import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preferred [ThemeMode] in [SharedPreferences]
/// under a single key. The choice is global (not per-profile) — it's
/// a viewing preference, not data that should change when a family
/// member switches profiles.
///
/// Forward-compat: if the stored string is no longer a valid
/// [ThemeMode] enum value (e.g. a future build removed or renamed a
/// mode), [load] silently falls back to [ThemeMode.system] rather
/// than crashing.
class ThemePreferencesStore {
  ThemePreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'app_theme_mode';

  /// Returns the currently-persisted [ThemeMode], or
  /// [ThemeMode.system] on first launch (no saved preference) or
  /// when the stored value is no longer a valid enum.
  ThemeMode load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return ThemeMode.system;
    for (final mode in ThemeMode.values) {
      if (mode.name == raw) return mode;
    }
    return ThemeMode.system;
  }

  /// Persist [mode]. Callers are expected to also update any
  /// in-memory Riverpod providers that mirror this state.
  Future<void> save(ThemeMode mode) async {
    await _prefs.setString(_key, mode.name);
  }
}
