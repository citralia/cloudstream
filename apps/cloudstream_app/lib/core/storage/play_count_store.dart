import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile play-frequency store, used to power the "Most Watched" home row.
///
/// Each time `PlayerScreen._saveProgress` fires (once every 30s + once on
/// dispose), we bump the counter for the current stream. Counters are
/// monotonically increasing — the row sorts by count desc, then by most
/// recent play.
///
/// Key: `play_count_{profileId}_{streamId}` → int (JSON-encoded as a number).
class PlayCountStore {
  PlayCountStore(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'play_count';

  String _key(String profileId, int streamId) =>
      '${PlayCountStore._prefix}_${profileId}_$streamId';

  /// Increment the play count for [streamId] under [profileId] by 1 and
  /// return the new value. Always returns at least 1.
  Future<int> increment({required String profileId, required int streamId}) async {
    final key = _key(profileId, streamId);
    final next = getCount(profileId: profileId, streamId: streamId) + 1;
    await _prefs.setInt(key, next);
    return next;
  }

  /// Read the current count (0 if never played).
  int getCount({required String profileId, required int streamId}) {
    return _prefs.getInt(_key(profileId, streamId)) ?? 0;
  }

  /// All non-zero (streamId → count) entries for [profileId], ordered by
  /// count desc, then by streamId asc as a stable tie-breaker.
  List<({int streamId, int count})> topEntries(String profileId) {
    final pattern = RegExp('^${PlayCountStore._prefix}_${profileId}_(\\d+)\$');
    final entries = <({int streamId, int count})>[];
    for (final k in _prefs.getKeys()) {
      final m = pattern.firstMatch(k);
      if (m == null) continue;
      final id = int.parse(m.group(1)!);
      final count = _prefs.getInt(k) ?? 0;
      if (count > 0) entries.add((streamId: id, count: count));
    }
    entries.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.streamId.compareTo(b.streamId);
    });
    return entries;
  }

  /// Clear a single stream's count (e.g. user un-favourited AND wants to
  /// reset history). Not used by the default UI but exposed for parity
  /// with `WatchProgressStore`.
  Future<void> clearCount({required String profileId, required int streamId}) async {
    await _prefs.remove(_key(profileId, streamId));
  }
}
