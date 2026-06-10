// V25 — Continue Watching row dedupes from Recently Played.
//
// Closes the symmetric V22 gap. V22 made `mostWatchedProvider`
// watch `recentlyPlayedProvider` and exclude any streamId in the
// top `kPersonalisationRowCap` (8) recency entries. The symmetric
// case — `continueWatchingProvider` for **live channels** (V24
// entries) — was still missing. A user watching "BBC One" for >30s
// would get BOTH a Continue Watching card AND a Recently Played
// card for the same channel (same data, same tap target — play BBC
// One) — the same "two home rows showing the same channel" problem
// V22 fixed for Most Watched.
//
// V25 adds a fourth pass in `continueWatchingProvider`: after the
// existing V23 dedupe partition (group-by-parent for series
// episodes, pass-through for VOD + live), the result is filtered
// against the recency-top-N set so any `liveChannel` entry whose
// streamId is already surfaced in the Recently Played row is
// dropped. VOD and series-episode entries are NOT deduped —
// `recentlyPlayedProvider` is live-only (joins against
// `liveStreamsProvider` exclusively, per V20's implementation), so
// the recency set can never contain a VOD or series streamId.
// Movies + series episodes always remain in Continue Watching
// even if the user recently watched them.
//
// Composition: combines with V22 (Most Watched also excludes
// recency) and V23 (series-episode group-by-parent dedupe) — both
// still apply; the live-channel recency dedupe is additive.
//
// Test scope: pure data-layer / Riverpod injection tests. Mirrors
// the V22 / V23 / V24 pattern (no widget pump). The card widget
// (`_ContinueWatchingCard`) is already exercised by the existing
// V17 / V21 / V24 tests; the source change is in
// `presentation/providers/app_providers.dart`
// `continueWatchingProvider`, so the data-layer tests prove the
// dedupe at the right layer.
//
// Fixture pattern follows `v24_live_continue_watching_test.dart`:
// _FakeCredentialsStore + `_FakeXtreamClient` (with vodStreams +
// seriesStreams + seriesInfoById + liveStreams) +
// `makeContainer` helper that overrides the storage + client
// providers, seeds watch progress, and optionally injects a
// `recentlyPlayedProvider.overrideWith` to drive the recency
// exclusion set deterministically (real PlayCountStore-based
// recency works too, but override is more direct).

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
  // When non-null, overrides `recentlyPlayedProvider` directly. Use
  // this to drive the recency exclusion set deterministically. The
  // recency provider is normally derived from `PlayCountStore` (which
  // is keyed by `creds.name` and shared across the test run via
  // SharedPreferences.setMockInitialValues), so injecting a fixed
  // list is the cleanest way to test the dedupe in isolation.
  List<RecentlyPlayedEntry>? recencyOverride,
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
      liveStreamsProvider.overrideWith((ref) async => liveStreams),
      if (recencyOverride != null)
        recentlyPlayedProvider.overrideWith((ref) async => recencyOverride),
    ],
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────

void main() {
  group('continueWatchingProvider — V25 recency dedupe', () {
    test('recency empty (default) → live entries unaffected (regression guard)',
        () async {
      // With no recency override, the `recentlyPlayedProvider`
      // returns the empty list from the bare `PlayCountStore`
      // (SharedPreferences is empty in `_makeContainer`). The
      // recency-top-N exclude set is therefore empty, and no
      // live entries get filtered. This is the V25 "no-op" path —
      // V25 must not break the existing behaviour when a user has
      // no recency data.
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
      expect(result.single.stream.streamId, 42);
    });

    test('live channel in recency top-N → excluded from Continue Watching',
        () async {
      // The headline V25 behaviour: a user currently watching
      // channel 42 (Continue Watching would surface a card) AND
      // has channel 42 in the recency top-1 (Recently Played
      // already surfaces a card) — the Continue Watching card
      // must be dropped to avoid the two-rows-one-channel
      // duplication.
      const recentId = 42;
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: const {},
        liveStreams: const [
          XtreamStream(
            streamId: recentId,
            name: 'CNN',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {recentId: 60000},
        recencyOverride: [
          RecentlyPlayedEntry(
            stream: XtreamStream(
              streamId: recentId,
              name: 'CNN',
              categoryId: 1,
              streamType: 'live',
            ),
            lastPlayedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, isEmpty);
    });

    test('live channel outside recency top-N → still surfaces (regression guard)',
        () async {
      // The recency set has 9 channels, none of which is the one
      // with watch progress. With `kPersonalisationRowCap = 8`
      // the recency-top-8 covers all 9? No — we take the first
      // 8 (streamId 1-8). The watched channel (id 100) is
      // outside the top-8 by virtue of being the 9th. Continue
      // Watching must still surface it.
      final recency = <RecentlyPlayedEntry>[];
      for (var i = 1; i <= 9; i++) {
        recency.add(RecentlyPlayedEntry(
          stream: XtreamStream(
            streamId: i,
            name: 'Ch$i',
            categoryId: 1,
            streamType: 'live',
          ),
          lastPlayedAtMs: DateTime.now().millisecondsSinceEpoch - i,
        ));
      }
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: const {},
        liveStreams: const [
          XtreamStream(
            streamId: 100,
            name: 'The Watched Channel',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {100: 60000},
        recencyOverride: recency,
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(1));
      expect(result.single.stream.streamId, 100);
    });

    test('VOD entries are NOT deduped (recency set is live-only)', () async {
      // `recentlyPlayedProvider` is joined against `liveStreamsProvider`
      // exclusively, so the recency-top-N can never contain a VOD
      // streamId. A VOD entry must therefore survive the V25
      // dedupe even if the VOD streamId happens to also be in
      // the recency set (which would be a synthetic fixture —
      // the recency set's `stream` is a live stream by construction).
      // For this test we construct a VOD stream (id 555) and a
      // recency override whose streamId is 555 (a synthetic
      // "live" stream with the same id). The V25 dedupe must
      // NOT filter the VOD entry out — only `liveChannel` kind
      // entries participate in the recency dedupe.
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
        liveStreams: const [],
        activeConnectionName: 'conn',
        progressByStreamId: {555: 5000},
        recencyOverride: [
          RecentlyPlayedEntry(
            // Synthetic "live" stream with the same id as the
            // VOD entry — recency set normally only contains
            // live streamIds, but the dedupe logic must filter
            // by KIND, not by streamId collision, so this case
            // must NOT drop the VOD entry.
            stream: XtreamStream(
              streamId: 555,
              name: 'Synthetic',
              categoryId: 1,
              streamType: 'live',
            ),
            lastPlayedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(1));
      expect(result.single.kind, ContinueWatchingKind.vod);
      expect(result.single.stream.streamId, 555);
    });

    test('series-episode entries are NOT deduped (recency set is live-only)',
        () async {
      // Symmetric to the VOD test: a series-episode entry must
      // survive the V25 dedupe even if a synthetic recency entry
      // happens to carry the same streamId. The dedupe filters
      // by `kind == liveChannel`, so series-episode entries are
      // untouched.
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
          seriesId: _seriesInfo(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Ep 1', 'stream_id': episodeStreamId},
            ],
          ]),
        },
        liveStreams: const [],
        activeConnectionName: 'conn',
        progressByStreamId: {episodeStreamId: 5000},
        recencyOverride: [
          RecentlyPlayedEntry(
            // Synthetic "live" stream with the same id as the
            // episode — must NOT drop the series-episode entry.
            stream: XtreamStream(
              streamId: episodeStreamId,
              name: 'Synthetic',
              categoryId: 1,
              streamType: 'live',
            ),
            lastPlayedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(1));
      expect(result.single.kind, ContinueWatchingKind.seriesEpisode);
      expect(result.single.stream.streamId, seriesId);
    });

    test('mixed VOD + series + live with partial recency overlap: '
        'live channels overlapping recency are dropped, others surface',
        () async {
      // Fixture: 3 watched streams.
      //   - VOD 555 (Movie A)
      //   - Series-episode 1001 (parent: Series 10)
      //   - Live 42 (CNN) — in recency top-1
      //   - Live 99 (BBC) — NOT in recency set
      // V25 must:
      //   - keep VOD 555 (recency set is live-only)
      //   - keep series-episode 1001 (recency set is live-only)
      //   - drop live 42 (overlaps recency top-1)
      //   - keep live 99 (no recency overlap)
      // Result: 3 entries.
      const seriesId = 10;
      const episodeStreamId = 1001;
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
              {'episode_num': 1, 'title': 'Ep 1', 'stream_id': episodeStreamId},
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
            streamId: 99,
            name: 'BBC',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {555: 5000, episodeStreamId: 5000, 42: 60000, 99: 60000},
        recencyOverride: [
          RecentlyPlayedEntry(
            stream: XtreamStream(
              streamId: 42,
              name: 'CNN',
              categoryId: 1,
              streamType: 'live',
            ),
            lastPlayedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(3));
      final ids = result.map((e) => e.stream.streamId).toSet();
      expect(ids, contains(555)); // VOD kept
      expect(ids, contains(seriesId)); // series-episode kept (parent id)
      expect(ids, contains(99)); // live, not in recency, kept
      expect(ids, isNot(contains(42))); // live, in recency, dropped
    });

    test('all live channels in recency → Continue Watching is empty',
        () async {
      // Edge case: every live channel the user has progress on
      // is also in the recency top-N. The result is the empty
      // list. Sanity for the "everything deduped" path.
      final recency = <RecentlyPlayedEntry>[];
      for (final id in [42, 99, 7]) {
        recency.add(RecentlyPlayedEntry(
          stream: XtreamStream(
            streamId: id,
            name: 'Ch$id',
            categoryId: 1,
            streamType: 'live',
          ),
          lastPlayedAtMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
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
          XtreamStream(
            streamId: 99,
            name: 'BBC',
            categoryId: 1,
            streamType: 'live',
          ),
          XtreamStream(
            streamId: 7,
            name: 'ITV',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {42: 60000, 99: 60000, 7: 60000},
        recencyOverride: recency,
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      expect(result, isEmpty);
    });

    test('recency set covers kPersonalisationRowCap (8) → still only '
        'filters live kinds (composition with V22 cap)', () async {
      // Composition check: the V25 dedupe uses the same
      // `kPersonalisationRowCap` (8) as V22's Most Watched
      // recency dedupe. Build a recency set with exactly 8
      // entries; the dedupe reads the first 8. Any live channel
      // in the first 8 gets dropped; any live channel outside
      // the first 8 (e.g. id 99) is unaffected.
      final recency = <RecentlyPlayedEntry>[];
      for (var i = 1; i <= 8; i++) {
        recency.add(RecentlyPlayedEntry(
          stream: XtreamStream(
            streamId: i,
            name: 'Ch$i',
            categoryId: 1,
            streamType: 'live',
          ),
          lastPlayedAtMs: DateTime.now().millisecondsSinceEpoch - i,
        ));
      }
      final container = await _makeContainer(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: const {},
        liveStreams: const [
          XtreamStream(
            streamId: 1,
            name: 'Ch1',
            categoryId: 1,
            streamType: 'live',
          ),
          XtreamStream(
            streamId: 8,
            name: 'Ch8',
            categoryId: 1,
            streamType: 'live',
          ),
          XtreamStream(
            streamId: 99,
            name: 'Ch99',
            categoryId: 1,
            streamType: 'live',
          ),
        ],
        activeConnectionName: 'conn',
        progressByStreamId: {1: 60000, 8: 60000, 99: 60000},
        recencyOverride: recency,
      );
      addTearDown(container.dispose);

      final result = await container.read(continueWatchingProvider.future);
      // Only channel 99 is NOT in the recency top-8, so it's the
      // sole survivor.
      expect(result, hasLength(1));
      expect(result.single.stream.streamId, 99);
    });
  });
}
