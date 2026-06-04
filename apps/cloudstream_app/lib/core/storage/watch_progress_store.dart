import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-profile VOD watch progress.
///
/// Key: `watch_progress_{profileId}_{streamId}` → JSON {positionMs, updatedAt}
class WatchProgressStore {
  WatchProgressStore(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'watch_progress';

  String _key(String profileId, int streamId) =>
      '${WatchProgressStore._prefix}_${profileId}_$streamId';

  /// Save watch progress for a VOD.
  Future<void> saveProgress({
    required String profileId,
    required int streamId,
    required int positionMs,
  }) async {
    final key = _key(profileId, streamId);
    final value = jsonEncode({
      'positionMs': positionMs,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await _prefs.setString(key, value);
  }

  /// Load saved progress, or null if none.
  WatchProgress? getProgress({
    required String profileId,
    required int streamId,
  }) {
    final key = _key(profileId, streamId);
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return WatchProgress(
        positionMs: map['positionMs'] as int,
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// Delete saved progress (e.g. when user finishes the video).
  Future<void> clearProgress({
    required String profileId,
    required int streamId,
  }) async {
    final key = _key(profileId, streamId);
    await _prefs.remove(key);
  }

  /// List all stream IDs with saved progress for a profile.
  List<int> savedStreamIds(String profileId) {
    final pattern = RegExp('^${WatchProgressStore._prefix}_${profileId}_(\\d+)\$');
    return _prefs
        .getKeys()
        .where((k) => pattern.hasMatch(k))
        .map((k) => int.parse(pattern.firstMatch(k)!.group(1)!))
        .toList();
  }
}

/// A saved watch-progress entry.
class WatchProgress {
  final int positionMs;
  final DateTime updatedAt;

  const WatchProgress({required this.positionMs, required this.updatedAt});

  Duration get position => Duration(milliseconds: positionMs);
}
