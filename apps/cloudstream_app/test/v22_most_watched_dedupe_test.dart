import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/play_count_store.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/core/storage/watch_progress_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

/// In-memory [CredentialsStore] fake. Same shape as the fakes in
/// `most_watched_test.dart` and `recently_played_row_test.dart`; kept
/// local so this test file is self-contained.
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

void main() {
  group('V22: mostWatchedProvider dedupes from recentlyPlayedProvider', () {
    /// Container builder. Note: V16's [PlayCountStore.increment] always
    /// stamps a lastPlayedAtMs (defaults to DateTime.now()), so the
    /// recency provider is always non-empty for any played stream. To
    /// test the "recency empty" path the caller overrides
    /// [recentlyPlayedProvider] directly.
    Future<ProviderContainer> makeContainer({
      required List<XtreamStream> liveStreams,
      String? activeConnectionName,
      Map<int, int> playCounts = const {},
      List<Override> extraOverrides = const [],
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final playStore = PlayCountStore(prefs);
      if (activeConnectionName != null) {
        for (final entry in playCounts.entries) {
          for (var i = 0; i < entry.value; i++) {
            await playStore.increment(
              profileId: activeConnectionName,
              streamId: entry.key,
            );
          }
        }
      }

      final credsStore = _FakeCredentialsStore(activeName: activeConnectionName);
      final profileStore = ProfileStore(prefs);
      WatchProgressStore(prefs);
      if (activeConnectionName != null) {
        await profileStore.addProfile(name: activeConnectionName);
      }

      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(profileStore),
          credentialsStoreProvider.overrideWithValue(credsStore),
          playCountStoreProvider.overrideWithValue(playStore),
          liveStreamsProvider.overrideWith((ref) async => liveStreams),
          ...extraOverrides,
        ],
      );
    }

    test('recency row is empty (overridden) → mostWatched unchanged',
        () async {
      // Force the recency provider to return empty so we exercise the
      // "no recency entries" code path. (PlayCountStore.increment
      // always stamps a timestamp, so we can't reach the empty-recency
      // state with increment alone — we have to override the provider.)
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 10, name: 'A', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 20, name: 'B', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn',
        playCounts: {10: 3, 20: 1},
        extraOverrides: [
          recentlyPlayedProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(mostWatchedProvider.future);
      expect(result, hasLength(2));
      expect(result[0].stream.streamId, 10);
      expect(result[1].stream.streamId, 20);
    });

    test('single channel present in both rows → excluded from mostWatched',
        () async {
      // Fixture: 4 streams, all played with distinct timestamps.
      // Counts: 20=3, 10=5, 30=1, 40=2. Recency: 20 (most
      // recent), 40, 10, 30. Most-watched raw (count desc, ties
      // broken by streamId asc): 10 (5), 20 (3), 40 (2), 30 (1).
      // Excluding recency-top-8 = {20, 40, 10, 30} → empty.
      // That's not what this test wants.
      //
      // For stream 10 to be in most-watched but NOT in recency-top-8,
      // we need at least 9 streams so stream 10 is bumped out of the
      // recency top-8 by the 8 more-recent ones. Use 10 streams.
      // Counts: 10=10, 20=3, 30=1, 40=2, 50=5. Timestamps: 50
      // newest, 20 next, 40 next, 10 oldest. Recency top-8 includes
      // 50, 20, 40, 10, and four others (30, 60, 70, 80 with count
      // 1 each). 10 is in the recency top-8 too. Hmm.
      //
      // Simpler: 9 streams, 10 has the highest count, 20 is the
      // most recent. Recency top-8 = {20, 90, 80, 70, 60, 50, 40,
      // 30} (10 is the oldest, bumped out). Most-watched raw = {10
      // (10), 20 (3), 30 (1), 40 (1), 50 (1), 60 (1), 70 (1), 80
      // (1), 90 (1)}. Excluding recency-top-8 = {10}. So
      // most-watched = [10] — 10 is preserved (not in recency), 20
      // is excluded (in recency).
      final t = DateTime(2026, 6, 10, 9);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final playStore = PlayCountStore(prefs);
      // Stream 10: count 10, oldest. Loop 10 times at t.
      for (var i = 0; i < 10; i++) {
        await playStore.increment(profileId: 'conn', streamId: 10, at: t);
      }
      // Stream 20: count 3, most recent. Loop 3 times at t+90m.
      for (var i = 0; i < 3; i++) {
        await playStore.increment(
          profileId: 'conn', streamId: 20,
          at: t.add(const Duration(minutes: 90)),
        );
      }
      // Streams 30-90: count 1 each, mid-recency timestamps.
      for (var s in [30, 40, 50, 60, 70, 80, 90]) {
        await playStore.increment(
          profileId: 'conn', streamId: s,
          at: t.add(Duration(minutes: s ~/ 2)),
        );
      }

      final credsStore = _FakeCredentialsStore(activeName: 'conn');
      final profileStore = ProfileStore(prefs);
      WatchProgressStore(prefs);
      await profileStore.addProfile(name: 'conn');
      final live = <XtreamStream>[
        for (var i = 10; i <= 90; i += 10)
          XtreamStream(
            streamId: i, name: 'Ch$i', categoryId: 1, streamType: 'live',
          ),
      ];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(profileStore),
          credentialsStoreProvider.overrideWithValue(credsStore),
          playCountStoreProvider.overrideWithValue(playStore),
          liveStreamsProvider.overrideWith((ref) async => live),
        ],
      );
      addTearDown(container.dispose);

      // Recency: 20 (newest), 90, 80, 70, 60, 50, 40, 30, 10.
      final recent = await container.read(recentlyPlayedProvider.future);
      final recencyTop8 = recent
          .take(kPersonalisationRowCap)
          .map((e) => e.stream.streamId)
          .toList();
      // Stream 20 is the most recent. Stream 10 is the oldest so
      // it falls outside the top-8.
      expect(recencyTop8.first, 20);
      expect(recencyTop8, isNot(contains(10)));

      // Most-watched: 10 (count 10) is preserved. 20 (count 3) is
      // excluded. The remaining mid-recency streams 30-90 have
      // count 1 each, sorted by streamId asc.
      final top = await container.read(mostWatchedProvider.future);
      expect(top.first.stream.streamId, 10);
      expect(top.map((e) => e.stream.streamId), isNot(contains(20)));
      expect(top.first.count, 10);
    });

    test('most-watched set with no recency overlap (overridden) → unchanged',
        () async {
      // Override recency to return empty so dedupe is a no-op.
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 10, name: 'A', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 20, name: 'B', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 30, name: 'C', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn',
        playCounts: {10: 1, 20: 2, 30: 3},
        extraOverrides: [
          recentlyPlayedProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(container.dispose);

      final top = await container.read(mostWatchedProvider.future);
      expect(top.length, 3);
      expect(top[0].stream.streamId, 30);
      expect(top[1].stream.streamId, 20);
      expect(top[2].stream.streamId, 10);
    });

    test('most-watched preserved up to kPersonalisationRowCap (8) when recency is empty',
        () async {
      // Override recency to empty so the full top-8 most-watched
      // surfaces, exercising the row cap.
      // Counts: stream 12 → 12 plays, stream 1 → 1 play.
      final live = <XtreamStream>[
        for (var i = 1; i <= 12; i++)
          XtreamStream(
            streamId: i, name: 'Ch$i', categoryId: 1, streamType: 'live',
          ),
      ];
      final playCounts = <int, int>{
        1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6,
        7: 7, 8: 8, 9: 9, 10: 10, 11: 11, 12: 12,
      };
      final container = await makeContainer(
        liveStreams: live,
        activeConnectionName: 'conn',
        playCounts: playCounts,
        extraOverrides: [
          recentlyPlayedProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(container.dispose);

      final top = await container.read(mostWatchedProvider.future);
      expect(top.length, kPersonalisationRowCap);
      expect(top.first.stream.streamId, 12);
      expect(top.last.stream.streamId, 5);
    });

    test('excluded stream keeps its count but disappears from the row',
        () async {
      // Stream 20 is the most recent + has the highest count. Stream
      // 10 is the oldest + has a low count.
      // Use a third stream (30) with a count between the two, played
      // at an intermediate timestamp — recency will be {20, 30, 10}.
      // Most-watched raw = {20 (10), 30 (5), 10 (1)}. Excluding
      // recency-top-8 = {20, 30, 10} → most-watched is empty.
      // That's not what this test wants.
      //
      // The right fixture: stream 20 is in recency AND most-watched;
      // stream 10 is ONLY in most-watched (not in recency). To
      // achieve that with increment-always-stamps-timestamp, we need
      // stream 10 to have count 0. But count 0 means it never
      // appears in topEntries at all (topEntries filters `count > 0`).
      //
      // So the cleanest fixture is to have stream 20 in recency (the
      // recency top-1) and stream 10 outside recency (it gets bumped
      // to recency top-2 or lower). This requires more than 2
      // streams so the recency top-N doesn't cover stream 10.
      //
      // 3 streams: 10 (count 1, old), 20 (count 10, mid), 30 (count 1,
      // new). Recency: 30 (new), 20 (mid), 10 (old). Most-watched
      // raw: 20 (10), 10 (1), 30 (1). Excluding recency-top-8 = {30,
      // 20, 10} → empty.
      //
      // The "disjoint recency" test fixture covers this case. For
      // THIS test, the realistic case is: stream 20 is the most
      // recent, but stream 10 is older than kPersonalisationRowCap
      // (so it's outside the recency top-8). Use 9+ streams.
      final t = DateTime(2026, 6, 10, 9);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final playStore = PlayCountStore(prefs);
      // 10 streams. Stream 20 has count 10 and is the most recent.
      // Streams 1-10 are all played once, with stream 20 the most
      // recent. Recency order (newest first): 20, 10, 9, 8, 7, 6,
      // 5, 4, 3, 2, 1. Top-8 = {20, 10, 9, 8, 7, 6, 5, 4}.
      // Most-watched raw (count desc): 20 (10), then 1-10 (1 each,
      // sorted by streamId asc) = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10.
      // Excluding recency-top-8 = {20, 10, 9, 8, 7, 6, 5, 4} →
      // most-watched = {1, 2, 3}. Three entries, none is 20.
      // That demonstrates the exclusion of the high-count stream.
      for (var i = 1; i <= 10; i++) {
        // Stream i gets one play at t + i minutes — stream 10 is
        // most recent, stream 1 is oldest.
        await playStore.increment(
          profileId: 'conn', streamId: i,
          at: t.add(Duration(minutes: i)),
        );
      }
      // Now bump stream 20's count to 10. We need a separate stream
      // ID for the high-count one — call it stream 20.
      for (var i = 0; i < 10; i++) {
        await playStore.increment(
          profileId: 'conn', streamId: 20,
          at: t.add(const Duration(minutes: 20)),
        );
      }

      final credsStore = _FakeCredentialsStore(activeName: 'conn');
      final profileStore = ProfileStore(prefs);
      WatchProgressStore(prefs);
      await profileStore.addProfile(name: 'conn');
      final live = <XtreamStream>[
        for (var i = 1; i <= 20; i++)
          XtreamStream(
            streamId: i, name: 'Ch$i', categoryId: 1, streamType: 'live',
          ),
      ];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(profileStore),
          credentialsStoreProvider.overrideWithValue(credsStore),
          playCountStoreProvider.overrideWithValue(playStore),
          liveStreamsProvider.overrideWith((ref) async => live),
        ],
      );
      addTearDown(container.dispose);

      // Sanity: the count for stream 20 is preserved (10).
      final store = container.read(playCountStoreProvider);
      expect(store.getCount(profileId: 'conn', streamId: 20), 10);

      // Recency: stream 20 is most recent (t+20m), then stream 10
      // (t+10m), then 9 (t+9m), ..., 1 (t+1m). Top-8 = {20, 10, 9,
      // 8, 7, 6, 5, 4}.
      final recent = await container.read(recentlyPlayedProvider.future);
      final recencyTop8 = recent
          .take(kPersonalisationRowCap)
          .map((e) => e.stream.streamId)
          .toSet();
      expect(recencyTop8, contains(20));
      expect(recencyTop8, isNot(contains(1)));
      expect(recencyTop8, isNot(contains(2)));
      expect(recencyTop8, isNot(contains(3)));

      // Most-watched: stream 20 (count 10) is excluded. The
      // remaining top entries (by count then streamId) are 1, 2, 3
      // (all count 1, streamId asc), then 4, 5, 6, 7 are excluded
      // (in recency), then 8, 9, 10 also excluded. So result = {1,
      // 2, 3}.
      final top = await container.read(mostWatchedProvider.future);
      expect(top.map((e) => e.stream.streamId).toList(), [1, 2, 3]);
    });

    test('no active connection → mostWatched empty (regression check)', () async {
      // Sanity: the dedupe logic must not break the "no connection"
      // early-return path.
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'A', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: null,
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedProvider.future);
      expect(result, isEmpty);
    });

    test('live streams empty → mostWatched empty (regression check)', () async {
      // Sanity: the dedupe logic must not break the "no live streams"
      // early-return path.
      final container = await makeContainer(
        liveStreams: const [],
        activeConnectionName: 'conn',
        playCounts: {1: 3},
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedProvider.future);
      expect(result, isEmpty);
    });
  });
}
