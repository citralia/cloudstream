// V35 — Persist search type filter chip selection.
//
// Closes a V32 follow-on gap: the search-screen type filter chip
// row (added in V32) kept its selection in a StateProvider
// (`searchTypeFilterProvider`) in memory only — closing the screen
// and reopening it (or relaunching the app) reset the chip to
// `all`. A user who consistently searches only VOD on a Firestick
// with a 200-channel live catalogue had to re-select the "VOD"
// chip every time they opened the search tab.
//
// V35 mirrors the V08 theme-preference / V10 lead-time pattern:
//   - `SearchTypeFilterPreferencesStore` (this file's
//     counterpart in `core/storage/`) — SharedPreferences-backed,
//     single key `search_type_filter`, enum-name round-trip,
//     forward-compat fallback to `null` on unknown stored values.
//   - `searchTypeFilterPreferencesStoreProvider` (Provider) — wires
//     the store to the Riverpod graph.
//   - `searchTypeFilterProvider` (StateProvider) — moved out of
//     `search_screen.dart` to `app_providers.dart`; initial value
//     is read from the store on first read (was: hard-coded
//     `SearchResultTypeFilter.all`).
//   - `search_screen.dart` chip onTap now writes through to both
//     the in-memory provider AND the store (same pattern as the
//     V08 theme tile + V10 lead-time picker).
//   - `SearchResultTypeFilter` enum moved to the store file (so
//     both screens + providers can import the same canonical
//     type without a screens→core dependency).
//
// V32 test changes: the V32 "per-session (not persisted)" test
// flipped to "persists across new containers (V35 — store-backed)"
// + a new "falls back to all on fresh install" default-preservation
// regression guard. The V32 `filterSearchResults` pure-function
// tests and the integration tests are unchanged — V35 is purely
// additive on the persistence side.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloudstream_app/core/storage/search_type_filter_preferences_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

void main() {
  group('SearchTypeFilterPreferencesStore', () {
    test('load returns null on a fresh install (no stored key)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SearchTypeFilterPreferencesStore(prefs);

      expect(store.load(), isNull);
    });

    test('save then load round-trips every enum variant', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SearchTypeFilterPreferencesStore(prefs);

      for (final filter in SearchResultTypeFilter.values) {
        await store.save(filter);
        // Fresh store backed by the same prefs should see the
        // latest write — same as a cold app launch.
        final fresh = SearchTypeFilterPreferencesStore(prefs);
        expect(fresh.load(), filter, reason: 'round-trip failed for $filter');
      }
    });

    test('load returns null for an unknown stored value (forward-compat)',
        () async {
      // A future build that removed or renamed a filter chip
      // could leave a stale string behind (e.g. an old "epg"
      // replaced by something else). The store must not crash —
      // returning null lets the provider default to `all`.
      SharedPreferences.setMockInitialValues({
        'search_type_filter': 'something_from_the_future',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = SearchTypeFilterPreferencesStore(prefs);

      expect(store.load(), isNull);
    });

    test('save then load is observable across fresh instances', () async {
      // Mirrors the production flow: chip tap calls store.save()
      // and the in-memory provider; a future app launch reads
      // from store.load() and surfaces the same value.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final s1 = SearchTypeFilterPreferencesStore(prefs);
      await s1.save(SearchResultTypeFilter.vod);

      final s2 = SearchTypeFilterPreferencesStore(prefs);
      expect(s2.load(), SearchResultTypeFilter.vod);
    });
  });

  group('searchTypeFilterProvider', () {
    test('reads the persisted value on init (not the hard-coded all)',
        () async {
      SharedPreferences.setMockInitialValues({
        'search_type_filter': 'vod',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.vod);
    });

    test('falls back to all on a fresh install (no stored key)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.all);
    });

    test('falls back to all on an unknown stored value (forward-compat)',
        () async {
      // Forward-compat: a build that wrote a stale enum name
      // (e.g. "epg" renamed to "programmes") must not crash
      // — the provider defaults to `all` on unknown.
      SharedPreferences.setMockInitialValues({
        'search_type_filter': 'programmes',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      expect(container.read(searchTypeFilterProvider),
          SearchResultTypeFilter.all);
    });

    test('in-memory update does not silently overwrite the persisted value',
        () async {
      // The chip row writes through store.save() in addition to
      // mutating the provider. If a caller ever mutates the
      // provider directly (e.g. a future test or a stub UI), the
      // store should still hold the *previous* persisted value —
      // a re-read picks up the truth, not the in-memory mutation.
      SharedPreferences.setMockInitialValues({
        'search_type_filter': 'live',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      // Mutate the in-memory provider without going through
      // store.save().
      container.read(searchTypeFilterProvider.notifier).state =
          SearchResultTypeFilter.series;

      // The store still holds the original value.
      final store = container.read(searchTypeFilterPreferencesStoreProvider);
      expect(store.load(), SearchResultTypeFilter.live);

      // A fresh container reading the same prefs would see the
      // stored value, not the in-memory mutation.
      final c2 = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(c2.dispose);
      expect(c2.read(searchTypeFilterProvider), SearchResultTypeFilter.live);
    });

    test('store.save() write is observable to a fresh container', () async {
      // Mirrors the production flow: chip tap calls
      // store.save(entry.filter) and the in-memory provider; a
      // future app launch reads from store.load() and surfaces
      // the same value in the provider.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final c1 = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(c1.dispose);
      await c1
          .read(searchTypeFilterPreferencesStoreProvider)
          .save(SearchResultTypeFilter.series);
      c1.read(searchTypeFilterProvider.notifier).state =
          SearchResultTypeFilter.series;

      final c2 = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(c2.dispose);
      expect(
          c2.read(searchTypeFilterProvider), SearchResultTypeFilter.series);
    });

    test('per-variant: every chip value round-trips through the store',
        () async {
      // Pin down that all 5 V32 enum values (`all`, `live`, `vod`,
      // `series`, `epg`) survive the store round-trip, not just
      // the ones the smoke tests happen to exercise.
      for (final filter in SearchResultTypeFilter.values) {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ]);
        addTearDown(container.dispose);

        // Fresh install → defaults to `all` (preserved V32
        // first-open behaviour, even if we're about to
        // overwrite).
        expect(container.read(searchTypeFilterProvider),
            SearchResultTypeFilter.all,
            reason: 'fresh install should default to all for $filter test');

        // Simulate the chip onTap (write through both layers).
        await container
            .read(searchTypeFilterPreferencesStoreProvider)
            .save(filter);
        container.read(searchTypeFilterProvider.notifier).state = filter;
        expect(container.read(searchTypeFilterProvider), filter,
            reason: 'in-memory read failed for $filter');

        // Fresh container (cold restart simulation) — store
        // round-trips the value.
        final cold = ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ]);
        addTearDown(cold.dispose);
        expect(cold.read(searchTypeFilterProvider), filter,
            reason: 'cold restart lost the $filter value');
      }
    });
  });
}
