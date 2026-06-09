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
/// `most_watched_test.dart` so the V09 sort-mode tests are
/// self-contained even if the V05 tests are reorganised.
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
  // A deliberately unsorted, mixed-play-count stream fixture.
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

  Future<ProviderContainer> makeContainer({
    required Map<int, int> playCounts,
    String? activeConnectionName,
    int? categoryId,
    List<int> favourites = const [],
    bool favouritesOnly = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final playStore = PlayCountStore(prefs);
    if (activeConnectionName != null) {
      for (final e in playCounts.entries) {
        for (var i = 0; i < e.value; i++) {
          await playStore.increment(
            profileId: activeConnectionName, streamId: e.key,
          );
        }
      }
    }
    final credsStore = _FakeCredentialsStore(activeName: activeConnectionName);
    final profileStore = ProfileStore(prefs);
    // Touching WatchProgressStore so sharedPreferences is initialised
    // for downstream providers.
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
        channelSortProvider.overrideWith((ref) => ChannelSortMode.mostWatched),
        if (categoryId != null)
          selectedCategoryIdProvider.overrideWith((ref) => categoryId),
        if (favouritesOnly)
          favouritesOnlyProvider.overrideWith((ref) => true),
      ],
    );
  }

  group('mostWatched sort mode (V09)', () {
    test('orders played streams by count desc, with ties broken by name',
        () async {
      // Play counts chosen so 2 > 4 > 1, with 3 and 5 unplayed.
      final container = await makeContainer(
        activeConnectionName: 'conn',
        playCounts: {1: 2, 2: 5, 4: 3},
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      // Expected order:
      //   CNN (id 2, count 5) — top
      //   Al Jazeera (id 4, count 3)
      //   BBC One (id 1, count 2)
      //   Sky News (id 5, unplayed, name asc)
      //   Zulu TV (id 3, unplayed, name asc)
      expect(
        result.map((s) => s.streamId).toList(),
        [2, 4, 1, 5, 3],
      );
    });

    test('unplayed streams sort by name asc as a stable secondary key',
        () async {
      // Only stream 2 is played. The remaining four should be
      // sorted by name (case-insensitive ascending) at the bottom.
      final container = await makeContainer(
        activeConnectionName: 'conn',
        playCounts: {2: 1},
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      // First: CNN (played).
      expect(result.first.streamId, 2);
      // Tail (unplayed, name asc): Al Jazeera (4), BBC One (1),
      // Sky News (5), Zulu TV (3).
      expect(
        result.skip(1).map((s) => s.streamId).toList(),
        [4, 1, 5, 3],
      );
    });

    test('ties in play count fall back to name asc (not streamId asc)',
        () async {
      // All four "played" streams have count 1; the unplayed one
      // (stream 5) goes to the bottom. The four played ones should
      // sort by name asc since their counts are tied.
      final container = await makeContainer(
        activeConnectionName: 'conn',
        playCounts: {1: 1, 2: 1, 3: 1, 4: 1},
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      // Played (count 1, name asc): Al Jazeera (4), BBC One (1),
      // CNN (2), Zulu TV (3). Unplayed at the bottom: Sky News (5).
      expect(
        result.map((s) => s.streamId).toList(),
        [4, 1, 2, 3, 5],
      );
    });

    test('no play counts recorded: behaves like default order with name asc',
        () async {
      final container = await makeContainer(
        activeConnectionName: 'conn',
        playCounts: const {},
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      // Every stream is unplayed → all sink to the bottom bucket
      // and sort by name asc.
      expect(
        result.map((s) => s.name).toList(),
        ['Al Jazeera', 'BBC One', 'CNN', 'Sky News', 'Zulu TV'],
      );
    });

    test('no active connection: degrades to default order (no crash)',
        () async {
      final container = await makeContainer(
        activeConnectionName: null,
        playCounts: const {1: 5},
      );
      addTearDown(container.dispose);
      // Should not throw. Falls back to default order.
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(
        result.map((s) => s.streamId).toList(),
        [1, 2, 3, 4, 5],
      );
    });

    test('composes with category filter: only category streams are sorted',
        () async {
      // categoryId 20 → CNN (2), Zulu TV (3), Sky News (5).
      // Play counts: CNN 5, Zulu TV 2, Sky News 0. Expected order:
      // CNN (5), Zulu TV (2), Sky News (unplayed → bottom).
      final container = await makeContainer(
        activeConnectionName: 'conn',
        playCounts: {2: 5, 3: 2},
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
      // Favourites in cat 20: stream 3 (Zulu TV, played 2), stream 5
      // (Sky News, unplayed). Expected: Zulu TV first (played),
      // Sky News second (unplayed).
      final container = await makeContainer(
        activeConnectionName: 'conn',
        playCounts: {3: 2},
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

    test('is per-profile: counts from another profile are invisible', () async {
      // Seed play counts under "conn-A" but switch the active
      // connection to "conn-B" mid-test. The new active profile has
      // no recorded plays, so every stream ends up unplayed and
      // sorts by name asc.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final playStore = PlayCountStore(prefs);
      await playStore.increment(profileId: 'conn-A', streamId: 1);
      await playStore.increment(profileId: 'conn-A', streamId: 1);
      await playStore.increment(profileId: 'conn-A', streamId: 2);

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
          channelSortProvider.overrideWith((ref) => ChannelSortMode.mostWatched),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      // "conn-B" has no counts → name asc.
      expect(
        result.map((s) => s.name).toList(),
        ['Al Jazeera', 'BBC One', 'CNN', 'Sky News', 'Zulu TV'],
      );
    });

    test('runtime: switching to mostWatched re-sorts an already-loaded list',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final playStore = PlayCountStore(prefs);
      await playStore.increment(profileId: 'conn', streamId: 3);
      await playStore.increment(profileId: 'conn', streamId: 3);
      await playStore.increment(profileId: 'conn', streamId: 1);

      final credsStore = _FakeCredentialsStore(activeName: 'conn');
      final profileStore = ProfileStore(prefs);
      await profileStore.addProfile(name: 'conn');
      WatchProgressStore(prefs);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(profileStore),
          credentialsStoreProvider.overrideWithValue(credsStore),
          playCountStoreProvider.overrideWithValue(playStore),
          xtreamClientProvider.overrideWithValue(_FakeXtreamClient(streams)),
          // Start in default order.
          channelSortProvider.overrideWith((ref) => ChannelSortMode.defaultOrder),
        ],
      );
      addTearDown(container.dispose);
      final initial = await container.read(filteredLiveStreamsProvider.future);
      expect(initial.map((s) => s.streamId).toList(), [1, 2, 3, 4, 5]);

      // Switch to most-watched.
      container.read(channelSortProvider.notifier).state =
          ChannelSortMode.mostWatched;
      final resorted = await container.read(filteredLiveStreamsProvider.future);
      // Zulu TV (3) has count 2, BBC One (1) has count 1. The rest
      // are unplayed → bottom, name asc: Al Jazeera (4), CNN (2),
      // Sky News (5).
      expect(
        resorted.map((s) => s.streamId).toList(),
        [3, 1, 4, 2, 5],
      );
    });
  });
}
