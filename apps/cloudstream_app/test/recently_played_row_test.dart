import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/play_count_store.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/core/storage/watch_progress_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

/// In-memory [CredentialsStore] fake. Holds a single named connection
/// (matching the pattern used by `most_watched_test.dart`).
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
  group('recentlyPlayedProvider', () {
    Future<ProviderContainer> makeContainer({
      required List<XtreamStream> liveStreams,
      String? activeConnectionName,
      Map<int, DateTime> playTimestamps = const {},
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Pre-seed play counts at fixed timestamps so the recency order
      // is deterministic across runs.
      final playStore = PlayCountStore(prefs);
      for (final entry in playTimestamps.entries) {
        if (activeConnectionName == null) continue;
        // V16's `increment(at:)` lets us inject a fixed timestamp.
        await playStore.increment(
          profileId: activeConnectionName,
          streamId: entry.key,
          at: entry.value,
        );
      }

      final credsStore = _FakeCredentialsStore(activeName: activeConnectionName);
      final profileStore = ProfileStore(prefs);
      // Touching WatchProgressStore so sharedPreferences is initialised
      // for downstream providers.
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
        ],
      );
    }

    test('returns empty list when no plays are recorded', () async {
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'Channel A', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);
      final result = await container.read(recentlyPlayedProvider.future);
      expect(result, isEmpty);
    });

    test('returns empty list when there is no active connection', () async {
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'Channel A', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: null,
        playTimestamps: {1: DateTime(2026, 6, 10, 9)},
      );
      addTearDown(container.dispose);
      final result = await container.read(recentlyPlayedProvider.future);
      expect(result, isEmpty);
    });

    test('returns empty list when live streams are not yet loaded', () async {
      final container = await makeContainer(
        liveStreams: const [],
        activeConnectionName: 'conn',
        playTimestamps: {1: DateTime(2026, 6, 10, 9)},
      );
      addTearDown(container.dispose);
      final result = await container.read(recentlyPlayedProvider.future);
      expect(result, isEmpty);
    });

    test('orders by recency desc, then by streamId asc', () async {
      final t = DateTime(2026, 6, 10, 9);
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 10, name: 'Channel A', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 20, name: 'Channel B', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 30, name: 'Channel C', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn',
        // 30 played first, 20 second, 10 third → recency order should
        // be 10, 20, 30 (most recent first).
        playTimestamps: {30: t, 20: t.add(const Duration(minutes: 1)), 10: t.add(const Duration(minutes: 2))},
      );
      addTearDown(container.dispose);
      final result = await container.read(recentlyPlayedProvider.future);
      expect(result.length, 3);
      expect(result[0].stream.streamId, 10);
      expect(result[1].stream.streamId, 20);
      expect(result[2].stream.streamId, 30);
    });

    test('breaks ties on timestamp with streamId asc', () async {
      // Three streams played in the exact same instant — recency
      // order should fall back to streamId asc (10, 20, 30).
      final t = DateTime(2026, 6, 10, 9);
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 10, name: 'Channel A', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 20, name: 'Channel B', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 30, name: 'Channel C', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn',
        playTimestamps: {30: t, 20: t, 10: t},
      );
      addTearDown(container.dispose);
      final result = await container.read(recentlyPlayedProvider.future);
      expect(result.length, 3);
      expect(result[0].stream.streamId, 10);
      expect(result[1].stream.streamId, 20);
      expect(result[2].stream.streamId, 30);
    });

    test('drops stream IDs that no longer exist in the live list', () async {
      // Play recorded for stream 999, but the loaded list has no such
      // stream — that entry should be silently dropped.
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'Channel A', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn',
        playTimestamps: {1: DateTime(2026, 6, 10, 9), 999: DateTime(2026, 6, 10, 9)},
      );
      addTearDown(container.dispose);
      final result = await container.read(recentlyPlayedProvider.future);
      expect(result, hasLength(1));
      expect(result.single.stream.streamId, 1);
    });

    test('isolates recency by active connection name', () async {
      // First connection has a recent stream; second has nothing.
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'Channel A', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn-A',
        playTimestamps: {1: DateTime(2026, 6, 10, 9)},
      );
      addTearDown(container.dispose);
      final result = await container.read(recentlyPlayedProvider.future);
      expect(result, hasLength(1));

      // Switch connection: counts are isolated by name, so this should
      // return empty even though "conn-A" has counts.
      final store = container.read(playCountStoreProvider);
      expect(store.recentEntries('conn-B'), isEmpty);
    });

    test('exposes the lastPlayedAtMs timestamp on each entry', () async {
      final t = DateTime.fromMillisecondsSinceEpoch(1749560000000); // fixed epoch ms
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 42, name: 'Channel A', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn',
        playTimestamps: {42: t},
      );
      addTearDown(container.dispose);
      final result = await container.read(recentlyPlayedProvider.future);
      expect(result, hasLength(1));
      expect(result.single.lastPlayedAtMs, t.millisecondsSinceEpoch);
      expect(result.single.stream.streamId, 42);
    });

    test('ranks recency independent of play count', () async {
      // Stream 10 has count 5 but is the oldest. Stream 20 has count 1
      // but is the most recent. recentlyPlayedProvider should put 20
      // first; mostWatchedProvider would put 10 first.
      final t = DateTime(2026, 6, 10, 9);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final playStore = PlayCountStore(prefs);
      for (var i = 0; i < 5; i++) {
        await playStore.increment(profileId: 'conn', streamId: 10, at: t);
      }
      await playStore.increment(
        profileId: 'conn', streamId: 20,
        at: t.add(const Duration(hours: 1)),
      );
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
          liveStreamsProvider.overrideWith((ref) async => const [
                XtreamStream(streamId: 10, name: 'Channel A', categoryId: 1, streamType: 'live'),
                XtreamStream(streamId: 20, name: 'Channel B', categoryId: 1, streamType: 'live'),
              ]),
        ],
      );
      addTearDown(container.dispose);

      final recent = await container.read(recentlyPlayedProvider.future);
      expect(recent.first.stream.streamId, 20); // recency winner

      final top = await container.read(mostWatchedProvider.future);
      expect(top.first.stream.streamId, 10); // count winner
    });
  });
}
