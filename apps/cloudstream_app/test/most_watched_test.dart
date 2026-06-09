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
/// (matching the pattern used by `continue_watching_test.dart`).
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
  group('PlayCountStore', () {
    late PlayCountStore store;
    const profileId = 'conn-1';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = PlayCountStore(prefs);
    });

    test('getCount returns 0 for never-played streams', () {
      expect(store.getCount(profileId: profileId, streamId: 42), 0);
    });

    test('increment bumps the count and returns the new value', () async {
      final n1 = await store.increment(profileId: profileId, streamId: 42);
      expect(n1, 1);
      final n2 = await store.increment(profileId: profileId, streamId: 42);
      expect(n2, 2);
      expect(store.getCount(profileId: profileId, streamId: 42), 2);
    });

    test('isolates counts by profile id', () async {
      await store.increment(profileId: 'conn-1', streamId: 42);
      await store.increment(profileId: 'conn-1', streamId: 42);
      await store.increment(profileId: 'conn-2', streamId: 42);
      expect(store.getCount(profileId: 'conn-1', streamId: 42), 2);
      expect(store.getCount(profileId: 'conn-2', streamId: 42), 1);
    });

    test('topEntries returns nothing when no entries exist', () {
      expect(store.topEntries(profileId), isEmpty);
    });

    test('topEntries orders by count desc, then by streamId asc', () async {
      await store.increment(profileId: profileId, streamId: 10); // → 1
      await store.increment(profileId: profileId, streamId: 10); // → 2
      await store.increment(profileId: profileId, streamId: 20); // → 1
      await store.increment(profileId: profileId, streamId: 30); // → 1
      await store.increment(profileId: profileId, streamId: 5);  // → 1
      final out = store.topEntries(profileId);
      expect(out.length, 4);
      // stream 10 leads (count=2). The other three are tied at 1 — sort
      // falls back to streamId asc, so order is 5, 20, 30.
      expect(out[0].streamId, 10);
      expect(out[0].count, 2);
      expect(out[1].streamId, 5);
      expect(out[2].streamId, 20);
      expect(out[3].streamId, 30);
    });

    test('topEntries isolates by profile id', () async {
      await store.increment(profileId: 'a', streamId: 1);
      await store.increment(profileId: 'a', streamId: 1);
      await store.increment(profileId: 'b', streamId: 1);
      expect(store.topEntries('a'), [(streamId: 1, count: 2)]);
      expect(store.topEntries('b'), [(streamId: 1, count: 1)]);
    });

    test('clearCount removes the entry', () async {
      await store.increment(profileId: profileId, streamId: 99);
      expect(store.getCount(profileId: profileId, streamId: 99), 1);
      await store.clearCount(profileId: profileId, streamId: 99);
      expect(store.getCount(profileId: profileId, streamId: 99), 0);
      expect(store.topEntries(profileId), isEmpty);
    });
  });

  group('mostWatchedProvider', () {
    Future<ProviderContainer> makeContainer({
      required List<XtreamStream> liveStreams,
      String? activeConnectionName,
      Map<int, int> playCounts = const {},
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Pre-seed play counts.
      final playStore = PlayCountStore(prefs);
      for (final entry in playCounts.entries) {
        if (activeConnectionName == null) continue;
        for (var i = 0; i < entry.value; i++) {
          await playStore.increment(
            profileId: activeConnectionName, streamId: entry.key,
          );
        }
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

    test('returns empty list when no play counts are recorded', () async {
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'Channel A', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedProvider.future);
      expect(result, isEmpty);
    });

    test('returns empty list when there is no active connection', () async {
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'Channel A', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: null,
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedProvider.future);
      expect(result, isEmpty);
    });

    test('returns empty list when live streams are not yet loaded', () async {
      final container = await makeContainer(
        liveStreams: const [],
        activeConnectionName: 'conn',
        playCounts: {1: 3},
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedProvider.future);
      expect(result, isEmpty);
    });

    test('joins play counts with live stream metadata, sorted by count desc',
        () async {
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 10, name: 'Channel A', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 20, name: 'Channel B', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 30, name: 'Channel C', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn',
        playCounts: {10: 1, 20: 5, 30: 3},
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedProvider.future);
      expect(result.length, 3);
      expect(result[0].stream.streamId, 20);
      expect(result[0].count, 5);
      expect(result[1].stream.streamId, 30);
      expect(result[1].count, 3);
      expect(result[2].stream.streamId, 10);
      expect(result[2].count, 1);
    });

    test('drops stream IDs that no longer exist in the live list', () async {
      // Play count recorded for stream 999, but the loaded list has no
      // such stream — that entry should be silently dropped.
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'Channel A', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn',
        playCounts: {1: 3, 999: 10},
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedProvider.future);
      expect(result, hasLength(1));
      expect(result.single.stream.streamId, 1);
      expect(result.single.count, 3);
    });

    test('isolates rankings by active connection name', () async {
      // First connection has a hot stream; second has nothing.
      final container = await makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'Channel A', categoryId: 1, streamType: 'live'),
        ],
        activeConnectionName: 'conn-A',
        playCounts: {1: 5},
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedProvider.future);
      expect(result, hasLength(1));

      // Switch connection: counts are isolated by name, so this should
      // return empty even though "conn-A" has counts.
      final store = container.read(playCountStoreProvider);
      expect(store.getCount(profileId: 'conn-B', streamId: 1), 0);
    });
  });
}
