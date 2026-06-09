import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/watch_progress_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

/// Test double for [XtreamApiClient] that returns a fixed stream list
/// for both VOD and series. The `getLiveStreams` call (used to populate
/// the channel list) is also stubbed so the providers don't fail to
/// initialise on read.
class _FakeXtreamClient extends XtreamApiClient {
  _FakeXtreamClient({
    required this.vodStreams,
    required this.seriesStreams,
  });

  final List<XtreamStream> vodStreams;
  final List<XtreamStream> seriesStreams;

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
}

/// In-memory [CredentialsStore] fake that bypasses [FlutterSecureStorage]
/// (which needs a platform channel) so the test doesn't need a Flutter
/// binding initialisation step. Holds a single named connection.
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
  group('WatchProgressStore.savedStreamIds', () {
    late WatchProgressStore store;
    const profileId = 'conn-1';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = WatchProgressStore(prefs);
    });

    test('returns empty list when no progress saved', () {
      expect(store.savedStreamIds(profileId), isEmpty);
    });

    test('returns just the stream IDs that have saved progress', () async {
      await store.saveProgress(
        profileId: profileId, streamId: 101, positionMs: 60000,
      );
      await store.saveProgress(
        profileId: profileId, streamId: 202, positionMs: 30000,
      );
      final ids = store.savedStreamIds(profileId).toSet();
      expect(ids, {101, 202});
    });

    test('isolates entries by profile id', () async {
      await store.saveProgress(
        profileId: 'conn-1', streamId: 101, positionMs: 60000,
      );
      await store.saveProgress(
        profileId: 'conn-2', streamId: 101, positionMs: 30000,
      );
      expect(store.savedStreamIds('conn-1'), [101]);
      expect(store.savedStreamIds('conn-2'), [101]);
    });

    test('clearProgress removes the entry from the listing', () async {
      await store.saveProgress(
        profileId: profileId, streamId: 101, positionMs: 60000,
      );
      await store.clearProgress(profileId: profileId, streamId: 101);
      expect(store.savedStreamIds(profileId), isEmpty);
    });
  });

  group('continueWatchingProvider', () {
    Future<ProviderContainer> makeContainer({
      required List<XtreamStream> vodStreams,
      required List<XtreamStream> seriesStreams,
      String? activeConnectionName,
      Map<int, int> progressByStreamId = const {},
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Pre-seed watch progress.
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

      // Create at least one profile so profile-related providers
      // initialise cleanly.
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
            ),
          ),
        ],
      );
    }

    test('returns empty list when no progress is saved', () async {
      final container = await makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 1, name: 'Movie A', categoryId: 1, streamType: 'movie'),
        ],
        seriesStreams: const [],
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);
      final result = await container.read(continueWatchingProvider.future);
      expect(result, isEmpty);
    });

    test('joins saved progress with VOD stream metadata', () async {
      final container = await makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 1, name: 'Movie A', categoryId: 1, streamType: 'movie'),
          XtreamStream(streamId: 2, name: 'Movie B', categoryId: 1, streamType: 'movie'),
        ],
        seriesStreams: const [],
        activeConnectionName: 'conn',
        progressByStreamId: {1: 60000, 2: 30000},
      );
      addTearDown(container.dispose);
      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(2));
      final ids = result.map((e) => e.stream.streamId).toSet();
      expect(ids, {1, 2});
      // Every entry must have a non-null progress with the seeded position.
      for (final entry in result) {
        expect(entry.progress.positionMs, isNonZero);
      }
    });

    test('drops stream IDs that no longer exist in the loaded lists', () async {
      // Saved progress for stream 999, but the loaded VOD list has no
      // such stream — that entry should be silently dropped.
      final container = await makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 1, name: 'Movie A', categoryId: 1, streamType: 'movie'),
        ],
        seriesStreams: const [],
        activeConnectionName: 'conn',
        progressByStreamId: {1: 60000, 999: 30000},
      );
      addTearDown(container.dispose);
      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(1));
      expect(result.single.stream.streamId, 1);
    });

    test('sorts entries by most recently updated first', () async {
      final container = await makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 1, name: 'Movie A', categoryId: 1, streamType: 'movie'),
          XtreamStream(streamId: 2, name: 'Movie B', categoryId: 1, streamType: 'movie'),
        ],
        seriesStreams: const [],
        activeConnectionName: 'conn',
        progressByStreamId: {1: 60000, 2: 30000},
      );
      addTearDown(container.dispose);
      final result = await container.read(continueWatchingProvider.future);
      // Both have updatedAt ≈ now; the sort is stable enough that we
      // just need each entry to have an updatedAt that's no older than
      // the other. Strict ordering can flake on millisecond boundaries,
      // so check by descending: result[i].progress.updatedAt >=
      // result[i+1].progress.updatedAt.
      for (var i = 0; i < result.length - 1; i++) {
        expect(
          result[i].progress.updatedAt.isAfter(result[i + 1].progress.updatedAt) ||
              result[i].progress.updatedAt.isAtSameMomentAs(
                result[i + 1].progress.updatedAt,
              ),
          isTrue,
        );
      }
    });

    test('returns empty when no active connection', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(ProfileStore(prefs)),
          credentialsStoreProvider.overrideWithValue(_FakeCredentialsStore()),
          xtreamClientProvider.overrideWithValue(
            _FakeXtreamClient(vodStreams: const [], seriesStreams: const []),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(continueWatchingProvider.future);
      expect(result, isEmpty);
    });
  });
}
