import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/watch_progress_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

/// In-memory [CredentialsStore] fake that bypasses [FlutterSecureStorage].
/// Mirror of the one in continue_watching_test.dart, duplicated here
/// because Dart test files are isolated library scopes — we can't
/// `import 'continue_watching_test.dart'` without exporting its fakes
/// as `part of` or moving them to a shared helper.
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
/// for VOD/series and a fixed series-info map for `getSeriesInfo`.
class _FakeXtreamClient extends XtreamApiClient {
  _FakeXtreamClient({
    required this.vodStreams,
    required this.seriesStreams,
    required this.seriesInfoById,
    this.failOn = const {},
  });

  final List<XtreamStream> vodStreams;
  final List<XtreamStream> seriesStreams;
  final Map<int, XtreamSeriesInfo> seriesInfoById;
  final Set<int> failOn;

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
    if (failOn.contains(seriesId)) {
      throw Exception('simulated network error');
    }
    final info = seriesInfoById[seriesId];
    if (info == null) {
      throw Exception('unknown series $seriesId');
    }
    return info;
  }
}

XtreamSeriesInfo _seriesInfoWith({
  required int id,
  required List<List<Map<String, dynamic>>> seasonsJson, // each row is episode list
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

void main() {
  group('SeriesInfoCache', () {
    test('caches getSeriesInfo results', () async {
      final client = _FakeXtreamClient(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: {
          10: _seriesInfoWith(id: 10, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Pilot', 'stream_id': 1001},
            ],
          ]),
        },
      );
      final cache = SeriesInfoCache(client);
      final a = await cache.get(10);
      final b = await cache.get(10);
      // Same instance — proves the second call did not refetch.
      expect(identical(a, b), isTrue);
    });

    test('findEpisodeByStreamId locates the right series + season + episode', () async {
      final cache = SeriesInfoCache(_FakeXtreamClient(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: {
          10: _seriesInfoWith(id: 10, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Pilot', 'stream_id': 1001},
              {'episode_num': 2, 'title': 'Day 2', 'stream_id': 1002},
            ],
            [
              {'episode_num': 1, 'title': 'S2E1', 'stream_id': 2001},
            ],
          ]),
        },
      ));
      await cache.get(10);
      final hit = cache.findEpisodeByStreamId(2001);
      expect(hit, isNotNull);
      expect(hit!.seriesId, 10);
      expect(hit.seasonNumber, 2);
      expect(hit.episode.streamId, 2001);
      expect(hit.episode.title, 'S2E1');
    });

    test('findEpisodeByStreamId returns null for unknown ids', () async {
      final cache = SeriesInfoCache(_FakeXtreamClient(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: {
          10: _seriesInfoWith(id: 10, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Pilot', 'stream_id': 1001},
            ],
          ]),
        },
      ));
      await cache.get(10);
      expect(cache.findEpisodeByStreamId(99999), isNull);
    });

    test('loadAll ignores individual failures and continues', () async {
      final client = _FakeXtreamClient(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: {
          10: _seriesInfoWith(id: 10, seasonsJson: [
            [{'episode_num': 1, 'title': 'Pilot', 'stream_id': 1001}],
          ]),
        },
        // 20 will throw, 10 should still load.
        failOn: {20},
      );
      final cache = SeriesInfoCache(client);
      await cache.loadAll([20, 10]);
      // 10 should be in the cache; 20 should not.
      expect(cache.findEpisodeByStreamId(1001), isNotNull);
    });
  });

  group('continueWatchingProvider (series episodes)', () {
    Future<ProviderContainer> makeContainer({
      required List<XtreamStream> vodStreams,
      required List<XtreamStream> seriesStreams,
      required Map<int, XtreamSeriesInfo> seriesInfoById,
      Set<int> failOn = const {},
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
              failOn: failOn,
            ),
          ),
        ],
      );
    }

    test('resolves a saved episode id back to its parent series + episode', () async {
      const seriesId = 10;
      const episodeStreamId = 1002;
      final seriesInfo = _seriesInfoWith(id: seriesId, seasonsJson: [
        [
          {'episode_num': 1, 'title': 'Pilot', 'stream_id': 1001},
          {'episode_num': 2, 'title': 'Day 2', 'stream_id': episodeStreamId},
        ],
      ]);
      final container = await makeContainer(
        vodStreams: const [],
        seriesStreams: const [
          XtreamStream(
            streamId: seriesId,
            name: 'The Series',
            categoryId: 0,
            streamType: 'series',
          ),
        ],
        seriesInfoById: {seriesId: seriesInfo},
        activeConnectionName: 'conn',
        progressByStreamId: {episodeStreamId: 60000},
      );
      addTearDown(container.dispose);
      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(1));
      final entry = result.single;
      expect(entry.kind, ContinueWatchingKind.seriesEpisode);
      expect(entry.stream.streamId, seriesId);
      expect(entry.parentSeries, isNotNull);
      expect(entry.episode, isNotNull);
      expect(entry.episode!.streamId, episodeStreamId);
      expect(entry.episode!.title, 'Day 2');
      expect(entry.parentSeason!.seasonNumber, 1);
    });

    test('mixes VOD entries and series-episode entries in one result', () async {
      const seriesId = 10;
      const episodeStreamId = 1001;
      const vodStreamId = 555;
      final container = await makeContainer(
        vodStreams: const [
          XtreamStream(
            streamId: vodStreamId,
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
          seriesId: _seriesInfoWith(id: seriesId, seasonsJson: [
            [
              {'episode_num': 1, 'title': 'Pilot', 'stream_id': episodeStreamId},
            ],
          ]),
        },
        activeConnectionName: 'conn',
        progressByStreamId: {
          vodStreamId: 30000,
          episodeStreamId: 60000,
        },
      );
      addTearDown(container.dispose);
      final result = await container.read(continueWatchingProvider.future);
      expect(result, hasLength(2));
      final byKind = {for (final e in result) e.kind: e};
      expect(byKind[ContinueWatchingKind.vod], isNotNull);
      expect(byKind[ContinueWatchingKind.seriesEpisode], isNotNull);
      expect(byKind[ContinueWatchingKind.vod]!.stream.streamId, vodStreamId);
      expect(
        byKind[ContinueWatchingKind.seriesEpisode]!.episode!.streamId,
        episodeStreamId,
      );
    });

    test('drops episode ids whose parent series failed to load', () async {
      const seriesId = 10;
      const episodeStreamId = 1001;
      final container = await makeContainer(
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
          // Empty map — the fake client will throw on lookup.
          // Equivalent to "we have no series info".
        },
        activeConnectionName: 'conn',
        progressByStreamId: {episodeStreamId: 60000},
      );
      addTearDown(container.dispose);
      final result = await container.read(continueWatchingProvider.future);
      // No usable series info → episode is dropped silently.
      expect(result, isEmpty);
    });

    test('drops orphan episode ids when series catalogue is empty', () async {
      const episodeStreamId = 1001;
      final container = await makeContainer(
        vodStreams: const [],
        seriesStreams: const [],
        seriesInfoById: const {},
        activeConnectionName: 'conn',
        progressByStreamId: {episodeStreamId: 60000},
      );
      addTearDown(container.dispose);
      final result = await container.read(continueWatchingProvider.future);
      expect(result, isEmpty);
    });

    test('continues to surface VOD entries even if some series fail to load', () async {
      const seriesId = 10;
      const episodeStreamId = 1001;
      const vodStreamId = 555;
      final container = await makeContainer(
        vodStreams: const [
          XtreamStream(
            streamId: vodStreamId,
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
        seriesInfoById: const {},
        // Mark the series as failing to load. Episode should be dropped.
        failOn: {seriesId},
        activeConnectionName: 'conn',
        progressByStreamId: {
          vodStreamId: 30000,
          episodeStreamId: 60000,
        },
      );
      addTearDown(container.dispose);
      final result = await container.read(continueWatchingProvider.future);
      // Only the VOD entry survives.
      expect(result, hasLength(1));
      expect(result.single.kind, ContinueWatchingKind.vod);
      expect(result.single.stream.streamId, vodStreamId);
    });
  });
}
