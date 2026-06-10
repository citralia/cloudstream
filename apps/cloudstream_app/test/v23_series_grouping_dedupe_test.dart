// V23 — Continue Watching series-grouping dedupe.
//
// Closes the V04/V21 follow-on gap: V04 added series-episode
// reverse-lookup (saved episode streamId → parent series) and V21
// extended the row across all three home tabs. Both exposed a real
// data-layer problem — a user with watch progress on 3 episodes of
// "Breaking Bad" saw THREE "Continue Watching — Breaking Bad" cards
// stacked, one per episode, all pointing at the same parent. The
// card itself rendered the synthesised episode's S/E badge
// (e.g. "S01E05 — Episode title"), so three cards for the same
// series were visually three near-duplicates.
//
// V23 dedupes the `continueWatchingProvider` output by
// `parentSeriesId` for series-episode entries, keeping the most
// recently updated episode as the representative. VOD entries are
// unaffected — a movie is a single item, not a container of
// sub-items, so there's no "group" to dedupe.
//
// Test scope: pure data-layer / Riverpod injection tests. Mirrors
// the V22 pattern (no widget pump). The card widget
// (`_ContinueWatchingCard`) is already exercised by the existing
// V17 / V21 tests; the source change is in
// `presentation/providers/app_providers.dart` `continueWatchingProvider`,
// so the data-layer tests prove the dedupe at the right layer.
//
// Fixture pattern follows `series_continue_watching_test.dart`:
// _FakeCredentialsStore + _FakeXtreamClient (with vodStreams,
// seriesStreams, seriesInfoById) + `makeContainer` helper that
// overrides the storage + client providers and seeds watch
// progress. Per-streamId progress seed lets us construct the
// "3 episodes of the same series" scenario deterministically.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/core/storage/watch_progress_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

// ─── Test doubles ────────────────────────────────────────────────────────

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
    if (info == null) {
      throw Exception('unknown series $seriesId');
    }
    return info;
  }
}

// ─── Fixture helpers ─────────────────────────────────────────────────────

XtreamSeriesInfo _seriesInfo({
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

// ─── Tests ───────────────────────────────────────────────────────────────

void main() {
  group('continueWatchingProvider — V23 series-grouping dedupe', () {
    test('3 episodes of the same series → 1 entry (most recent representative)',
        () async {
      const seriesId = 10;
      // Three episodes of the same series, all watched.
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [
          XtreamStream(
            streamId: seriesId,
            name: 'Breaking Bad',
            categoryId: 0,
            streamType: 'series',
          ),
        ],
        seriesInfoById: {
          seriesId: _seriesInfo(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Pilot', 'stream_id': 1001},
              {'episode_num': 2, 'title': "Cat's in the Bag...", 'stream_id': 1002},
              {'episode_num': 3, 'title': '...And the Bag\'s in the River', 'stream_id': 1003},
            ],
          ]),
        },
        activeConnectionName: 'conn',
        // Distinct position values don't matter for ordering — the
        // dedupe uses `progress.updatedAt`, which `saveProgress`
        // stamps to DateTime.now() on each call. We just need
        // *some* progress for each id. The last-written (1003)
        // becomes the representative.
        progressByStreamId: {1001: 1000, 1002: 1000, 1003: 1000},
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      // Three episodes → one representative card.
      expect(result, hasLength(1));
      final entry = result.single;
      expect(entry.kind, ContinueWatchingKind.seriesEpisode);
      expect(entry.parentSeriesId, seriesId);
      // Representative is the most recent (last written).
      expect(entry.episode!.streamId, 1003);
    });

    test('VOD entries pass through the dedupe unchanged', () async {
      // A user who has progress on 2 VODs + 3 episodes of one
      // series should see 3 cards: 2 VODs + 1 series card, NOT
      // 5 (VODs aren't grouped) and NOT 3 (VODs aren't dropped).
      const seriesId = 10;
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 555, name: 'Movie A', categoryId: 1, streamType: 'movie'),
          XtreamStream(streamId: 556, name: 'Movie B', categoryId: 1, streamType: 'movie'),
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
          seriesId: _seriesInfo(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Ep 1', 'stream_id': 1001},
              {'episode_num': 2, 'title': 'Ep 2', 'stream_id': 1002},
              {'episode_num': 3, 'title': 'Ep 3', 'stream_id': 1003},
            ],
          ]),
        },
        activeConnectionName: 'conn',
        progressByStreamId: {
          555: 1000,
          556: 1000,
          1001: 1000,
          1002: 1000,
          1003: 1000,
        },
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(3));
      final vodCount =
          result.where((e) => e.kind == ContinueWatchingKind.vod).length;
      final seriesCount = result
          .where((e) => e.kind == ContinueWatchingKind.seriesEpisode)
          .length;
      expect(vodCount, 2, reason: 'VOD entries must NOT be grouped');
      expect(seriesCount, 1, reason: 'Series-episode entries are deduped');
    });

    test('2 different series each with 2 episodes → 2 entries (one per series)',
        () async {
      const seriesA = 10;
      const seriesB = 20;
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [
          XtreamStream(streamId: seriesA, name: 'Series A', categoryId: 0, streamType: 'series'),
          XtreamStream(streamId: seriesB, name: 'Series B', categoryId: 0, streamType: 'series'),
        ],
        seriesInfoById: {
          seriesA: _seriesInfo(id: seriesA, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'A1', 'stream_id': 1001},
              {'episode_num': 2, 'title': 'A2', 'stream_id': 1002},
            ],
          ]),
          seriesB: _seriesInfo(id: seriesB, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'B1', 'stream_id': 2001},
              {'episode_num': 2, 'title': 'B2', 'stream_id': 2002},
            ],
          ]),
        },
        activeConnectionName: 'conn',
        progressByStreamId: {
          1001: 1000,
          1002: 1000,
          2001: 1000,
          2002: 1000,
        },
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(2));
      final seriesIds =
          result.map((e) => e.parentSeriesId).toSet();
      expect(seriesIds, {seriesA, seriesB});
    });

    test('ordering of deduped result is by recency desc, VODs and series interleaved',
        () async {
      // Series A's most recent episode written 2nd, Movie A written
      // 3rd → in the sorted output, Movie A should come first
      // (newest updatedAt), then Series A's representative, then
      // Movie B. Mirrors the existing updatedAt-desc sort.
      const seriesA = 10;
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 555, name: 'Movie A', categoryId: 1, streamType: 'movie'),
          XtreamStream(streamId: 556, name: 'Movie B', categoryId: 1, streamType: 'movie'),
        ],
        seriesStreams: const [
          XtreamStream(
            streamId: seriesA,
            name: 'Series A',
            categoryId: 0,
            streamType: 'series',
          ),
        ],
        seriesInfoById: {
          seriesA: _seriesInfo(id: seriesA, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'A1', 'stream_id': 1001},
              {'episode_num': 2, 'title': 'A2', 'stream_id': 1002},
            ],
          ]),
        },
        activeConnectionName: 'conn',
        // Write order: Movie B → Series A ep1 → Series A ep2 →
        // Movie A. Final updatedAt ranking: Movie A > Series A
        // (ep2) > Movie B.
        progressByStreamId: const {},
      );
      addTearDown(container.dispose);

      final progressStore = container.read(watchProgressStoreProvider);
      // Sleep-avoiding ordering: each `saveProgress` stamps
      // DateTime.now(); microsecond differences are enough for
      // the comparator. The four writes below are sequential.
      await progressStore.saveProgress(profileId: 'conn', streamId: 556, positionMs: 1);
      await progressStore.saveProgress(profileId: 'conn', streamId: 1001, positionMs: 1);
      await progressStore.saveProgress(profileId: 'conn', streamId: 1002, positionMs: 1);
      await progressStore.saveProgress(profileId: 'conn', streamId: 555, positionMs: 1);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(3));
      // The most recent (last written) is Movie A.
      expect(result[0].stream.streamId, 555);
      // Then Series A's representative (the most recent of its
      // two episodes — 1002, written before Movie A).
      expect(result[1].kind, ContinueWatchingKind.seriesEpisode);
      expect(result[1].episode!.streamId, 1002);
      // Then Movie B (written first).
      expect(result[2].stream.streamId, 556);
    });

    test('dedupe is per-profile isolated (profile A series ≠ profile B series)',
        () async {
      // Watch progress is keyed by profileId — so the dedupe
      // operates on the active profile's progress set, and a
      // different profile with the same series ids gets its own
      // independent result.
      const seriesId = 10;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final progressStore = WatchProgressStore(prefs);
      await progressStore.saveProgress(profileId: 'A', streamId: 1001, positionMs: 1000);
      await progressStore.saveProgress(profileId: 'A', streamId: 1002, positionMs: 1000);
      await progressStore.saveProgress(profileId: 'B', streamId: 1001, positionMs: 1000);
      await progressStore.saveProgress(profileId: 'B', streamId: 1002, positionMs: 1000);

      final credsStore = _FakeCredentialsStore(activeName: 'A');
      final profileStore = ProfileStore(prefs);
      await profileStore.addProfile(name: 'A');
      await profileStore.addProfile(name: 'B');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(profileStore),
          credentialsStoreProvider.overrideWithValue(credsStore),
          watchProgressStoreProvider.overrideWithValue(progressStore),
          xtreamClientProvider.overrideWithValue(
            _FakeXtreamClient(
              vodStreams: const [],
              seriesStreams: const [
                XtreamStream(
                  streamId: seriesId,
                  name: 'Series',
                  categoryId: 0,
                  streamType: 'series',
                ),
              ],
              seriesInfoById: {
                seriesId: _seriesInfo(id: seriesId, seasonsJson: [
                  [
                    {'episode_num': 1, 'title': 'Ep1', 'stream_id': 1001},
                    {'episode_num': 2, 'title': 'Ep2', 'stream_id': 1002},
                  ],
                ]),
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Active = A → 1 entry (the 2 episodes deduped).
      final resultA = await container.read(continueWatchingProvider.future);
      expect(resultA, hasLength(1));
      expect(resultA.single.parentSeriesId, seriesId);

      // Switch to B → also 1 entry (independent storage).
      await credsStore.setActiveConnection('B');
      container.invalidate(continueWatchingProvider);
      final resultB = await container.read(continueWatchingProvider.future);
      expect(resultB, hasLength(1));
      expect(resultB.single.parentSeriesId, seriesId);
    });

    test('single episode of a series → 1 entry (dedupe is a no-op for size-1 groups)',
        () async {
      // Regression guard: the dedupe path must handle the
      // "1 episode" case without dropping the entry. V23 should
      // be a no-op for the existing single-episode case.
      const seriesId = 10;
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
          seriesId: _seriesInfo(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Pilot', 'stream_id': 1001},
            ],
          ]),
        },
        activeConnectionName: 'conn',
        progressByStreamId: {1001: 60000},
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(1));
      expect(result.single.kind, ContinueWatchingKind.seriesEpisode);
      expect(result.single.episode!.streamId, 1001);
      expect(result.single.parentSeriesId, seriesId);
    });

    test('long-press → clear → provider no longer surfaces the cleared series entry',
        () async {
      // The existing V17 long-press flow clears a single
      // `entry.stream.streamId` (the parent series stream's id,
      // not the episode's). After V23, if the user has progress
      // on 3 episodes of one series, there's exactly ONE
      // `continueWatchingProvider` entry for the series — and
      // long-pressing it should clear the most recently updated
      // episode's progress and drop the entire series from the
      // row (the older episodes' progress remains in storage, so
      // the row re-appears if the user opens one of them and
      // re-watches).
      //
      // We seed 2 episodes, save the older one first, save the
      // newer one second, then clear the newer's id. The
      // `continueWatchingProvider` should drop the series entry
      // entirely. This is the same data-layer behaviour V17
      // exercised, with the V23 dedupe in front.
      const seriesId = 10;
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
          seriesId: _seriesInfo(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Ep1', 'stream_id': 1001},
              {'episode_num': 2, 'title': 'Ep2', 'stream_id': 1002},
            ],
          ]),
        },
        activeConnectionName: 'conn',
        progressByStreamId: const {},
      );
      addTearDown(container.dispose);

      final progressStore = container.read(watchProgressStoreProvider);
      await progressStore.saveProgress(profileId: 'conn', streamId: 1001, positionMs: 1);
      await progressStore.saveProgress(profileId: 'conn', streamId: 1002, positionMs: 1);

      var result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(1));
      expect(result.single.parentSeriesId, seriesId);
      // The representative is the most recent episode (1002).
      expect(result.single.episode!.streamId, 1002);

      // Simulate the V17 long-press → clear flow.
      await progressStore.clearProgress(profileId: 'conn', streamId: 1002);
      container.invalidate(continueWatchingProvider);

      result = await container.read(continueWatchingProvider.future);
      // The representative is gone — but note: progress for
      // 1001 is still in storage, so `savedStreamIds` still
      // returns [1001]. The 1001 entry resolves to the parent
      // series (same dedupe key), so it should now be the
      // representative.
      expect(result, hasLength(1));
      expect(result.single.parentSeriesId, seriesId);
      expect(result.single.episode!.streamId, 1001);

      // Now clear 1001 too — series should be gone entirely.
      await progressStore.clearProgress(profileId: 'conn', streamId: 1001);
      container.invalidate(continueWatchingProvider);
      result = await container.read(continueWatchingProvider.future);
      expect(result, isEmpty);
    });
  });
}
