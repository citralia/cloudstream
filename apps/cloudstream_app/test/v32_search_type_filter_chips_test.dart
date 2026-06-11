// V32 — Search result type filter chips.
//
// Closes a real user-friction gap on the search screen: prior to
// V32, the search screen rendered all in-memory results (live
// channels + VOD + series) and the EPG programme column in a single
// ListView with two section headers. A user searching for an
// uncommon VOD title (e.g. "Interstellar") on a Firestick with a
// 200-channel live catalogue would see "Interstellar" in the
// "Channels and VOD" section but have to scroll past 50 live
// channels ("Inter TV", "International Film Channel", etc.) to find
// the VOD match. V32 adds a horizontal row of filter chips
// (All / Live TV / VOD / Series / EPG) above the results list —
// selecting a chip hides the other sections so the user sees only
// matches of the chosen type.
//
// V32 adds:
//   - `SearchResultTypeFilter` enum (`all` | `live` | `vod` |
//     `series` | `epg`) in `search_screen.dart` — the discriminator
//     for the chip row selection.
//   - `searchTypeFilterProvider` (`StateProvider<SearchResultTypeFilter>`)
//     — module-level so widget tests can override it; defaults to
//     `all` (preserves pre-V32 behaviour on first open).
//   - `filterSearchResults(...)` — a pure function that partitions
//     the in-memory result list and the EPG hits into the pair to
//     render. Module-level so tests can drive it without pumping
//     the search screen widget.
//   - `_SearchTypeChips` + `_SearchTypeChip` widgets in
//     `search_screen.dart` — the chip row UI. Sits between the
//     search bar and the results list. Each chip shows the type's
//     icon + label + count suffix (e.g. "VOD 3"). Hides itself
//     when there are no results at all (the body shows the "No
//     results" empty state in that case).
//   - The search screen's `_buildBody` now applies
//     `filterSearchResults` to the data before rendering. The
//     section header copy adapts to the active filter (e.g. "Live
//     TV" when `live` is selected, "Channels and VOD" when `all`).
//     The duplicate "EPG programmes" header is suppressed when the
//     filter is already `epg`. The footer spinner is shown when
//     EPG is loading even if the in-memory list is empty (the user
//     explicitly selected the EPG filter, so they're waiting for
//     that column).
//
// Test scope follows the V22 / V23 / V24 / V26 / V27 / V30 pattern:
// pure data-layer / Riverpod injection tests for the new provider
// + the pure `filterSearchResults` function. The chip widget
// changes are covered by two testWidgets smoke tests that pump
// the search screen with hand-rolled provider overrides.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/search/search_service.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';
import 'package:cloudstream_app/presentation/screens/search_screen.dart';

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
    required this.vodStreams,
    required this.seriesStreams,
    required this.epgByStreamId,
  });

  final List<XtreamStream> liveStreams;
  final List<XtreamStream> vodStreams;
  final List<XtreamStream> seriesStreams;

  /// Per-streamId EPG list. A missing key (or `epgProvider` overridden
  /// to throw) simulates a flaky channel.
  final Map<int, List<XtreamEpgEntry>> epgByStreamId;

  @override
  Future<List<XtreamStream>> getLiveStreams({int? categoryId}) async {
    if (categoryId == null) return liveStreams;
    return liveStreams.where((s) => s.categoryId == categoryId).toList();
  }

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
  Future<List<XtreamEpgEntry>> getEpg(int streamId) async {
    final entries = epgByStreamId[streamId];
    if (entries == null) {
      throw Exception('epg unavailable for stream $streamId');
    }
    return entries;
  }
}

// ─── Fixture helpers ─────────────────────────────────────────────────────

SearchResult _result(int streamId, String name, String type) {
  return SearchResult(
    stream: XtreamStream(
      streamId: streamId,
      name: name,
      categoryId: 1,
      streamType: type == 'live' ? 'live' : type,
    ),
    type: type,
  );
}

EpgProgrammeHit _hit({
  required int streamId,
  required String channelName,
  required String title,
  int start = 1717200000,
  int end = 1717203600,
}) {
  return EpgProgrammeHit(
    channel: XtreamStream(
      streamId: streamId,
      name: channelName,
      categoryId: 1,
      streamType: 'live',
    ),
    programme: XtreamEpgEntry(
      channelId: 'c$streamId',
      start: start,
      end: end,
      title: title,
    ),
  );
}

Future<ProviderContainer> _makeContainer({
  required List<XtreamStream> liveStreams,
  required List<XtreamStream> vodStreams,
  required List<XtreamStream> seriesStreams,
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
  // Pre-seed the search service index from the fixture. Overriding
  // the leaf `searchServiceProvider` short-circuits the
  // `searchIndexRebuilderProvider` (which would otherwise await
  // the three catalogue `FutureProvider`s — the V32 integration
  // tests don't need the catalogue plumbing, only the index).
  final searchService = SearchService();
  searchService.rebuild(
    live: liveStreams,
    vod: vodStreams,
    series: seriesStreams,
  );
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      profileStoreProvider.overrideWithValue(profileStore),
      credentialsStoreProvider.overrideWithValue(credsStore),
      searchServiceProvider.overrideWithValue(searchService),
      // Override the index rebuilder with a no-op so it resolves
      // immediately and doesn't try to clobber the pre-seeded
      // service with `valueOrNull ?? []` (which is `[]` because
      // the catalogue providers are not overridden here).
      searchIndexRebuilderProvider.overrideWith((ref) async {}),
      // Override the EPG family with a no-op so the search screen
      // doesn't fire N EPG network round-trips per test.
      programmeTitleSearchProvider.overrideWith(
        (ref, query) async => const <EpgProgrammeHit>[],
      ),
      // Override the xtream client so the real one never tries a
      // network call when the catalogue providers fall through.
      xtreamClientProvider.overrideWith(
        (ref) => _FakeXtreamClient(
          liveStreams: liveStreams,
          vodStreams: vodStreams,
          seriesStreams: seriesStreams,
          epgByStreamId: epgByStreamId,
        ),
      ),
    ],
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────

void main() {
  // ── Pure function tests for `filterSearchResults` ──
  //
  // The function is the unit-testable core of V32. Every code path
  // is exercised without pumping any widget — the chip widget
  // delegates the data-partition decision to this function.
  group('filterSearchResults — V32 type-filter partition', () {
    final inMemory = [
      _result(1, 'BBC One', 'live'),
      _result(2, 'CNN', 'live'),
      _result(10, 'Inception', 'vod'),
      _result(11, 'Tenet', 'vod'),
      _result(20, 'Breaking Bad', 'series'),
    ];
    final epg = [
      _hit(streamId: 1, channelName: 'BBC One', title: 'News at Six'),
      _hit(streamId: 2, channelName: 'CNN', title: 'Newsroom'),
    ];

    test('all → identity (returns both lists unchanged)', () {
      final out = filterSearchResults(
        filter: SearchResultTypeFilter.all,
        inMemory: inMemory,
        epg: epg,
      );
      expect(out.inMemory, equals(inMemory));
      expect(out.epg, equals(epg));
    });

    test('live → keeps only live in-memory, drops EPG', () {
      final out = filterSearchResults(
        filter: SearchResultTypeFilter.live,
        inMemory: inMemory,
        epg: epg,
      );
      expect(out.inMemory.map((r) => r.type), everyElement('live'));
      expect(out.inMemory.length, 2);
      expect(out.epg, isEmpty);
    });

    test('vod → keeps only VOD in-memory, drops EPG', () {
      final out = filterSearchResults(
        filter: SearchResultTypeFilter.vod,
        inMemory: inMemory,
        epg: epg,
      );
      expect(out.inMemory.map((r) => r.type), everyElement('vod'));
      expect(out.inMemory.length, 2);
      expect(out.epg, isEmpty);
    });

    test('series → keeps only series in-memory, drops EPG', () {
      final out = filterSearchResults(
        filter: SearchResultTypeFilter.series,
        inMemory: inMemory,
        epg: epg,
      );
      expect(out.inMemory.map((r) => r.type), everyElement('series'));
      expect(out.inMemory.length, 1);
      expect(out.epg, isEmpty);
    });

    test('epg → drops all in-memory, keeps EPG', () {
      final out = filterSearchResults(
        filter: SearchResultTypeFilter.epg,
        inMemory: inMemory,
        epg: epg,
      );
      expect(out.inMemory, isEmpty);
      expect(out.epg, equals(epg));
    });

    test('all with empty inputs → empty pair (the all-empty case)', () {
      final out = filterSearchResults(
        filter: SearchResultTypeFilter.all,
        inMemory: const <SearchResult>[],
        epg: const <EpgProgrammeHit>[],
      );
      expect(out.inMemory, isEmpty);
      expect(out.epg, isEmpty);
    });

    test('live with no live results + non-empty EPG → empty pair', () {
      // Regression guard: a single non-matching filter must not leak
      // the EPG column through. The EPG column is always hidden
      // unless `all` or `epg` is selected.
      final out = filterSearchResults(
        filter: SearchResultTypeFilter.live,
        inMemory: [
          _result(10, 'Inception', 'vod'),
        ],
        epg: epg,
      );
      expect(out.inMemory, isEmpty);
      expect(out.epg, isEmpty);
    });
  });

  // ── State provider tests for `searchTypeFilterProvider` ──
  group('searchTypeFilterProvider — V32 filter state', () {
    test('default is all (preserves pre-V32 behaviour)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final value = container.read(searchTypeFilterProvider);
      expect(value, SearchResultTypeFilter.all);
    });

    test('can be set to each variant (the chip tap path)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      container.read(searchTypeFilterProvider.notifier).state =
          SearchResultTypeFilter.live;
      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.live);

      container.read(searchTypeFilterProvider.notifier).state =
          SearchResultTypeFilter.vod;
      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.vod);

      container.read(searchTypeFilterProvider.notifier).state =
          SearchResultTypeFilter.series;
      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.series);

      container.read(searchTypeFilterProvider.notifier).state =
          SearchResultTypeFilter.epg;
      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.epg);

      // Round-trip back to `all`.
      container.read(searchTypeFilterProvider.notifier).state =
          SearchResultTypeFilter.all;
      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.all);
    });

    test('persists across new containers (V35 — store-backed)', () async {
      // V35 update: V32 originally kept the filter per-session
      // (StateProvider memory only). V35 persists the chip
      // selection via SearchTypeFilterPreferencesStore, mirroring
      // the V08 theme / V10 lead-time pattern. Two consecutive
      // containers with the same backing prefs should now see
      // the most recent tap survive, not reset to `all`.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c1 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      c1.read(searchTypeFilterProvider.notifier).state =
          SearchResultTypeFilter.live;
      await c1.read(searchTypeFilterPreferencesStoreProvider)
          .save(SearchResultTypeFilter.live);
      expect(c1.read(searchTypeFilterProvider), SearchResultTypeFilter.live);
      c1.dispose();

      final c2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(c2.dispose);
      expect(c2.read(searchTypeFilterProvider), SearchResultTypeFilter.live);
    });

    test('falls back to all on fresh install (no stored key)', () async {
      // V35 default-preservation regression guard: a fresh
      // install with no `search_type_filter` key in prefs must
      // still default to `all` (preserves the V32 first-open
      // behaviour).
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(searchTypeFilterProvider), SearchResultTypeFilter.all);
    });
  });

  // ── Integration tests for the chip row wiring ──
  //
  // Drive the search service index end-to-end (live + VOD + series
  // loaded → search runs → results feed both the provider and the
  // chip row counts). Verifies the live data layer plus the
  // pure-function filter compose correctly.
  group('V32 integration — search index + filter', () {
    test('search hits all three in-memory types, filter narrows', () async {
      final container = await _makeContainer(
        liveStreams: [
          XtreamStream(
              streamId: 1,
              name: 'Match TV',
              categoryId: 1,
              streamType: 'live'),
          XtreamStream(
              streamId: 2,
              name: 'Sky News',
              categoryId: 1,
              streamType: 'live'),
        ],
        vodStreams: [
          XtreamStream(
              streamId: 10,
              name: 'Match Point',
              categoryId: 1,
              streamType: 'movie'),
        ],
        seriesStreams: [
          XtreamStream(
              streamId: 20,
              name: 'Match Day',
              categoryId: 1,
              streamType: 'series'),
        ],
        epgByStreamId: const {},
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      // The fixture pre-seeded the search service; no need to await
      // the index rebuilder (and doing so risks the FutureProvider
      // dispose-during-loading gotcha).
      container.read(searchQueryProvider.notifier).state = 'match';
      final all = container.read(searchResultsProvider);
      expect(all.length, 3);
      expect(all.map((r) => r.type).toSet(), {'live', 'vod', 'series'});

      // Filter to live only — should drop the VOD and series match.
      container.read(searchTypeFilterProvider.notifier).state =
          SearchResultTypeFilter.live;
      final liveOnly = filterSearchResults(
        filter: container.read(searchTypeFilterProvider),
        inMemory: container.read(searchResultsProvider),
        epg: const <EpgProgrammeHit>[],
      );
      expect(liveOnly.inMemory.length, 1);
      expect(liveOnly.inMemory.first.type, 'live');
      expect(liveOnly.epg, isEmpty);

      // Filter to series only — should drop the VOD and live match.
      container.read(searchTypeFilterProvider.notifier).state =
          SearchResultTypeFilter.series;
      final seriesOnly = filterSearchResults(
        filter: container.read(searchTypeFilterProvider),
        inMemory: container.read(searchResultsProvider),
        epg: const <EpgProgrammeHit>[],
      );
      expect(seriesOnly.inMemory.length, 1);
      expect(seriesOnly.inMemory.first.type, 'series');
    });

    test('VOD-only filter excludes live and series', () async {
      final container = await _makeContainer(
        liveStreams: [
          XtreamStream(
              streamId: 1,
              name: 'News Channel',
              categoryId: 1,
              streamType: 'live'),
        ],
        vodStreams: [
          XtreamStream(
              streamId: 10,
              name: 'News of the World',
              categoryId: 1,
              streamType: 'movie'),
        ],
        seriesStreams: [
          XtreamStream(
              streamId: 20,
              name: 'Newsroom',
              categoryId: 1,
              streamType: 'series'),
        ],
        epgByStreamId: const {},
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      container.read(searchQueryProvider.notifier).state = 'news';
      expect(container.read(searchResultsProvider).length, 3);

      container.read(searchTypeFilterProvider.notifier).state =
          SearchResultTypeFilter.vod;
      final vodOnly = filterSearchResults(
        filter: container.read(searchTypeFilterProvider),
        inMemory: container.read(searchResultsProvider),
        epg: const <EpgProgrammeHit>[],
      );
      expect(vodOnly.inMemory.length, 1);
      expect(vodOnly.inMemory.first.type, 'vod');
      expect(vodOnly.inMemory.first.stream.name, 'News of the World');
    });
  });

  // ── Widget smoke tests for the chip row ──
  //
  // Pump the `SearchScreen` widget with hand-rolled provider
  // overrides and assert on the chip row's labels, counts, and
  // selection state after tapping.
  group('V32 widget — _SearchTypeChips smoke test', () {
    testWidgets('renders 5 chips with non-zero counts for mixed results',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // Pre-seed the search service so the chip row has in-memory
      // results to count without depending on the catalogue
      // FutureProvider chain.
      final searchService = SearchService()
        ..rebuild(
          live: const [
            XtreamStream(
                streamId: 1, name: 'BBC One', categoryId: 1, streamType: 'live'),
            XtreamStream(
                streamId: 2, name: 'CNN', categoryId: 1, streamType: 'live'),
          ],
          vod: const [
            XtreamStream(
                streamId: 10, name: 'Inception', categoryId: 1, streamType: 'movie'),
          ],
          series: const [
            XtreamStream(
                streamId: 20, name: 'Breaking Bad', categoryId: 1, streamType: 'series'),
          ],
        );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchServiceProvider.overrideWithValue(searchService),
          searchIndexRebuilderProvider.overrideWith((ref) async {}),
          programmeTitleSearchProvider.overrideWith(
            (ref, query) async => <EpgProgrammeHit>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(searchQueryProvider.notifier).state = 'b';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Five chips: All, Live TV, VOD, Series, EPG. Scoped to the
      // chip row by Key so the result-list 'Live TV' / 'VOD' /
      // 'Series' type badges below don't double-match.
      final chips = find.byKey(const Key('searchTypeChips'));
      expect(find.descendant(of: chips, matching: find.text('All')),
          findsOneWidget);
      expect(find.descendant(of: chips, matching: find.text('Live TV')),
          findsOneWidget);
      expect(find.descendant(of: chips, matching: find.text('VOD')),
          findsOneWidget);
      expect(find.descendant(of: chips, matching: find.text('Series')),
          findsOneWidget);
      expect(find.descendant(of: chips, matching: find.text('EPG')),
          findsOneWidget);

      // The seeded index has 2 live + 1 VOD + 1 series = 4 in-memory
      // results; with query 'b' the matching subset is 2 (BBC + Breaking
      // Bad). The EPG column is empty. The chip row shows the
      // per-type counts: All=2, Live TV=1, VOD=0, Series=1, EPG=0.
      // The `0` count chips still render — they're tap-targets for
      // the user to discover that no VOD / EPG matches exist for the
      // current query.
      expect(find.descendant(of: chips, matching: find.text('2')),
          findsOneWidget); // All
      expect(find.descendant(of: chips, matching: find.text('1')),
          findsNWidgets(2)); // Live TV, Series
      // EPG and VOD both show 0 (their '0' digit).
      expect(find.descendant(of: chips, matching: find.text('0')),
          findsNWidgets(2));
    });

    testWidgets('tapping a chip updates the selection (drives the filter)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // Pre-seed the search service with one live match so the chip
      // row renders with non-zero counts.
      final searchService = SearchService()
        ..rebuild(
          live: const [
            XtreamStream(
                streamId: 1, name: 'BBC One', categoryId: 1, streamType: 'live'),
          ],
          vod: const <XtreamStream>[],
          series: const <XtreamStream>[],
        );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchServiceProvider.overrideWithValue(searchService),
          searchIndexRebuilderProvider.overrideWith((ref) async {}),
          programmeTitleSearchProvider.overrideWith(
            (ref, query) async => const <EpgProgrammeHit>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(searchQueryProvider.notifier).state = 'b';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SearchScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Default selection is `all`.
      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.all);

      // Tap the Live TV chip (scoped to the chip row to avoid
      // double-matching the result-list 'Live TV' type badge).
      final chips = find.byKey(const Key('searchTypeChips'));
      await tester.tap(find.descendant(of: chips, matching: find.text('Live TV')));
      await tester.pumpAndSettle();
      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.live);

      // Tap the VOD chip (count is 0 but the chip is still tappable).
      await tester.tap(find.descendant(of: chips, matching: find.text('VOD')));
      await tester.pumpAndSettle();
      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.vod);

      // Tap the All chip to clear the filter.
      await tester.tap(find.descendant(of: chips, matching: find.text('All')));
      await tester.pumpAndSettle();
      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.all);
    });
  });
}
