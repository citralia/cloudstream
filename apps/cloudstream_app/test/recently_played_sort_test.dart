import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/channel_sort_store.dart';
import 'package:cloudstream_app/core/storage/play_count_store.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/core/storage/watch_progress_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

/// In-memory [CredentialsStore] fake. Mirrors the helper in
/// `most_watched_sort_test.dart` so V16's sort-mode tests are
/// self-contained even if the V09 tests are reorganised.
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

/// Test double for [XtreamApiClient] that returns a fixed stream list
/// regardless of category filter.
class _FakeXtreamClient extends XtreamApiClient {
  _FakeXtreamClient(this._streams);

  final List<XtreamStream> _streams;

  @override
  Future<List<XtreamStream>> getLiveStreams({int? categoryId}) async {
    if (categoryId == null) return _streams;
    return _streams.where((s) => s.categoryId == categoryId).toList();
  }
}

void main() {
  // A deliberately unsorted stream fixture. The "natural" order is
  // 1, 2, 3, 4, 5; the recency tests deliberately shuffle plays so
  // the expected order is NOT the natural order.
  const streams = [
    XtreamStream(streamId: 1, name: 'BBC One', categoryId: 10,
        streamType: 'live', number: 101),
    XtreamStream(streamId: 2, name: 'CNN', categoryId: 20,
        streamType: 'live', number: 200),
    XtreamStream(streamId: 3, name: 'Zulu TV', categoryId: 20,
        streamType: 'live', number: 50),
    XtreamStream(streamId: 4, name: 'Al Jazeera', categoryId: 10,
        streamType: 'live', number: 77),
    XtreamStream(streamId: 5, name: 'Sky News', categoryId: 20,
        streamType: 'live'), // number == null
  ];

  group('PlayCountStore last-played timestamp (V16)', () {
    late PlayCountStore store;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = PlayCountStore(prefs);
    });

    test('getLastPlayedAtMs returns null for never-played stream', () {
      expect(
        store.getLastPlayedAtMs(profileId: 'p', streamId: 1),
        isNull,
      );
    });

    test('increment stamps the current time as the last-played timestamp',
        () async {
      // Pin a specific instant so the assertion is stable.
      final t0 = DateTime.utc(2026, 6, 10, 12, 0, 0);
      final next = await store.increment(
        profileId: 'p', streamId: 7, at: t0,
      );
      expect(next, 1);
      expect(
        store.getLastPlayedAtMs(profileId: 'p', streamId: 7),
        t0.millisecondsSinceEpoch,
      );
      expect(store.getCount(profileId: 'p', streamId: 7), 1);
    });

    test('subsequent increments overwrite the timestamp and bump the count',
        () async {
      final t0 = DateTime.utc(2026, 6, 10, 12, 0, 0);
      final t1 = DateTime.utc(2026, 6, 10, 14, 30, 0);
      await store.increment(profileId: 'p', streamId: 7, at: t0);
      await store.increment(profileId: 'p', streamId: 7, at: t1);
      expect(store.getCount(profileId: 'p', streamId: 7), 2);
      expect(
        store.getLastPlayedAtMs(profileId: 'p', streamId: 7),
        t1.millisecondsSinceEpoch,
      );
    });

    test('recentEntries returns played streams sorted by recency desc', () async {
      final t0 = DateTime.utc(2026, 6, 1, 0, 0, 0);
      final t1 = DateTime.utc(2026, 6, 5, 0, 0, 0);
      final t2 = DateTime.utc(2026, 6, 10, 0, 0, 0);
      await store.increment(profileId: 'p', streamId: 1, at: t0); // oldest
      await store.increment(profileId: 'p', streamId: 2, at: t2); // newest
      await store.increment(profileId: 'p', streamId: 3, at: t1); // middle
      final recents = store.recentEntries('p');
      expect(
        recents.map((e) => e.streamId).toList(),
        [2, 3, 1],
      );
      expect(
        recents.map((e) => e.lastPlayedAtMs).toList(),
        [t2.millisecondsSinceEpoch, t1.millisecondsSinceEpoch, t0.millisecondsSinceEpoch],
      );
    });

    test('recentEntries is empty when nothing has been played', () {
      expect(store.recentEntries('p'), isEmpty);
    });

    test('recentEntries breaks ties on timestamp by streamId asc', () async {
      final t = DateTime.utc(2026, 6, 10, 0, 0, 0);
      // All four played at the same instant.
      await store.increment(profileId: 'p', streamId: 4, at: t);
      await store.increment(profileId: 'p', streamId: 2, at: t);
      await store.increment(profileId: 'p', streamId: 1, at: t);
      await store.increment(profileId: 'p', streamId: 3, at: t);
      final recents = store.recentEntries('p');
      expect(
        recents.map((e) => e.streamId).toList(),
        [1, 2, 3, 4],
      );
    });

    test('recentEntries is per-profile (invisible to other profiles)', () async {
      final t = DateTime.utc(2026, 6, 10, 0, 0, 0);
      await store.increment(profileId: 'p-A', streamId: 1, at: t);
      await store.increment(profileId: 'p-A', streamId: 2, at: t);
      expect(store.recentEntries('p-A').length, 2);
      expect(store.recentEntries('p-B'), isEmpty);
    });

    test('clearCount removes both count and last-played stamp', () async {
      final t = DateTime.utc(2026, 6, 10, 0, 0, 0);
      await store.increment(profileId: 'p', streamId: 1, at: t);
      expect(store.getCount(profileId: 'p', streamId: 1), 1);
      expect(
        store.getLastPlayedAtMs(profileId: 'p', streamId: 1),
        t.millisecondsSinceEpoch,
      );
      await store.clearCount(profileId: 'p', streamId: 1);
      expect(store.getCount(profileId: 'p', streamId: 1), 0);
      expect(
        store.getLastPlayedAtMs(profileId: 'p', streamId: 1),
        isNull,
      );
      expect(store.recentEntries('p'), isEmpty);
    });

    test('legacy v0.1.x–v0.1.48 entry (count but no last-played stamp) is '
        'still surfaced by recentEntries with epoch-0', () async {
      // Simulate a legacy install: a count key but no last-played key.
      await prefs.setInt('play_count_legacy_1', 5);
      // No `play_last_legacy_1` set.
      final recents = store.recentEntries('legacy');
      expect(recents.length, 1);
      expect(recents.first.streamId, 1);
      expect(recents.first.lastPlayedAtMs, 0);
    });
  });

  group('recentlyPlayed sort mode (V16)', () {
    Future<ProviderContainer> makeContainer({
      required Map<int, DateTime> lastPlayed,
      String? activeConnectionName,
      int? categoryId,
      List<int> favourites = const [],
      bool favouritesOnly = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final playStore = PlayCountStore(prefs);
      if (activeConnectionName != null) {
        for (final e in lastPlayed.entries) {
          // Each entry is one play at the given timestamp; multiple
          // plays on the same stream would need an extra loop, but
          // recentEntries() always orders by the *last* timestamp
          // (increment overwrites), so one increment is enough to
          // test ordering.
          await playStore.increment(
            profileId: activeConnectionName,
            streamId: e.key,
            at: e.value,
          );
        }
      }
      final credsStore = _FakeCredentialsStore(activeName: activeConnectionName);
      final profileStore = ProfileStore(prefs);
      WatchProgressStore(prefs);
      if (activeConnectionName != null) {
        final profile = await profileStore.addProfile(name: activeConnectionName);
        for (final id in favourites) {
          await profileStore.addFavourite(profile.id, id);
        }
      }
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(profileStore),
          credentialsStoreProvider.overrideWithValue(credsStore),
          playCountStoreProvider.overrideWithValue(playStore),
          xtreamClientProvider.overrideWithValue(_FakeXtreamClient(streams)),
          channelSortProvider.overrideWith((ref) => ChannelSortMode.recentlyPlayed),
          if (categoryId != null)
            selectedCategoryIdProvider.overrideWith((ref) => categoryId),
          if (favouritesOnly)
            favouritesOnlyProvider.overrideWith((ref) => true),
        ],
      );
    }

    test('orders played streams by recency desc, ties broken by streamId asc',
        () async {
      // 2 most recent, then 4, then 1. 3 and 5 unplayed → bottom,
      // sorted by name asc (Al Jazeera=4 played, so the bottom is
      // just Zulu TV=3 and Sky News=5).
      final t0 = DateTime.utc(2026, 6, 1, 0, 0, 0);
      final t1 = DateTime.utc(2026, 6, 5, 0, 0, 0);
      final t2 = DateTime.utc(2026, 6, 10, 0, 0, 0);
      final container = await makeContainer(
        activeConnectionName: 'conn',
        lastPlayed: {1: t0, 2: t2, 4: t1},
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      // Played bucket: CNN (2, t2) → Al Jazeera (4, t1) → BBC One (1, t0).
      // Unplayed bucket (name asc): Sky News (5) → Zulu TV (3).
      expect(
        result.map((s) => s.streamId).toList(),
        [2, 4, 1, 5, 3],
      );
    });

    test('no plays recorded: every stream is unplayed, sorts by name asc',
        () async {
      final container = await makeContainer(
        activeConnectionName: 'conn',
        lastPlayed: const {},
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(
        result.map((s) => s.name).toList(),
        ['Al Jazeera', 'BBC One', 'CNN', 'Sky News', 'Zulu TV'],
      );
    });

    test('no active connection: degrades to default order (no crash)',
        () async {
      final container = await makeContainer(
        activeConnectionName: null,
        lastPlayed: {1: DateTime.utc(2026, 6, 10)},
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(
        result.map((s) => s.streamId).toList(),
        [1, 2, 3, 4, 5],
      );
    });

    test('composes with category filter: only category streams are sorted',
        () async {
      // categoryId 20 → CNN (2), Zulu TV (3), Sky News (5).
      // Recent: CNN (t2), Zulu TV (t1). Sky News unplayed → bottom.
      final t1 = DateTime.utc(2026, 6, 1, 0, 0, 0);
      final t2 = DateTime.utc(2026, 6, 10, 0, 0, 0);
      final container = await makeContainer(
        activeConnectionName: 'conn',
        lastPlayed: {2: t2, 3: t1},
        categoryId: 20,
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(
        result.map((s) => s.streamId).toList(),
        [2, 3, 5],
      );
    });

    test('composes with favourites-only filter', () async {
      // Favourites in cat 20: stream 3 (Zulu TV, played t1), stream 5
      // (Sky News, unplayed). Expected: Zulu TV first (played),
      // Sky News second (unplayed).
      final t1 = DateTime.utc(2026, 6, 10, 0, 0, 0);
      final container = await makeContainer(
        activeConnectionName: 'conn',
        lastPlayed: {3: t1},
        categoryId: 20,
        favourites: [3, 5],
        favouritesOnly: true,
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(
        result.map((s) => s.streamId).toList(),
        [3, 5],
      );
    });

    test('is per-profile: recency from another profile is invisible',
        () async {
      // Seed recency under "conn-A" but switch the active connection
      // to "conn-B" mid-test. The new active profile has no recorded
      // plays, so every stream ends up unplayed and sorts by name asc.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final playStore = PlayCountStore(prefs);
      await playStore.increment(
        profileId: 'conn-A', streamId: 1,
        at: DateTime.utc(2026, 6, 10),
      );
      await playStore.increment(
        profileId: 'conn-A', streamId: 2,
        at: DateTime.utc(2026, 6, 11),
      );

      final credsStore = _FakeCredentialsStore(activeName: 'conn-B');
      final profileStore = ProfileStore(prefs);
      await profileStore.addProfile(name: 'conn-B');
      WatchProgressStore(prefs);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(profileStore),
          credentialsStoreProvider.overrideWithValue(credsStore),
          playCountStoreProvider.overrideWithValue(playStore),
          xtreamClientProvider.overrideWithValue(_FakeXtreamClient(streams)),
          channelSortProvider.overrideWith((ref) => ChannelSortMode.recentlyPlayed),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      // conn-B has no plays → every stream is unplayed → name asc.
      expect(
        result.map((s) => s.name).toList(),
        ['Al Jazeera', 'BBC One', 'CNN', 'Sky News', 'Zulu TV'],
      );
    });

    test('coexists with mostWatched: switching modes re-sorts the same list',
        () async {
      // One stream is played often (3 times — old timestamp), one is
      // played once (new timestamp). The two modes should rank them
      // differently:
      //   mostWatched → stream 2 (count 3) > stream 4 (count 1)
      //   recentlyPlayed → stream 4 (played t2) > stream 2 (played t0)
      final t0 = DateTime.utc(2026, 6, 1, 0, 0, 0);
      final t2 = DateTime.utc(2026, 6, 10, 0, 0, 0);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final playStore = PlayCountStore(prefs);
      // Three plays on stream 2 (oldest), one play on stream 4 (newest).
      await playStore.increment(profileId: 'conn', streamId: 2, at: t0);
      await playStore.increment(profileId: 'conn', streamId: 2, at: t0);
      await playStore.increment(profileId: 'conn', streamId: 2, at: t0);
      await playStore.increment(profileId: 'conn', streamId: 4, at: t2);
      final credsStore = _FakeCredentialsStore(activeName: 'conn');
      final profileStore = ProfileStore(prefs);
      await profileStore.addProfile(name: 'conn');
      WatchProgressStore(prefs);

      Future<List<int>> runWith(ChannelSortMode mode) async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            profileStoreProvider.overrideWithValue(profileStore),
            credentialsStoreProvider.overrideWithValue(credsStore),
            playCountStoreProvider.overrideWithValue(playStore),
            xtreamClientProvider.overrideWithValue(_FakeXtreamClient(streams)),
            channelSortProvider.overrideWith((ref) => mode),
          ],
        );
        addTearDown(container.dispose);
        final r = await container.read(filteredLiveStreamsProvider.future);
        return r.map((s) => s.streamId).toList();
      }

      final byCount = await runWith(ChannelSortMode.mostWatched);
      final byRecency = await runWith(ChannelSortMode.recentlyPlayed);
      // By count: 2 (3 plays) > 4 (1 play) > unplayed name asc.
      expect(byCount.take(2).toList(), [2, 4]);
      // By recency: 4 (t2) > 2 (t0) > unplayed name asc.
      expect(byRecency.take(2).toList(), [4, 2]);
    });
  });
}
