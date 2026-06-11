// V27 — EPG programme-title search.
//
// Closes the V04 search surface gap: the search screen indexed live
// channels + VOD + series by name, but a user looking for "find me
// when Match of the Day is on any channel" had no way to search by
// *programme title*. The Xtream API exposes EPG listings (already
// fetched by the EPG guide screen on demand), so a new
// `programmeTitleSearchProvider` joins the EPG entries across the
// loaded live channels and surfaces a new 'epg' result type.
//
// V27 adds:
//   - `programmeTitleSearchProvider` (FutureProvider.family) —
//     case-insensitive title + description match across the active
//     connection's loaded live channels' EPG, sorted by programme
//     start-time asc, capped at `kEpgProgrammeSearchCap` (20).
//   - `debouncedEpgQueryProvider` (StateProvider<String>) — the
//     SearchScreen writes to this 350ms after the user stops typing
//     so we don't fire N EPG network round-trips per keystroke.
//   - `EpgProgrammeHit` (channel + programme pair) and
//     `kEpgProgrammeSearchCap` (const int) in app_providers.dart.
//   - `EpgGuideScreen(initialProgrammeStartMs:)` — opens the guide
//     centred on the matched programme's start time. Defaults to
//     null (now-centred) so the bottom-nav entry point is unchanged.
//   - SearchScreen renders EPG results as a new `_EpgResultTile`
//     below the existing in-memory section, with a section header.
//     Tap → EpgGuideScreen at the right time.
//
// Test scope follows the V22 / V23 / V24 / V26 pattern: pure
// data-layer / Riverpod injection tests for the new provider. The
// widget changes (search screen + EPG guide init) are thin and
// covered by source migration + analyze (same trade-off V14 chunk
// 2 + V15 made for player surfaces that don't pump cleanly in unit
// tests).
//
// Fixture pattern follows v24_live_continue_watching_test.dart:
// _FakeCredentialsStore + `_FakeXtreamClient` (with liveStreams +
// per-stream EPG via getEpg) + `makeContainer` helper that overrides
// the storage + client + live + epg providers. Per-channel EPG
// seed lets us construct deterministic multi-channel scenarios
// (match on one channel's title, miss on another's, etc.).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

// ─── Test doubles ────────────────────────────────────────────────────────

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

class _FakeXtreamClient extends XtreamApiClient {
  _FakeXtreamClient({
    required this.liveStreams,
    required this.epgByStreamId,
  });

  final List<XtreamStream> liveStreams;

  /// Per-streamId EPG list. A missing key (or `epgProvider` overridden
  /// to throw) simulates a flaky channel.
  final Map<int, List<XtreamEpgEntry>> epgByStreamId;

  @override
  Future<List<XtreamStream>> getLiveStreams({int? categoryId}) async {
    if (categoryId == null) return liveStreams;
    return liveStreams.where((s) => s.categoryId == categoryId).toList();
  }

  @override
  Future<List<XtreamEpgEntry>> getEpg(int streamId) async {
    final entries = epgByStreamId[streamId];
    if (entries == null) {
      throw Exception('epg unavailable for stream $streamId');
    }
    return entries;
  }
}

// ─── Fixture helpers ─────────────────────────────────────────────────────

XtreamEpgEntry _epg({
  required int start,
  required int end,
  required String title,
  String? description,
  String channelId = 'c',
}) {
  return XtreamEpgEntry(
    channelId: channelId,
    start: start,
    end: end,
    title: title,
    description: description,
  );
}

Future<ProviderContainer> _makeContainer({
  required List<XtreamStream> liveStreams,
  required Map<int, List<XtreamEpgEntry>> epgByStreamId,
  String? activeConnectionName,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final profileStore = ProfileStore(prefs);
  if (activeConnectionName != null) {
    await profileStore.addProfile(name: activeConnectionName);
  }
  final credsStore = _FakeCredentialsStore(activeName: activeConnectionName);
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      profileStoreProvider.overrideWithValue(profileStore),
      credentialsStoreProvider.overrideWithValue(credsStore),
      xtreamClientProvider.overrideWith(
        (ref) => _FakeXtreamClient(
          liveStreams: liveStreams,
          epgByStreamId: epgByStreamId,
        ),
      ),
    ],
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────

void main() {
  group('programmeTitleSearchProvider — V27 EPG programme-title search', () {
    test('empty query → empty list (short-circuits without doing work)',
        () async {
      final container = await _makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'BBC One', categoryId: 1, streamType: 'live'),
        ],
        epgByStreamId: {
          1: [
            _epg(
              start: 1717200000,
              end: 1717203600,
              title: 'Match of the Day',
            ),
          ],
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final result = await container.read(
        programmeTitleSearchProvider('').future,
      );
      expect(result, isEmpty);
    });

    test('whitespace-only query → empty list', () async {
      final container = await _makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'BBC One', categoryId: 1, streamType: 'live'),
        ],
        epgByStreamId: {
          1: [
            _epg(
              start: 1717200000,
              end: 1717203600,
              title: 'Match of the Day',
            ),
          ],
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final result = await container.read(
        programmeTitleSearchProvider('   ').future,
      );
      expect(result, isEmpty);
    });

    test('no active connection → empty list', () async {
      final container = await _makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'BBC One', categoryId: 1, streamType: 'live'),
        ],
        epgByStreamId: {
          1: [
            _epg(
              start: 1717200000,
              end: 1717203600,
              title: 'Match of the Day',
            ),
          ],
        },
        activeConnectionName: null,
      );
      addTearDown(container.dispose);

      final result = await container.read(
        programmeTitleSearchProvider('match').future,
      );
      expect(result, isEmpty);
    });

    test('no live streams → empty list (regression guard)', () async {
      final container = await _makeContainer(
        liveStreams: const [],
        epgByStreamId: const {},
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final result = await container.read(
        programmeTitleSearchProvider('match').future,
      );
      expect(result, isEmpty);
    });

    test('case-insensitive title match across all loaded channels',
        () async {
      final container = await _makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'BBC One', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 2, name: 'ITV', categoryId: 1, streamType: 'live'),
        ],
        epgByStreamId: {
          1: [
            _epg(
              start: 1717200000,
              end: 1717203600,
              title: 'Match of the Day',
            ),
          ],
          2: [
            _epg(
              start: 1717200900,
              end: 1717204500,
              title: 'The Chase',
            ),
          ],
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      // Lowercase query, mixed-case title — case-insensitive.
      final result = await container.read(
        programmeTitleSearchProvider('match').future,
      );
      expect(result, hasLength(1));
      expect(result.first.programme.title, 'Match of the Day');
      expect(result.first.channel.streamId, 1);
      expect(result.first.channel.name, 'BBC One');
    });

    test('description match (when title does not match)', () async {
      final container = await _makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'BBC One', categoryId: 1, streamType: 'live'),
        ],
        epgByStreamId: {
          1: [
            _epg(
              start: 1717200000,
              end: 1717203600,
              title: 'Regional News',
              description: 'Football highlights and analysis',
            ),
          ],
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final result = await container.read(
        programmeTitleSearchProvider('football').future,
      );
      expect(result, hasLength(1));
      expect(result.first.programme.title, 'Regional News');
      expect(result.first.programme.description, contains('Football'));
    });

    test('multiple hits sorted by programme start-time asc', () async {
      final container = await _makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'BBC One', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 2, name: 'ITV', categoryId: 1, streamType: 'live'),
        ],
        epgByStreamId: {
          1: [
            _epg(
              start: 1717203600, // later
              end: 1717207200,
              title: 'News at Ten',
            ),
          ],
          2: [
            _epg(
              start: 1717200000, // earlier
              end: 1717203600,
              title: 'News at Six',
            ),
          ],
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final result = await container.read(
        programmeTitleSearchProvider('news').future,
      );
      expect(result, hasLength(2));
      // Earliest first.
      expect(result.first.programme.title, 'News at Six');
      expect(result.last.programme.title, 'News at Ten');
    });

    test('results capped at kEpgProgrammeSearchCap (20)', () async {
      // 25 programmes across 5 channels, all matching "show".
      final epgByStreamId = <int, List<XtreamEpgEntry>>{};
      final liveStreams = <XtreamStream>[];
      for (var c = 1; c <= 5; c++) {
        liveStreams.add(
          XtreamStream(streamId: c, name: 'Channel $c', categoryId: 1, streamType: 'live'),
        );
        final entries = <XtreamEpgEntry>[];
        for (var i = 0; i < 5; i++) {
          entries.add(
            _epg(
              start: 1717200000 + (c * 1000) + (i * 100),
              end: 1717200000 + (c * 1000) + (i * 100) + 600,
              title: 'Show $c.$i',
            ),
          );
        }
        epgByStreamId[c] = entries;
      }

      final container = await _makeContainer(
        liveStreams: liveStreams,
        epgByStreamId: epgByStreamId,
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final result = await container.read(
        programmeTitleSearchProvider('show').future,
      );
      expect(result, hasLength(kEpgProgrammeSearchCap));
      expect(kEpgProgrammeSearchCap, 20); // pin the cap
    });

    test('a flaky channel (epgProvider throws) does not poison the result',
        () async {
      // Channel 1 returns 2 matches; channel 2's EPG fetch throws (a
      // network blip); the search must surface channel 1's hits.
      final container = await _makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'BBC One', categoryId: 1, streamType: 'live'),
          XtreamStream(streamId: 2, name: 'ITV', categoryId: 1, streamType: 'live'),
        ],
        epgByStreamId: {
          1: [
            _epg(
              start: 1717200000,
              end: 1717203600,
              title: 'Match of the Day',
            ),
            _epg(
              start: 1717203600,
              end: 1717207200,
              title: 'Match of the Day 2',
            ),
          ],
          // 2 → no entry → fake's getEpg throws.
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final result = await container.read(
        programmeTitleSearchProvider('match').future,
      );
      expect(result, hasLength(2));
      // Both hits are from channel 1 (the working channel).
      expect(result.every((h) => h.channel.streamId == 1), isTrue);
    });

    test('no matches across all channels → empty list', () async {
      final container = await _makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 1, name: 'BBC One', categoryId: 1, streamType: 'live'),
        ],
        epgByStreamId: {
          1: [
            _epg(
              start: 1717200000,
              end: 1717203600,
              title: 'News at Ten',
            ),
          ],
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final result = await container.read(
        programmeTitleSearchProvider('football').future,
      );
      expect(result, isEmpty);
    });

    test('hit carries both the matched programme and its parent channel',
        () async {
      final container = await _makeContainer(
        liveStreams: const [
          XtreamStream(streamId: 42, name: 'Sky Sports', categoryId: 7, streamType: 'live'),
        ],
        epgByStreamId: {
          42: [
            _epg(
              start: 1717200000,
              end: 1717254000, // 3-hour programme
              title: 'Premier League Live',
              description: 'Live coverage',
            ),
          ],
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final result = await container.read(
        programmeTitleSearchProvider('premier').future,
      );
      expect(result, hasLength(1));
      final hit = result.first;
      // Programme fields round-trip.
      expect(hit.programme.title, 'Premier League Live');
      expect(hit.programme.start, 1717200000);
      expect(hit.programme.end, 1717254000);
      expect(hit.programme.description, 'Live coverage');
      // Channel fields round-trip (used to render logo + name in the
      // _EpgResultTile and to navigate to the EPG guide on tap).
      expect(hit.channel.streamId, 42);
      expect(hit.channel.name, 'Sky Sports');
      expect(hit.channel.categoryId, 7);
    });
  });

  group('debouncedEpgQueryProvider — V27 keystroke debounce', () {
    test('defaults to empty string', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(debouncedEpgQueryProvider), '');
    });

    test('writes propagate to the StateProvider', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      container.read(debouncedEpgQueryProvider.notifier).state = 'match';
      expect(container.read(debouncedEpgQueryProvider), 'match');

      container.read(debouncedEpgQueryProvider.notifier).state = '';
      expect(container.read(debouncedEpgQueryProvider), '');
    });
  });
}
