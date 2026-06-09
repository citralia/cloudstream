import 'package:shared_preferences/shared_preferences.dart';

/// Available ordering modes for the live TV channel list.
///
/// Persisted via [ChannelSortStore] so the user's choice survives
/// across launches.
enum ChannelSortMode {
  /// Xtream server's natural order (the default). Channels appear in
  /// the order the provider returns them.
  defaultOrder,

  /// Alphabetical by display name, ascending. Case-insensitive.
  name,

  /// By the provider-supplied channel number. Many Xtream providers
  /// populate the `num` field on the live stream JSON; if it's missing
  /// we fall back to [XtreamStream.streamId] as a stable, monotonic
  /// tie-breaker.
  number,
}

/// Persists the user's preferred [ChannelSortMode] in
/// [SharedPreferences] under a single key. The choice is global (not
/// per-profile) — the sort is a viewing preference, not data that
/// should change when a family member switches profiles.
class ChannelSortStore {
  ChannelSortStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'channel_sort_mode';

  /// Returns the currently-persisted mode, or [ChannelSortMode.defaultOrder]
  /// if nothing has been saved yet (or the saved value is no longer a
  /// valid enum — forward-compat: a future build that removes a mode
  /// should silently fall back rather than crash).
  ChannelSortMode load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return ChannelSortMode.defaultOrder;
    for (final mode in ChannelSortMode.values) {
      if (mode.name == raw) return mode;
    }
    return ChannelSortMode.defaultOrder;
  }

  /// Persist [mode]. Callers are expected to also update any
  /// in-memory Riverpod providers that mirror this state.
  Future<void> save(ChannelSortMode mode) async {
    await _prefs.setString(_key, mode.name);
  }
}
