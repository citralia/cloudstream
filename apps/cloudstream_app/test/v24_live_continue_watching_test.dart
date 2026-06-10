// V24 — Continue Watching includes live TV channels.
//
// Closes the V03 follow-on gap: PlayerScreen._saveProgress saves
// watch progress for ANY stream (live channels included) on the
// same 30s cadence as VOD/series. The data was being persisted,
// but `continueWatchingProvider` only resolved saved streamIds
// against the VOD + series catalogues — a user watching a live
// channel for >30s had progress on disk but the Continue Watching
// row would never show a card for that channel. The user had to
// remember which channel they were on.
//
// V24 adds a third resolution branch against `liveStreamsProvider`,
// tagging the resulting entries with the new
// `ContinueWatchingKind.liveChannel`. The V23 dedupe partition
// ("seriesEpisodes" group-by-parent vs "everything else" pass-
// through) handles live channels in the "everything else" bucket
// alongside VOD entries — a live channel is a single item, not a
// container of sub-items, so no group dedupe is needed (mirrors
// how VOD entries are handled). A new `continueWatchingLiveProvider`
// filter exposes the live subset for symmetry with the V21 VOD /
// Series split (currently only consumed by the channel-list
// `_ContinueWatchingRow`, but exposed for future use).
//
// UI routing (channel_list_screen.dart `_openResume`): live
// entries open the live player directly (selectedStreamProvider
// state + PlayerScreen) — no VOD detail screen, no resume
// position. Live streams don't seek; the "Resume" badge is "I was
// watching this, tap to jump back", not a true seek-and-resume.
//
// Test scope: pure data-layer / Riverpod injection tests. Mirrors
// the V22 / V23 pattern (no widget pump). The card widget
// (`_ContinueWatchingCard`) is already exercised by the existing
// V17 / V21 tests; the source change is in
// `presentation/providers/app_providers.dart` `continueWatchingProvider`
// + the new `continueWatchingLiveProvider` filter, so the data-
// layer tests prove the live resolution at the right layer.
//
// Fixture pattern follows `v23_series_grouping_dedupe_test.dart`:
// _FakeCredentialsStore + `_FakeXtreamClient` (with vodStreams +
// seriesStreams + seriesInfoById, plus optional liveStreams
// override) + `makeContainer` helper that overrides the storage +
// client providers and seeds watch progress. Per-streamId progress
// seed lets us construct deterministic multi-kind scenarios.

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
  required List<XtreamStream> liveStreams,
  String? activeConnectionName,
  Map<int, int> progressByStreamId = const {},
  // When true, force liveStreamsProvider to throw (simulates a
  // server outage on a reconnect). Used by the "live provider
  // fails → VOD + series still surface" test.
  bool liveProviderFails = false,
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
      liveStreamsProvider.overrideWith(
        liveProviderFails
            ? (ref) async => throw Exception('live provider failed')
            : (ref) async => liveStreams,
      ),
    ],
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────

void main() {
  group('continueWatchingProvider — V24 live-channel resolution', () {
    test('no active connection → empty list', () async {
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: const {},
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'CNN', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: null,
        // No progress would be saved because no active connection.
        progressByStreamId: const {},
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, isEmpty);
    });

    test('saved progress on a live channel → surfaces as liveChannel kind',
        () async {
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: const {},
        liveStreams: const [
          XtreamStream(
            streamId: 42,
            name: 'CNN',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {42: 60000}, // 1 minute in
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(1));
      final entry = result.single;
      expect(entry.kind, ContinueWatchingKind.liveChannel);
      expect(entry.stream.streamId, 42);
      expect(entry.stream.name, 'CNN');
      expect(entry.stream.streamType, 'live');
    });

    test('VOD + live progress both surface with correct kinds', () async {
      // The headline V24 behaviour: a user with a VOD partially
      // watched AND a live channel partially watched sees TWO
      // Continue Watching cards, one per kind. Before V24 the
      // live one would be dropped silently.
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(
            streamId: 555,
            name: 'Movie A',
            categoryId: 1,
            streamType: 'movie',
          ),
        ],
        seriesStreams: const [],
        seriesInfoById: const {},
        liveStreams: const [
          XtreamStream(
            streamId: 42,
            name: 'CNN',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {555: 5000, 42: 60000},
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(2));
      final kinds = result.map((e) => e.kind).toSet();
      expect(kinds, {
        ContinueWatchingKind.vod,
        ContinueWatchingKind.liveChannel,
      });
      // Both streamIds are present.
      expect(result.map((e) => e.stream.streamId).toSet(), {555, 42});
    });

    test('VOD + series-episode + live: all three kinds surface, none lost',
        () async {
      // Mixed scenario: a user with progress on a VOD, an episode
      // of a series, AND a live channel sees three Continue
      // Watching cards, one per kind. Regression guard against
      // any of the three resolution branches swallowing one of
      // the others.
      const seriesId = 10;
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(
            streamId: 555,
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
          seriesId: _seriesInfo(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Ep 1', 'stream_id': 1001},
            ],
          ]),
        },
        liveStreams: const [
          XtreamStream(
            streamId: 42,
            name: 'CNN',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {555: 5000, 1001: 5000, 42: 60000},
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(3));
      final kinds = result.map((e) => e.kind).toSet();
      expect(kinds, {
        ContinueWatchingKind.vod,
        ContinueWatchingKind.seriesEpisode,
        ContinueWatchingKind.liveChannel,
      });
    });

    test(
        'orphan live streamId (no longer in catalogue) is dropped silently',
        () async {
      // The user has progress on a streamId that's NOT in the
      // live catalogue (e.g. the provider removed the channel
      // since they last watched it). The V03 / V21 orphan-drop
      // contract must apply to V24 live entries too — a stale
      // card pointing at a non-existent channel is a worse UX
      // than no card at all.
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: const {},
        liveStreams: const [
          // Only channel 99 is in the catalogue. The user has
          // progress on 1001, which is NOT.
          XtreamStream(
            streamId: 99,
            name: 'Real Channel',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {1001: 60000},
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, isEmpty);
    });

    test('per-profile isolation: live progress on profile A is hidden on profile B',
        () async {
      // The WatchProgressStore is keyed by profile (creds.name).
      // A user switching from profile A to profile B should not
      // see A's Continue Watching entries.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final progressStore = WatchProgressStore(prefs);
      // Profile A: live channel 42 partially watched.
      await progressStore.saveProgress(
        profileId: 'profileA',
        streamId: 42,
        positionMs: 60000,
      );
      // Profile B: no progress.
      final credsStore = _FakeCredentialsStore(activeName: 'profileB');
      final profileStore = ProfileStore(prefs);
      await profileStore.addProfile(name: 'profileA');
      await profileStore.addProfile(name: 'profileB');
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(profileStore),
          credentialsStoreProvider.overrideWithValue(credsStore),
          watchProgressStoreProvider.overrideWithValue(progressStore),
          xtreamClientProvider.overrideWithValue(
            _FakeXtreamClient(
              vodStreams: const [],
              seriesStreams: const [],
              seriesInfoById: const {},
            ),
          ),
          liveStreamsProvider.overrideWith((ref) async => const [
                XtreamStream(
                  streamId: 42,
                  name: 'CNN',
                  categoryId: 1,
                  streamType: 'live',
                ),
              ]),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, isEmpty,
          reason: 'Profile B has no progress; profile A\'s live entry '
              'must not leak across');
    });

    test(
        'liveStreamsProvider failure (server outage) → VOD + series still surface, live dropped',
        () async {
      // Resilient: the live provider is wrapped in catchError so a
      // failing live fetch doesn't tank the whole Continue
      // Watching row. VOD + series entries still surface, live
      // ones are dropped this tick. The user sees their saved
      // VOD/series progress even when the live catalogue is
      // unreachable.
      const seriesId = 10;
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(
            streamId: 555,
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
          seriesId: _seriesInfo(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Ep 1', 'stream_id': 1001},
            ],
          ]),
        },
        liveStreams: const [
          // Doesn't matter — the override below throws.
          XtreamStream(streamId: 42, name: 'X', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {555: 5000, 1001: 5000, 42: 60000},
        liveProviderFails: true,
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      // VOD + series survive; live is dropped.
      expect(result, hasLength(2));
      final kinds = result.map((e) => e.kind).toSet();
      expect(kinds, {
        ContinueWatchingKind.vod,
        ContinueWatchingKind.seriesEpisode,
      }, reason: 'Live entries are dropped on provider failure, not '
          'allowed to take down VOD + series');
    });

    test(
        'V23 series dedupe still works when a live entry is also present',
        () async {
      // V23 regression guard: the dedupe of series-episode
      // entries by parent series id must not regress when a live
      // entry is in the mix. The partition logic now sees three
      // kinds (vod, seriesEpisode, liveChannel) but the dedupe
      // is still keyed on `parentSeriesId` for seriesEpisodes
      // only — a user with progress on 3 episodes of "The
      // Series" + 1 live channel sees 2 cards, not 4.
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
              {'episode_num': 1, 'title': 'Ep 1', 'stream_id': 1001},
              {'episode_num': 2, 'title': 'Ep 2', 'stream_id': 1002},
              {'episode_num': 3, 'title': 'Ep 3', 'stream_id': 1003},
            ],
          ]),
        },
        liveStreams: const [
          XtreamStream(
            streamId: 42,
            name: 'CNN',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {
          1001: 1000,
          1002: 1000,
          1003: 1000,
          42: 60000,
        },
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(2),
          reason: '3 episodes of one series → 1 card (V23), plus '
              '1 live entry → 1 card = 2 cards total');
      final kinds = result.map((e) => e.kind).toSet();
      expect(kinds, {
        ContinueWatchingKind.seriesEpisode,
        ContinueWatchingKind.liveChannel,
      });
      // The series entry is the most recent episode.
      final seriesEntry = result.firstWhere(
        (e) => e.kind == ContinueWatchingKind.seriesEpisode,
      );
      expect(seriesEntry.parentSeriesId, seriesId);
      expect(seriesEntry.episode!.streamId, 1003);
      // The live entry is the CNN card.
      final liveEntry = result.firstWhere(
        (e) => e.kind == ContinueWatchingKind.liveChannel,
      );
      expect(liveEntry.stream.streamId, 42);
    });

    test('V22 Most Watched dedupe regression: V24 doesn\'t break V22',
        () async {
      // Lightweight regression guard: the V22 dedupe of Most
      // Watched from Recently Played reads play counts, not
      // watch progress — the two stores are independent — so V24
      // doesn't touch V22. This test just confirms the V24
      // continueWatchingProvider returns correctly while
      // playCountStore + recentlyPlayedProvider are at their
      // defaults (no play counts = no recency = no dedupe).
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: const {},
        liveStreams: const [
          XtreamStream(
            streamId: 42,
            name: 'CNN',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {42: 60000},
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(1));
      expect(result.single.kind, ContinueWatchingKind.liveChannel);
    });
  });

  group('continueWatchingLiveProvider — V24 live-only filter', () {
    test('no connection → empty', () async {
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: const {},
        liveStreams: const [],
        activeConnectionName: null,
      );
      addTearDown(container.dispose);

      final result =
          await container.read(continueWatchingLiveProvider.future);
      expect(result, isEmpty);
    });

    test('only live-channel entries surface (VOD + series filtered out)',
        () async {
      // The filter's job: given a continueWatchingProvider output
      // with mixed kinds, return only the liveChannel subset.
      const seriesId = 10;
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(
            streamId: 555,
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
          seriesId: _seriesInfo(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Ep 1', 'stream_id': 1001},
            ],
          ]),
        },
        liveStreams: const [
          XtreamStream(
            streamId: 42,
            name: 'CNN',
            categoryId: 1,
            streamType: 'live',
          ),
          XtreamStream(
            streamId: 43,
            name: 'BBC',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {
          555: 5000,
          1001: 5000,
          42: 60000,
          43: 120000,
        },
      );
      addTearDown(container.dispose);

      final result =
          await container.read(continueWatchingLiveProvider.future);
      expect(result, hasLength(2));
      final kinds = result.map((e) => e.kind).toSet();
      expect(kinds, {ContinueWatchingKind.liveChannel});
      expect(result.map((e) => e.stream.streamId).toSet(), {42, 43});
    });

    test('no live-channel entries → empty list (VOD + series still present upstream)',
        () async {
      // Symmetric to the previous test: when the upstream
      // continueWatchingProvider has no live entries (e.g. a
      // VOD-only user), the live filter returns []. The VOD +
      // series providers are unaffected — the live filter is
      // just one of three views on the same data.
      const seriesId = 10;
      final container = await _makeContainer(
        vodStreams: const [
          XtreamStream(
            streamId: 555,
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
          seriesId: _seriesInfo(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Ep 1', 'stream_id': 1001},
            ],
          ]),
        },
        liveStreams: const [], // No live channels.
        activeConnectionName: 'conn',
        progressByStreamId: {555: 5000, 1001: 5000},
      );
      addTearDown(container.dispose);

      final result =
          await container.read(continueWatchingLiveProvider.future);
      expect(result, isEmpty);

      // Sanity: VOD + series providers still see their entries.
      final vod =
          await container.read(continueWatchingVodProvider.future);
      expect(vod, hasLength(1));
      expect(vod.single.kind, ContinueWatchingKind.vod);

      final series =
          await container.read(continueWatchingSeriesProvider.future);
      expect(series, hasLength(1));
      expect(series.single.kind, ContinueWatchingKind.seriesEpisode);
    });
  });
}
