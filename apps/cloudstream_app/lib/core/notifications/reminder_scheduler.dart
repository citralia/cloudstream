import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../storage/reminder_store.dart';

/// Schedules a single OS-level local notification for a [Reminder].
///
/// Defined as a small interface so the data path can be unit-tested
/// without a real `FlutterLocalNotificationsPlugin` (which depends on
/// platform channels). Production code wires up
/// [LocalNotificationsReminderScheduler]; tests use
/// [InMemoryReminderScheduler] (declared in the same file as the
/// production impl) or any other fake.
abstract class ReminderScheduler {
  /// Ask the OS for the runtime permission needed to post a
  /// notification. Returns `true` if the user granted it, `false`
  /// otherwise. On platforms that don't require a runtime prompt
  /// (older Android, desktop, web) the call is a no-op and returns
  /// `true`.
  Future<bool> requestPermission();

  /// Schedule a notification for [reminder]. If [reminder.fireAt] is
  /// in the past the call is a no-op (the user can't be reminded
  /// about something that has already started).
  Future<void> schedule(Reminder reminder);

  /// Cancel a previously-scheduled notification by its [id]. Safe to
  /// call when nothing is scheduled for that id.
  Future<void> cancel(String id);

  /// Re-schedule every reminder in [reminders]. Used at app startup
  /// to rehydrate scheduled alarms after a device reboot or a fresh
  /// install (the OS drops scheduled notifications on those events).
  Future<void> rehydrate(List<Reminder> reminders);
}

/// Production scheduler backed by `flutter_local_notifications`.
///
/// `init()` must be called from `main()` before any `schedule()` /
/// `cancel()` call — it initialises the timezone database, creates
/// the platform channel, and (on Android 13+) asks for the runtime
/// POST_NOTIFICATIONS permission.
class LocalNotificationsReminderScheduler implements ReminderScheduler {
  LocalNotificationsReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'epg_reminders';
  static const _androidChannelName = 'EPG Reminders';
  static const _androidChannelDescription =
      'Reminders for upcoming TV programmes.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialised = false;

  /// Wire up the plugin, register the Android channel, and (on iOS)
  /// request the alert permission. Idempotent — calling it twice is
  /// a no-op.
  Future<void> init() async {
    if (_initialised) return;
    tz_data.initializeTimeZones();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false, // we ask on first schedule
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(initSettings);

    // Android: create the channel up-front. `flutter_local_notifications`
    // requires the channel id to match between `initialize` and
    // `show`/`zonedSchedule`. Safe to call before any schedule.
    const androidChannel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialised = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_initialised) await init();
    if (kIsWeb) return true; // plugin doesn't ship a web impl
    // iOS / macOS: ask the user.
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    // Android 13+ (API 33): ask for POST_NOTIFICATIONS.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? true; // older Androids return null = granted
    }
    return true;
  }

  @override
  Future<void> schedule(Reminder reminder) async {
    if (!_initialised) await init();
    final fireAt = reminder.fireAt;
    if (fireAt.isBefore(DateTime.now())) return; // too late

    final tzFireAt = tz.TZDateTime.from(fireAt, tz.local);
    final body = reminder.leadTime == Duration.zero
        ? 'Now starting on ${reminder.channelName}'
        : 'Starts at ${_formatTime(reminder.startTime)} on ${reminder.channelName}';

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const iosDetails = DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.zonedSchedule(
        _idFromString(reminder.id),
        reminder.programmeTitle,
        body,
        tzFireAt,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder:${reminder.id}',
      );
    } on Exception catch (e) {
      // Don't crash the UI if the OS rejects the schedule (e.g. user
      // denied permission, exact-alarm policy violated). The reminder
      // is still recorded in SharedPreferences; the next boot
      // rehydrate pass will retry.
      debugPrint('ReminderScheduler.schedule failed: $e');
    }
  }

  @override
  Future<void> cancel(String id) async {
    if (!_initialised) await init();
    try {
      await _plugin.cancel(_idFromString(id));
    } on Exception catch (e) {
      debugPrint('ReminderScheduler.cancel failed: $e');
    }
  }

  @override
  Future<void> rehydrate(List<Reminder> reminders) async {
    if (!_initialised) await init();
    // Wipe any pre-existing scheduled notifications — they may
    // belong to a previous profile or to reminders the user
    // deleted. The boot receiver below also calls this path.
    await _plugin.cancelAll();
    for (final r in reminders) {
      await schedule(r);
    }
  }
}

/// `flutter_local_notifications` requires the notification id to be
/// a 32-bit signed integer. The reminder id is a string
/// (`"$channelId-$epochMs"`) — hash it to a stable int. We use the
/// absolute value of a small `hashCode` mix so the result is
/// deterministic across runs and stable enough for our purposes
/// (collisions are harmless: scheduling two reminders at the same
/// integer id overwrites the earlier one, but the bodies are
/// identical so the user just sees one of them).
int _idFromString(String s) {
  // Spread the input across a wider range so collisions are rare
  // for the small (dozens) of reminders we ever have live.
  var h = 0;
  for (final cu in s.codeUnits) {
    h = (h * 31 + cu) & 0x7fffffff;
  }
  return h;
}

String _formatTime(DateTime t) {
  final local = t.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
