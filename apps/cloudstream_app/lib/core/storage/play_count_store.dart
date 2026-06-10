import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile play-frequency store, used to power the "Most Watched" home row
/// and the "Most Watched" / "Recently Played" channel-list sort modes.
///
/// Each time `PlayerScreen._saveProgress` fires (once every 30s + once on
/// dispose), we bump the counter for the current stream and stamp the
/// play time. Counters are monotonically increasing; the timestamp is
/// overwritten on every bump.
///
/// Key (count):   `play_count_{profileId}_{streamId}` → int
/// Key (time):    `play_last_{profileId}_{streamId}` → int (epoch ms)
class PlayCountStore {
  PlayCountStore(this._prefs);

  final SharedPreferences _prefs;

  static const _countPrefix = 'play_count';
  static const _lastPrefix = 'play_last';

  String _countKey(String profileId, int streamId) =>
      '${PlayCountStore._countPrefix}_${profileId}_$streamId';
  String _lastKey(String profileId, int streamId) =>
      '${PlayCountStore._lastPrefix}_${profileId}_$streamId';

  /// Increment the play count for [streamId] under [profileId] by 1,
  /// stamp the play time, and return the new count. Always returns
  /// at least 1.
  ///
  /// [at] is injectable for tests; production callers should let it
  /// default to [DateTime.now] so the stamped time is wall-clock UTC.
  Future<int> increment({
    required String profileId,
    required int streamId,
    DateTime? at,
  }) async {
    final next = getCount(profileId: profileId, streamId: streamId) + 1;
    await _prefs.setInt(_countKey(profileId, streamId), next);
    await _prefs.setInt(
      _lastKey(profileId, streamId),
      (at ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
    );
    return next;
  }

  /// Read the current count (0 if never played).
  int getCount({required String profileId, required int streamId}) {
    return _prefs.getInt(_countKey(profileId, streamId)) ?? 0;
  }

  /// Read the wall-clock millisecond timestamp of the most recent
  /// [increment] for [streamId] under [profileId], or `null` if the
  /// stream has never been played (or if only legacy v0.1.x–v0.1.48
  /// data exists without a stamped last-play time — forward-compat:
  /// the "Recently Played" sort treats such entries as epoch-0,
  /// pushing them to the bottom of the recency order).
  int? getLastPlayedAtMs({required String profileId, required int streamId}) {
    return _prefs.getInt(_lastKey(profileId, streamId));
  }

  /// All non-zero (streamId → count) entries for [profileId], ordered by
  /// count desc, then by streamId asc as a stable tie-breaker.
  List<({int streamId, int count})> topEntries(String profileId) {
    final pattern = RegExp('^${PlayCountStore._countPrefix}_${profileId}_(\\d+)\$');
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

  /// All (streamId → lastPlayedAtMs) entries for [profileId] that have
  /// ever been played, ordered by recency desc (most recent first).
  ///
  /// Streams with a stamped timestamp sort above streams without
  /// one — missing timestamps are treated as epoch-0, so legacy
  /// entries that pre-date the "Recently Played" sort always land at
  /// the bottom. Ties on timestamp are broken by streamId asc as a
  /// stable secondary key.
  List<({int streamId, int lastPlayedAtMs})> recentEntries(String profileId) {
    // Walk both the count-key and last-key patterns. Any stream that
    // was played at least once has a count key; the last key may be
    // missing on legacy installs (see [getLastPlayedAtMs]). The
    // count-key pattern is the source of truth for "ever played".
    final pattern = RegExp('^${PlayCountStore._countPrefix}_${profileId}_(\\d+)\$');
    final entries = <({int streamId, int lastPlayedAtMs})>[];
    for (final k in _prefs.getKeys()) {
      final m = pattern.firstMatch(k);
      if (m == null) continue;
      final id = int.parse(m.group(1)!);
      final count = _prefs.getInt(k) ?? 0;
      if (count <= 0) continue;
      final last = _prefs.getInt(_lastKey(profileId, id)) ?? 0;
      entries.add((streamId: id, lastPlayedAtMs: last));
    }
    entries.sort((a, b) {
      final byTime = b.lastPlayedAtMs.compareTo(a.lastPlayedAtMs);
      if (byTime != 0) return byTime;
      return a.streamId.compareTo(b.streamId);
    });
    return entries;
  }

  /// Clear a single stream's count + last-played stamp (e.g. user
  /// un-favourited AND wants to reset history). Not used by the
  /// default UI but exposed for parity with [WatchProgressStore].
  Future<void> clearCount({required String profileId, required int streamId}) async {
    await _prefs.remove(_countKey(profileId, streamId));
    await _prefs.remove(_lastKey(profileId, streamId));
  }
}
