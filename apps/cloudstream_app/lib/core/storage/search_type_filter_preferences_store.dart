import 'package:shared_preferences/shared_preferences.dart';

/// The discriminator for the search-screen type filter chip row
/// (added in V32). Tapping a chip filters the result list to only
/// matches of the chosen type. **V35**: the chosen value is
/// persisted across app launches via
/// [SearchTypeFilterPreferencesStore] — V32 originally kept it
/// per-session in [StateProvider] memory only.
///
/// Lives in the `core/storage` layer (not the screens layer) so
/// the store and the providers can both import it without the
/// screens-layer pulling storage into a build dependency. The
/// screens file `search_screen.dart` re-imports it for rendering
/// (chip row + section header copy).
enum SearchResultTypeFilter {
  /// Default — render every section (in-memory channels/VOD/series +
  /// EPG programmes). Equivalent to "no filter applied".
  all,

  /// Show only live TV channels.
  live,

  /// Show only VOD movies.
  vod,

  /// Show only series.
  series,

  /// Show only EPG programme search results (the V27 column).
  epg,
}

/// Persists the user's preferred [SearchResultTypeFilter] (the
/// search-screen filter chip selection added in V32) in
/// [SharedPreferences] under a single key. The choice is global
/// (not per-profile) — it's a viewing preference, not data that
/// should change when a family member switches profiles.
///
/// Forward-compat: an invalid stored value (not a valid
/// [SearchResultTypeFilter] enum name) silently falls back to
/// [SearchResultTypeFilter.all] rather than crashing. This matches
/// the [ThemePreferencesStore] / [LeadTimePreferencesStore] pattern.
class SearchTypeFilterPreferencesStore {
  SearchTypeFilterPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'search_type_filter';

  /// Returns the currently-persisted filter (parsed to the
  /// [SearchResultTypeFilter] enum), or `null` on first launch (no
  /// saved preference) or when the stored value is no longer a
  /// valid enum (a future build could have removed or renamed a
  /// filter — fall back gracefully to `null` so the provider can
  /// default to [SearchResultTypeFilter.all]).
  SearchResultTypeFilter? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    for (final filter in SearchResultTypeFilter.values) {
      if (filter.name == raw) return filter;
    }
    return null;
  }

  /// Persist [filter]. Callers are expected to also update any
  /// in-memory Riverpod providers that mirror this state.
  Future<void> save(SearchResultTypeFilter filter) async {
    await _prefs.setString(_key, filter.name);
  }
}
