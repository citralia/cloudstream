import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

/// Test double for [XtreamApiClient] that returns a fixed [XtreamVodInfo].
class _FakeXtreamClient extends XtreamApiClient {
  _FakeXtreamClient(this._info);

  final XtreamVodInfo _info;

  @override
  Future<XtreamVodInfo> getVodInfo(int vodId) async => _info;
}

void main() {
  group('XtreamVodInfo.fromJson', () {
    test('parses full info block', () {
      final json = {
        'info': {
          'name': 'Inception',
          'plot': 'A thief who steals corporate secrets through dream-sharing.',
          'cover': 'https://example.com/inception.jpg',
          'cast': 'Leonardo DiCaprio, Joseph Gordon-Levitt, Ellen Page',
          'director': 'Christopher Nolan',
          'releaseDate': '2010-07-16',
          'rating': '8.8',
          'duration': '148 min',
          'seasons': <dynamic>[],
        },
      };
      final info = XtreamVodInfo.fromJson(json);
      expect(info.name, 'Inception');
      expect(info.plot, contains('dream-sharing'));
      expect(info.cover, 'https://example.com/inception.jpg');
      expect(info.cast, contains('DiCaprio'));
      expect(info.director, 'Christopher Nolan');
      expect(info.releaseDate, '2010-07-16');
      expect(info.rating, '8.8');
      expect(info.duration, '148 min');
      expect(info.seasons, isEmpty);
    });

    test('falls back to top-level name when info.name is missing', () {
      final json = {
        'name': 'Top Level Title',
        'info': <String, dynamic>{},
      };
      final info = XtreamVodInfo.fromJson(json);
      expect(info.name, 'Top Level Title');
      expect(info.plot, isNull);
      expect(info.cover, isNull);
    });

    test('handles missing info block entirely', () {
      final info = XtreamVodInfo.fromJson(<String, dynamic>{});
      expect(info.name, '');
      expect(info.plot, isNull);
      expect(info.seasons, isEmpty);
    });

    test('parses seasons and episodes', () {
      final json = {
        'info': {
          'name': 'Show',
          'seasons': [
            {
              'season_number': 1,
              'episodes': [
                {
                  'episode_num': 1,
                  'title': 'Pilot',
                  'description': 'First ep',
                  'stream_id': 100,
                },
                {
                  'episode_num': 2,
                  'title': 'Second',
                  'stream_id': 101,
                },
              ],
            },
          ],
        },
      };
      final info = XtreamVodInfo.fromJson(json);
      expect(info.seasons.length, 1);
      expect(info.seasons.first.seasonNumber, 1);
      expect(info.seasons.first.episodes.length, 2);
      expect(info.seasons.first.episodes[0].title, 'Pilot');
      expect(info.seasons.first.episodes[1].streamId, 101);
    });
  });

  group('vodInfoProvider', () {
    test('returns XtreamVodInfo from the injected XtreamApiClient', () async {
      final info = XtreamVodInfo(
        name: 'Test Movie',
        plot: 'A test plot',
        rating: '7.5',
        duration: '90 min',
        releaseDate: '2024-01-15',
        director: 'Test Director',
        cast: 'Actor A, Actor B',
      );
      final container = ProviderContainer(
        overrides: [
          xtreamClientProvider.overrideWithValue(_FakeXtreamClient(info)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(vodInfoProvider(42).future);
      expect(result.name, 'Test Movie');
      expect(result.plot, 'A test plot');
      expect(result.rating, '7.5');
      expect(result.director, 'Test Director');
    });
  });
}
