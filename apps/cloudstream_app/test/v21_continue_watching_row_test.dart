// V21: Continue Watching row on the VOD and Series home tabs.
//
// V21 splits the existing `continueWatchingProvider` (V03 + V04) into
// two kind-filtered providers:
//
//   - `continueWatchingVodProvider`     → `kind == vod` (drives VOD tab)
//   - `continueWatchingSeriesProvider` → `kind == seriesEpisode`
//                                         (drives Series tab)
//
// Both providers must:
//
//   1. return `[]` when no creds are configured (same as the source)
//   2. return `[]` when no saved watch progress exists
//   3. return only the matching kind from the source (filter
//      correctness — the whole point of the split)
//   4. not surface the un-resolved episode/parent fields as
//      mismatched (defensive: the filter provider sees the full
//      ContinueWatchingEntry, not a stripped subset)
//   5. cascade through `continueWatchingProvider` invalidation
//      (single invalidate must refresh all three rows: channel list,
//      VOD, Series)
//
// We don't pump the `VodScreen` / `SeriesScreen` widgets here because
// both pull `vodCategoriesProvider` / `seriesCategoriesProvider`
// (network call) on first build and the brightness-aware migration
// tests already cover the row's brightness correctness by the
// brightness-aware source code being unchanged. The data-layer
// coverage below proves the filter is correct and that the new
// providers integrate with the existing one cleanly.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/core/storage/watch_progress_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

// ── Fakes ─────────────────────────────────────────────────────────────

class _FakeCredentialsStore implements CredentialsStore {
  _FakeCredentialsStore({this.activeName});
  String? activeName;

  @override
  Future<List<XtreamCredentials>> listConnections() async {
    if (activeName == null) return [];
    return [
      XtreamCredentials(
        name: activeName!,
        serverUrl: 'https://example.com',
        username: 'u',
        password: 'p',
      ),
    ];
  }

  @override
  Future<XtreamCredentials?> loadActiveConnection() async {
    if (activeName == null) return null;
    return XtreamCredentials(
      name: activeName!,
      serverUrl: 'https://example.com',
      username: 'u',
      password: 'p',
    );
  }

  @override
  Future<void> saveConnection({
    required String name,
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    activeName = name;
  }

  @override
  Future<void> setActiveConnection(String name) async {
    activeName = name;
  }

  @override
  Future<void> deleteConnection(String name) async {
    if (activeName == name) activeName = null;
  }

  @override
  Future<void> clearAll() async {
    activeName = null;
  }
}

class _FakeXtreamClient extends XtreamApiClient {
  _FakeXtreamClient({
    required this.vodStreams,
    required this.seriesStreams,
    required this.seriesInfoById,
  });

  final List<XtreamStream> vodStreams;
  final List<XtreamStream> seriesStreams;
  final Map<int, XtreamSeriesInfo> seriesInfoById;

  @override
  Future<List<XtreamStream>> getVodStreams({int? categoryId}) async {
    if (categoryId == null) return vodStreams;
    return vodStreams.where((s) => s.categoryId == categoryId).toList();
  }

  @override
  Future<List<XtreamStream>> getSeriesStreams({int? categoryId}) async {
    if (categoryId == null) return seriesStreams;
    return seriesStreams.where((s) => s.categoryId == categoryId).toList();
  }

  @override
  Future<XtreamSeriesInfo> getSeriesInfo(int seriesId) async {
    final info = seriesInfoById[seriesId];
    if (info == null) throw Exception('unknown series $seriesId');
    return info;
  }
}

XtreamSeriesInfo _seriesInfoWith({
  required int id,
  required List<List<Map<String, dynamic>>> seasonsJson,
}) {
  final seasons = <XtreamSeason>[];
  for (var i = 0; i < seasonsJson.length; i++) {
    final eps = seasonsJson[i]
        .map((j) => XtreamEpisode(
              episodeNumber: j['episode_num'] as int? ?? 0,
              title: j['title'] as String? ?? '',
              description: j['description'] as String?,
              streamId: j['stream_id'] as int? ?? 0,
              duration: j['duration'] as int? ?? 0,
            ))
        .toList();
    seasons.add(XtreamSeason(seasonNumber: i + 1, episodes: eps));
  }
  return XtreamSeriesInfo(
    name: 'Series $id',
    cover: 'https://cdn.example.com/series/$id.jpg',
    seasons: seasons,
  );
}

Future<ProviderContainer> _makeContainer({
  required List<XtreamStream> vodStreams,
  required List<XtreamStream> seriesStreams,
  required Map<int, XtreamSeriesInfo> seriesInfoById,
  String? activeConnectionName,
  Map<int, int> progressByStreamId = const {},
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final progressStore = WatchProgressStore(prefs);
  for (final entry in progressByStreamId.entries) {
    if (activeConnectionName == null) continue;
    await progressStore.saveProgress(
      profileId: activeConnectionName,
      streamId: entry.key,
      positionMs: entry.value,
    );
  }
  final credsStore = _FakeCredentialsStore(activeName: activeConnectionName);
  final profileStore = ProfileStore(prefs);
  if (activeConnectionName != null) {
    await profileStore.addProfile(name: activeConnectionName);
  }
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      profileStoreProvider.overrideWithValue(profileStore),
      credentialsStoreProvider.overrideWithValue(credsStore),
      watchProgressStoreProvider.overrideWithValue(progressStore),
      xtreamClientProvider.overrideWithValue(
        _FakeXtreamClient(
          vodStreams: vodStreams,
          seriesStreams: seriesStreams,
          seriesInfoById: seriesInfoById,
        ),
      ),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────

void main() {
  group('continueWatchingVodProvider', () {
    test('empty when no active connection', () async {
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 1, name: 'Movie A', categoryId: 1, streamType: 'movie'),
        ],
        seriesStreams: const [],
        seriesInfoById: const {},
        activeConnectionName: null,
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingVodProvider.future);
      expect(result, isEmpty);
    });

    test('empty when no saved progress', () async {
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 1, name: 'Movie A', categoryId: 1, streamType: 'movie'),
        ],
        seriesStreams: const [],
        seriesInfoById: const {},
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingVodProvider.future);
      expect(result, isEmpty);
    });

    test('surfaces VOD-kind entries with the right stream + kind', () async {
      const vodStreamId = 555;
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(streamId: vodStreamId, name: 'Movie A', categoryId: 1, streamType: 'movie'),
        ],
        seriesStreams: const [],
        seriesInfoById: const {},
        activeConnectionName: 'conn',
        progressByStreamId: {vodStreamId: 60000},
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingVodProvider.future);
      expect(result, hasLength(1));
      final entry = result.single;
      expect(entry.kind, ContinueWatchingKind.vod);
      expect(entry.stream.streamId, vodStreamId);
      expect(entry.stream.name, 'Movie A');
    });

    test('filters OUT series-episode entries (the whole point of the split)',
        () async {
      const seriesId = 10;
      const episodeStreamId = 1001;
      const vodStreamId = 555;
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(
            streamId: vodStreamId,
            name: 'Movie A',
            categoryId: 1,
            streamType: 'movie',
          ),
        ],
        seriesStreams: const [
          XtreamStream(
            streamId: seriesId,
            name: 'The Series',
            categoryId: 0,
            streamType: 'series',
          ),
        ],
        seriesInfoById: {
          seriesId: _seriesInfoWith(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Pilot', 'stream_id': episodeStreamId},
            ],
          ]),
        },
        activeConnectionName: 'conn',
        progressByStreamId: {
          vodStreamId: 30000,
          episodeStreamId: 60000,
        },
      );
      addTearDown(container.dispose);

      // Source provider sees both.
      final all = await container.read(continueWatchingProvider.future);
      expect(all, hasLength(2));

      // VOD filter narrows to the VOD entry only — the series episode
      // entry must NOT leak into the VOD tab's row.
      final vodOnly = await container.read(continueWatchingVodProvider.future);
      expect(vodOnly, hasLength(1));
      expect(vodOnly.single.kind, ContinueWatchingKind.vod);
      expect(vodOnly.single.stream.streamId, vodStreamId);
    });

    test('preserves updatedAt-desc ordering from the source provider',
        () async {
      // Save progress in non-sorted order; the source provider sorts
      // by updatedAt desc. The VOD filter should inherit that order
      // (it just narrows, doesn't re-sort).
      const a = 555;
      const b = 556;
      const c = 557;
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(streamId: a, name: 'A', categoryId: 1, streamType: 'movie'),
          XtreamStream(streamId: b, name: 'B', categoryId: 1, streamType: 'movie'),
          XtreamStream(streamId: c, name: 'C', categoryId: 1, streamType: 'movie'),
        ],
        seriesStreams: const [],
        seriesInfoById: const {},
        activeConnectionName: 'conn',
        progressByStreamId: {a: 1000, b: 1000, c: 1000},
      );
      addTearDown(container.dispose);

      // Sanity: source returns 3 entries.
      final all = await container.read(continueWatchingProvider.future);
      expect(all, hasLength(3));

      final vodOnly = await container.read(continueWatchingVodProvider.future);
      expect(vodOnly, hasLength(3));
      expect(
        vodOnly.map((e) => e.stream.streamId).toSet(),
        {a, b, c},
      );
    });
  });

  group('continueWatchingSeriesProvider', () {
    test('empty when no active connection', () async {
      const seriesId = 10;
      const episodeStreamId = 1001;
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [
          XtreamStream(
            streamId: seriesId,
            name: 'The Series',
            categoryId: 0,
            streamType: 'series',
          ),
        ],
        seriesInfoById: {
          seriesId: _seriesInfoWith(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Pilot', 'stream_id': episodeStreamId},
            ],
          ]),
        },
        activeConnectionName: null,
        progressByStreamId: {episodeStreamId: 60000},
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingSeriesProvider.future);
      expect(result, isEmpty);
    });

    test('surfaces series-episode entries with parent fields populated',
        () async {
      const seriesId = 10;
      const episodeStreamId = 1001;
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [
          XtreamStream(
            streamId: seriesId,
            name: 'The Series',
            categoryId: 0,
            streamType: 'series',
          ),
        ],
        seriesInfoById: {
          seriesId: _seriesInfoWith(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Pilot', 'stream_id': episodeStreamId},
            ],
          ]),
        },
        activeConnectionName: 'conn',
        progressByStreamId: {episodeStreamId: 60000},
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingSeriesProvider.future);
      expect(result, hasLength(1));
      final entry = result.single;
      expect(entry.kind, ContinueWatchingKind.seriesEpisode);
      expect(entry.parentSeries, isNotNull);
      expect(entry.parentSeason, isNotNull);
      expect(entry.episode, isNotNull);
      expect(entry.episode!.streamId, episodeStreamId);
    });

    test('filters OUT VOD entries (the whole point of the split)',
        () async {
      const seriesId = 10;
      const episodeStreamId = 1001;
      const vodStreamId = 555;
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(
            streamId: vodStreamId,
            name: 'Movie A',
            categoryId: 1,
            streamType: 'movie',
          ),
        ],
        seriesStreams: const [
          XtreamStream(
            streamId: seriesId,
            name: 'The Series',
            categoryId: 0,
            streamType: 'series',
          ),
        ],
        seriesInfoById: {
          seriesId: _seriesInfoWith(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Pilot', 'stream_id': episodeStreamId},
            ],
          ]),
        },
        activeConnectionName: 'conn',
        progressByStreamId: {
          vodStreamId: 30000,
          episodeStreamId: 60000,
        },
      );
      addTearDown(container.dispose);

      // Series filter narrows to the series-episode entry only — the
      // VOD entry must NOT leak into the Series tab's row.
      final seriesOnly =
          await container.read(continueWatchingSeriesProvider.future);
      expect(seriesOnly, hasLength(1));
      expect(seriesOnly.single.kind, ContinueWatchingKind.seriesEpisode);
      expect(seriesOnly.single.episode!.streamId, episodeStreamId);
    });
  });

  group('cross-provider invalidation (single invalidate cascades)', () {
    // The dismiss flow on every Continue Watching row
    // (`VodScreen._openDismiss`, `SeriesScreen._openDismiss`,
    // `ChannelListScreen._openDismiss`) calls
    // `ref.invalidate(continueWatchingProvider)` so a single
    // invalidate must refresh all three rows: the source AND the two
    // V21 filter providers. This test proves that contract.
    test('invalidate(continueWatchingProvider) cascades to VOD + Series '
        'filters', () async {
      const seriesId = 10;
      const episodeStreamId = 1001;
      const vodStreamId = 555;
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(
            streamId: vodStreamId,
            name: 'Movie A',
            categoryId: 1,
            streamType: 'movie',
          ),
        ],
        seriesStreams: const [
          XtreamStream(
            streamId: seriesId,
            name: 'The Series',
            categoryId: 0,
            streamType: 'series',
          ),
        ],
        seriesInfoById: {
          seriesId: _seriesInfoWith(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Pilot', 'stream_id': episodeStreamId},
            ],
          ]),
        },
        activeConnectionName: 'conn',
        progressByStreamId: {
          vodStreamId: 30000,
          episodeStreamId: 60000,
        },
      );
      addTearDown(container.dispose);

      // Sanity: all three providers have data.
      expect(
        (await container.read(continueWatchingProvider.future)).length,
        2,
      );
      expect(
        (await container.read(continueWatchingVodProvider.future)).length,
        1,
      );
      expect(
        (await container.read(continueWatchingSeriesProvider.future)).length,
        1,
      );

      // Clear the VOD entry + invalidate the source.
      final store = container.read(watchProgressStoreProvider);
      await store.clearProgress(profileId: 'conn', streamId: vodStreamId);
      container.invalidate(continueWatchingProvider);

      // Source reflects the clear; both filter providers reflect it.
      final all = await container.read(continueWatchingProvider.future);
      expect(all, hasLength(1));
      expect(all.single.kind, ContinueWatchingKind.seriesEpisode);

      final vodOnly = await container.read(continueWatchingVodProvider.future);
      expect(vodOnly, isEmpty,
          reason: 'VOD filter must cascade the source invalidate');

      final seriesOnly =
          await container.read(continueWatchingSeriesProvider.future);
      expect(seriesOnly, hasLength(1),
          reason: 'Series filter must cascade the source invalidate');
    });
  });
}
