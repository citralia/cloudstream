import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_store.dart';

/// Persists the user's preferred EPG reminder lead time (how long
/// before a programme starts the OS notification should fire) in
/// [SharedPreferences] under a single key. The choice is global
/// (not per-profile) — it's a viewing preference, not data that
/// should change when a family member switches profiles.
///
/// Forward-compat: an invalid stored value (not parseable as a
/// non-negative minute count) silently falls back to
/// [ReminderStore.defaultLeadTime] rather than crashing. This
/// matches the [ThemePreferencesStore] pattern.
class LeadTimePreferencesStore {
  LeadTimePreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'reminder_default_lead_minutes';

  /// Returns the currently-persisted lead time, or
  /// [ReminderStore.defaultLeadTime] (5 min) on first launch
  /// (no saved preference) or when the stored value is no longer
  /// a valid non-negative minute count.
  Duration load() {
    final raw = _prefs.getInt(_key);
    if (raw == null) return ReminderStore.defaultLeadTime;
    if (raw < 0) return ReminderStore.defaultLeadTime;
    return Duration(minutes: raw);
  }

  /// Persist [lead] rounded to whole minutes. The picker only
  /// exposes minute-granular options, so sub-minute precision would
  /// be lost on round-trip anyway.
  Future<void> save(Duration lead) async {
    await _prefs.setInt(_key, lead.inMinutes);
  }
}
