import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

/// Test double for [XtreamApiClient] that returns a fixed [XtreamSeriesInfo].
class _FakeXtreamClient extends XtreamApiClient {
  _FakeXtreamClient(this._info);

  final XtreamSeriesInfo _info;

  @override
  Future<XtreamSeriesInfo> getSeriesInfo(int seriesId) async => _info;
}

void main() {
  group('XtreamSeriesInfo.fromJson', () {
    test('parses full info block with metadata', () {
      final json = {
        'info': {
          'name': 'Breaking Bad',
          'plot': 'A high school chemistry teacher turned meth maker.',
          'cover': 'https://example.com/bb.jpg',
          'cast': 'Bryan Cranston, Aaron Paul',
          'director': 'Vince Gilligan',
          'releaseDate': '2008-01-20',
          'rating': '9.5',
          'seasons': [
            {
              'season_number': 1,
              'episodes': [
                {
                  'episode_num': 1,
                  'title': 'Pilot',
                  'stream_id': 100,
                  'duration': '2700',
                },
              ],
            },
          ],
        },
      };
      final info = XtreamSeriesInfo.fromJson(json);
      expect(info.name, 'Breaking Bad');
      expect(info.plot, contains('chemistry teacher'));
      expect(info.cover, 'https://example.com/bb.jpg');
      expect(info.cast, contains('Bryan Cranston'));
      expect(info.director, 'Vince Gilligan');
      expect(info.releaseDate, '2008-01-20');
      expect(info.rating, '9.5');
      expect(info.seasons.length, 1);
      expect(info.seasons.first.episodes.length, 1);
      expect(info.seasons.first.episodes.first.streamId, 100);
      expect(info.seasons.first.episodes.first.duration, 2700);
    });

    test('falls back to top-level name when info.name is missing', () {
      final json = {
        'name': 'Top Level Series',
        'info': <String, dynamic>{},
      };
      final info = XtreamSeriesInfo.fromJson(json);
      expect(info.name, 'Top Level Series');
      expect(info.plot, isNull);
      expect(info.cover, isNull);
      expect(info.cast, isNull);
    });

    test('handles missing info block entirely', () {
      final info = XtreamSeriesInfo.fromJson(<String, dynamic>{});
      expect(info.name, '');
      expect(info.plot, isNull);
      expect(info.cover, isNull);
      expect(info.seasons, isEmpty);
    });

    test('parses multiple seasons with empty episodes lists', () {
      final json = {
        'info': {
          'name': 'Multi Season',
          'seasons': [
            {'season_number': 1, 'episodes': []},
            {'season_number': 2, 'episodes': []},
            {'season_number': 3, 'episodes': []},
          ],
        },
      };
      final info = XtreamSeriesInfo.fromJson(json);
      expect(info.seasons.length, 3);
      expect(info.seasons.map((s) => s.seasonNumber), [1, 2, 3]);
      for (final s in info.seasons) {
        expect(s.episodes, isEmpty);
      }
    });

    test('parses season missing episodes field without crashing', () {
      final json = {
        'info': {
          'name': 'Sparse Season',
          'seasons': [
            {'season_number': 1},
          ],
        },
      };
      final info = XtreamSeriesInfo.fromJson(json);
      expect(info.seasons.length, 1);
      expect(info.seasons.first.seasonNumber, 1);
      expect(info.seasons.first.episodes, isEmpty);
    });
  });

  group('XtreamEpisode.fromJson', () {
    test('handles missing duration and description', () {
      final json = {
        'episode_num': 5,
        'title': 'Episode 5',
        'stream_id': 555,
      };
      final episode = XtreamEpisode.fromJson(json);
      expect(episode.episodeNumber, 5);
      expect(episode.title, 'Episode 5');
      expect(episode.streamId, 555);
      expect(episode.description, isNull);
      expect(episode.duration, 0);
    });

    test('parses duration as int string', () {
      final json = {
        'episode_num': 1,
        'title': 'First',
        'stream_id': 10,
        'duration': '1800',
      };
      final episode = XtreamEpisode.fromJson(json);
      expect(episode.duration, 1800);
    });
  });

  group('seriesInfoProvider', () {
    test('returns XtreamSeriesInfo from the injected XtreamApiClient', () async {
      final info = XtreamSeriesInfo(
        name: 'Test Show',
        plot: 'A test plot',
        rating: '8.0',
        releaseDate: '2023-09-01',
        seasons: const [],
      );
      final container = ProviderContainer(
        overrides: [
          xtreamClientProvider.overrideWithValue(_FakeXtreamClient(info)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(seriesInfoProvider(99).future);
      expect(result.name, 'Test Show');
      expect(result.plot, 'A test plot');
      expect(result.rating, '8.0');
      expect(result.releaseDate, '2023-09-01');
      expect(result.seasons, isEmpty);
    });
  });
}
