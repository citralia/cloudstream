import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/play_count_store.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/core/storage/watch_progress_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

/// In-memory [CredentialsStore] fake. Mirrors the V22/V25 fakes in
/// `v22_most_watched_dedupe_test.dart` / `v25_continue_watching_recency_dedupe_test.dart`
/// — kept local so this test file is self-contained.
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
  group('V26: mostWatchedVodProvider', () {
    Future<ProviderContainer> makeContainer({
      required List<XtreamStream> vodStreams,
      String? activeConnectionName,
      Map<int, int> playCounts = const {},
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
          vodStreamsProvider.overrideWith((ref) async => vodStreams),
        ],
      );
    }

    test('no active connection → empty', () async {
      final container = await makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 1, name: 'Movie A', categoryId: 1, streamType: 'movie'),
        ],
        activeConnectionName: null,
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedVodProvider.future);
      expect(result, isEmpty);
    });

    test('no play counts → empty', () async {
      final container = await makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 1, name: 'Movie A', categoryId: 1, streamType: 'movie'),
        ],
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedVodProvider.future);
      expect(result, isEmpty);
    });

    test('no VOD catalogue → empty', () async {
      final container = await makeContainer(
        vodStreams: const [],
        activeConnectionName: 'conn',
        playCounts: {1: 3},
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedVodProvider.future);
      expect(result, isEmpty);
    });

    test('joins counts with VOD metadata, sorted by count desc', () async {
      final container = await makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 10, name: 'Movie A', categoryId: 1, streamType: 'movie'),
          XtreamStream(streamId: 20, name: 'Movie B', categoryId: 1, streamType: 'movie'),
          XtreamStream(streamId: 30, name: 'Movie C', categoryId: 1, streamType: 'movie'),
        ],
        activeConnectionName: 'conn',
        playCounts: {10: 1, 20: 5, 30: 3},
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedVodProvider.future);
      expect(result.length, 3);
      expect(result[0].stream.streamId, 20);
      expect(result[0].count, 5);
      expect(result[1].stream.streamId, 30);
      expect(result[1].count, 3);
      expect(result[2].stream.streamId, 10);
      expect(result[2].count, 1);
    });

    test('drops stream IDs not in the VOD catalogue (live-channel play counts do NOT leak)', () async {
      // Stream 999 has 10 plays, but the VOD catalogue has no such
      // stream — most likely the count is for a live channel.
      // V26 must silently drop it (the VOD card and the live card
      // are visually + functionally different, so there's no value
      // in surfacing it here).
      final container = await makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 1, name: 'Movie A', categoryId: 1, streamType: 'movie'),
        ],
        activeConnectionName: 'conn',
        playCounts: {1: 3, 999: 10},
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedVodProvider.future);
      expect(result, hasLength(1));
      expect(result.single.stream.streamId, 1);
      expect(result.single.count, 3);
    });

    test('caps at kPersonalisationRowCap entries', () async {
      final vod = <XtreamStream>[
        for (var i = 1; i <= 12; i++)
          XtreamStream(
            streamId: i, name: 'Movie $i', categoryId: 1, streamType: 'movie',
          ),
      ];
      final playCounts = <int, int>{
        for (var i = 1; i <= 12; i++) i: i, // ascending count = descending position
      };
      final container = await makeContainer(
        vodStreams: vod,
        activeConnectionName: 'conn',
        playCounts: playCounts,
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedVodProvider.future);
      expect(result.length, kPersonalisationRowCap);
      expect(result.first.stream.streamId, 12);
      expect(result.last.stream.streamId, 5);
    });

    test('isolates rankings by active connection name', () async {
      // Counts keyed under 'conn-A' must not surface for 'conn-B'.
      final container = await makeContainer(
        vodStreams: const [
          XtreamStream(streamId: 1, name: 'Movie A', categoryId: 1, streamType: 'movie'),
        ],
        activeConnectionName: 'conn-A',
        playCounts: {1: 5},
      );
      addTearDown(container.dispose);

      final result = await container.read(mostWatchedVodProvider.future);
      expect(result, hasLength(1));

      // Switching connection: counts are isolated by name. The store
      // holds the count, but the provider keys on creds.name, so a
      // different active name yields empty.
      final store = container.read(playCountStoreProvider);
      expect(store.getCount(profileId: 'conn-B', streamId: 1), 0);
    });
  });

  group('V26: mostWatchedSeriesProvider', () {
    Future<ProviderContainer> makeContainer({
      required List<XtreamStream> seriesStreams,
      String? activeConnectionName,
      Map<int, int> playCounts = const {},
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
          seriesStreamsProvider.overrideWith((ref) async => seriesStreams),
        ],
      );
    }

    test('no active connection → empty', () async {
      final container = await makeContainer(
        seriesStreams: const [
          XtreamStream(streamId: 1, name: 'Series A', categoryId: 1, streamType: 'series'),
        ],
        activeConnectionName: null,
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedSeriesProvider.future);
      expect(result, isEmpty);
    });

    test('no play counts → empty', () async {
      final container = await makeContainer(
        seriesStreams: const [
          XtreamStream(streamId: 1, name: 'Series A', categoryId: 1, streamType: 'series'),
        ],
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedSeriesProvider.future);
      expect(result, isEmpty);
    });

    test('no series catalogue → empty', () async {
      final container = await makeContainer(
        seriesStreams: const [],
        activeConnectionName: 'conn',
        playCounts: {1: 3},
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedSeriesProvider.future);
      expect(result, isEmpty);
    });

    test('joins counts with series metadata, sorted by count desc', () async {
      final container = await makeContainer(
        seriesStreams: const [
          XtreamStream(streamId: 10, name: 'Series A', categoryId: 1, streamType: 'series'),
          XtreamStream(streamId: 20, name: 'Series B', categoryId: 1, streamType: 'series'),
          XtreamStream(streamId: 30, name: 'Series C', categoryId: 1, streamType: 'series'),
        ],
        activeConnectionName: 'conn',
        playCounts: {10: 1, 20: 5, 30: 3},
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedSeriesProvider.future);
      expect(result.length, 3);
      expect(result[0].stream.streamId, 20);
      expect(result[0].count, 5);
      expect(result[1].stream.streamId, 30);
      expect(result[1].count, 3);
      expect(result[2].stream.streamId, 10);
      expect(result[2].count, 1);
    });

    test('drops stream IDs not in the series catalogue (live+VOD play counts do NOT leak)', () async {
      // Stream 999 has 10 plays but is a live channel — must be dropped.
      // Stream 100 has 5 plays but is a VOD movie — must be dropped.
      // Only stream 1 (a series) should surface.
      final container = await makeContainer(
        seriesStreams: const [
          XtreamStream(streamId: 1, name: 'Series A', categoryId: 1, streamType: 'series'),
        ],
        activeConnectionName: 'conn',
        playCounts: {1: 3, 999: 10, 100: 5},
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedSeriesProvider.future);
      expect(result, hasLength(1));
      expect(result.single.stream.streamId, 1);
      expect(result.single.count, 3);
    });

    test('caps at kPersonalisationRowCap entries', () async {
      final series = <XtreamStream>[
        for (var i = 1; i <= 12; i++)
          XtreamStream(
            streamId: i, name: 'Series $i', categoryId: 1, streamType: 'series',
          ),
      ];
      final playCounts = <int, int>{
        for (var i = 1; i <= 12; i++) i: i,
      };
      final container = await makeContainer(
        seriesStreams: series,
        activeConnectionName: 'conn',
        playCounts: playCounts,
      );
      addTearDown(container.dispose);
      final result = await container.read(mostWatchedSeriesProvider.future);
      expect(result.length, kPersonalisationRowCap);
      expect(result.first.stream.streamId, 12);
      expect(result.last.stream.streamId, 5);
    });

    test('isolates rankings by active connection name', () async {
      final container = await makeContainer(
        seriesStreams: const [
          XtreamStream(streamId: 1, name: 'Series A', categoryId: 1, streamType: 'series'),
        ],
        activeConnectionName: 'conn-A',
        playCounts: {1: 5},
      );
      addTearDown(container.dispose);

      final result = await container.read(mostWatchedSeriesProvider.future);
      expect(result, hasLength(1));

      final store = container.read(playCountStoreProvider);
      expect(store.getCount(profileId: 'conn-B', streamId: 1), 0);
    });
  });
}
