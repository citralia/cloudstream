import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A scheduled EPG reminder. The [startTime] is the programme's actual
/// start; the actual notification fires at [fireAt] (= [startTime] -
/// [leadTime]). The reminder is associated with a specific connection
/// ([profileName]) so a profile switch hides another profile's
/// reminders naturally.
class Reminder {
  final String id; // stable, e.g. "${channelId}-${startTime.millisecondsSinceEpoch}"
  final int channelId;
  final String channelName;
  final String programmeTitle;
  final DateTime startTime;
  final DateTime endTime;
  final Duration leadTime;
  final String profileName;

  const Reminder({
    required this.id,
    required this.channelId,
    required this.channelName,
    required this.programmeTitle,
    required this.startTime,
    required this.endTime,
    required this.leadTime,
    required this.profileName,
  });

  /// When the notification should fire. This is the time the user
  /// actually wants to be alerted (programme start minus the lead time).
  DateTime get fireAt => startTime.subtract(leadTime);

  /// True if this reminder is for a programme that has already ended.
  bool get isPast {
    final now = DateTime.now().toUtc();
    return now.isAfter(endTime);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelId': channelId,
        'channelName': channelName,
        'programmeTitle': programmeTitle,
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        'leadMinutes': leadTime.inMinutes,
        'profileName': profileName,
      };

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      channelId: json['channelId'] as int,
      channelName: json['channelName'] as String? ?? '',
      programmeTitle: json['programmeTitle'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] as String).toUtc(),
      endTime: DateTime.parse(json['endTime'] as String).toUtc(),
      leadTime: Duration(minutes: json['leadMinutes'] as int? ?? 5),
      profileName: json['profileName'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reminder && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Persists the user's scheduled EPG reminders in
/// [SharedPreferences] under a single JSON list. Reminders are
/// connection-scoped (each [Reminder] carries the [profileName] it
/// was created for) — the store does not enforce that scoping, the
/// provider layer is expected to filter by the active profile.
///
/// This is the data layer. The actual OS-level notification
/// scheduling lives in a separate `ReminderScheduler` service (not
/// part of V07 chunk 1) — for now, all `add` / `remove` calls
/// silently succeed and the UI just confirms the reminder was
/// recorded.
class ReminderStore {
  ReminderStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'epg_reminders_v1';

  /// Default lead time when the caller doesn't specify one. Five
  /// minutes is a good cable-box-style default — enough time to
  /// switch inputs / find the remote, not so much that the reminder
  /// fires before the user thinks about it.
  static const Duration defaultLeadTime = Duration(minutes: 5);

  /// Build a stable id for a (channel, programme) pair. Used by
  /// callers that want to check if a reminder already exists before
  /// adding a duplicate.
  static String makeId({
    required int channelId,
    required DateTime startTime,
  }) {
    return '$channelId-${startTime.toUtc().millisecondsSinceEpoch}';
  }

  /// All currently-saved reminders, in insertion order. Past
  /// reminders are NOT pruned here — callers can filter with
  /// [Reminder.isPast] if they want to display "active" only.
  List<Reminder> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final result = <Reminder>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          result.add(Reminder.fromJson(item));
        }
      }
      return result;
    } catch (_) {
      // Forward-compat: if the on-disk format ever becomes
      // unparseable, treat it as "no reminders" rather than crash.
      return [];
    }
  }

  /// Save [reminder]. If a reminder with the same id already
  /// exists, it is replaced — `add` is idempotent on the id.
  Future<void> add(Reminder reminder) async {
    final all = loadAll();
    final filtered = all.where((r) => r.id != reminder.id).toList();
    filtered.add(reminder);
    await _saveAll(filtered);
  }

  /// Remove the reminder with the given [id]. No-op if not present.
  Future<void> remove(String id) async {
    final all = loadAll();
    final filtered = all.where((r) => r.id != id).toList();
    if (filtered.length == all.length) return; // nothing changed
    await _saveAll(filtered);
  }

  /// Remove all reminders. Useful for a future "clear all" affordance
  /// in the Reminders list screen.
  Future<void> clear() async {
    await _prefs.setString(_key, '[]');
  }

  /// True if a reminder with [id] is currently stored.
  bool has(String id) => loadAll().any((r) => r.id == id);

  /// Filtered view: only reminders for the given profile and that
  /// have not ended yet. Sort is by [Reminder.fireAt] ascending.
  List<Reminder> activeForProfile(String profileName) {
    final all = loadAll();
    final active = all
        .where((r) => r.profileName == profileName && !r.isPast)
        .toList();
    active.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return active;
  }

  Future<void> _saveAll(List<Reminder> reminders) async {
    final encoded = jsonEncode(reminders.map((r) => r.toJson()).toList());
    await _prefs.setString(_key, encoded);
  }
}
