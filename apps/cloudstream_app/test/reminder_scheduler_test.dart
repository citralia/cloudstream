import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/notifications/reminder_scheduler.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/core/storage/reminder_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

/// Recording [ReminderScheduler] — captures every call so the test
/// can assert what the notifier asked the OS to do. Lighter than
/// mocking `flutter_local_notifications` (no platform channel).
class _FakeScheduler implements ReminderScheduler {
  _FakeScheduler({this.permissionGranted = true});

  bool permissionGranted;
  bool permissionRequested = false;
  int rehydrateCalls = 0;
  final List<Reminder> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<bool> requestPermission() async {
    permissionRequested = true;
    return permissionGranted;
  }

  @override
  Future<void> schedule(Reminder reminder) async {
    scheduled.add(reminder);
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
  }

  @override
  Future<void> rehydrate(List<Reminder> reminders) async {
    rehydrateCalls += 1;
    scheduled
      ..clear()
      ..addAll(reminders);
  }
}

class _FakeCredentialsStore implements CredentialsStore {
  _FakeCredentialsStore({this.activeName});
  String? activeName;

  @override
  Future<List<XtreamCredentials>> listConnections() async {
    if (activeName == null) return [];
    return [
      XtreamCredentials(
        name: activeName!,
        serverUrl: 'https://example.com',
        username: 'u',
        password: 'p',
      ),
    ];
  }

  @override
  Future<XtreamCredentials?> loadActiveConnection() async {
    if (activeName == null) return null;
    return XtreamCredentials(
      name: activeName!,
      serverUrl: 'https://example.com',
      username: 'u',
      password: 'p',
    );
  }

  @override
  Future<void> saveConnection({
    required String name,
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    activeName = name;
  }

  @override
  Future<void> setActiveConnection(String name) async {
    activeName = name;
  }

  @override
  Future<void> deleteConnection(String name) async {
    if (activeName == name) activeName = null;
  }

  @override
  Future<void> clearAll() async {
    activeName = null;
  }
}

class _TestRig {
  _TestRig(this.container, this.scheduler);
  final ProviderContainer container;
  final _FakeScheduler scheduler;
}

Future<_TestRig> _makeRig({String? activeConnectionName}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final credsStore = _FakeCredentialsStore(activeName: activeConnectionName);
  final profileStore = ProfileStore(prefs);
  if (activeConnectionName != null) {
    await profileStore.addProfile(name: activeConnectionName);
  }
  final scheduler = _FakeScheduler();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      profileStoreProvider.overrideWithValue(profileStore),
      credentialsStoreProvider.overrideWithValue(credsStore),
      reminderSchedulerProvider.overrideWithValue(scheduler),
    ],
  );
  await container.read(activeCredentialsProvider.future);
  return _TestRig(container, scheduler);
}

void main() {
  group('RemindersNotifier ↔ ReminderScheduler wiring', () {
    test('add() requests permission and schedules a notification', () async {
      final rig = await _makeRig(
        activeConnectionName: 'conn',
      );
      addTearDown(rig.container.dispose);

      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final end = start.add(const Duration(minutes: 30));
      final r = await rig.container.read(remindersProvider.notifier).add(
            channelId: 42,
            channelName: 'BBC One',
            programmeTitle: 'News',
            startTime: start,
            endTime: end,
          );

      expect(rig.scheduler.permissionRequested, isTrue);
      expect(rig.scheduler.scheduled, hasLength(1));
      expect(rig.scheduler.scheduled.first.id, r.id);
      expect(rig.scheduler.scheduled.first.programmeTitle, 'News');
      expect(rig.scheduler.cancelled, isEmpty);
    });

    test('remove() cancels the matching notification by id', () async {
      final rig = await _makeRig(
        activeConnectionName: 'conn',
      );
      addTearDown(rig.container.dispose);

      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final end = start.add(const Duration(minutes: 30));
      final r = await rig.container.read(remindersProvider.notifier).add(
            channelId: 7,
            channelName: 'ITV',
            programmeTitle: 'Drama',
            startTime: start,
            endTime: end,
          );

      await rig.container.read(remindersProvider.notifier).remove(r.id);

      expect(rig.scheduler.cancelled, [r.id]);
      expect(rig.container.read(remindersProvider), isEmpty);
    });

    test('add() then remove() then add() schedules a fresh notification',
        () async {
      final rig = await _makeRig(
        activeConnectionName: 'conn',
      );
      addTearDown(rig.container.dispose);

      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final end = start.add(const Duration(minutes: 30));
      final r1 = await rig.container.read(remindersProvider.notifier).add(
            channelId: 9,
            channelName: 'C4',
            programmeTitle: 'Film',
            startTime: start,
            endTime: end,
          );
      await rig.container.read(remindersProvider.notifier).remove(r1.id);
      // Idempotent on id — second add replaces in store, schedules fresh.
      final r2 = await rig.container.read(remindersProvider.notifier).add(
            channelId: 9,
            channelName: 'C4',
            programmeTitle: 'Film',
            startTime: start,
            endTime: end,
          );
      expect(r2.id, r1.id);
      expect(rig.scheduler.scheduled, hasLength(2)); // 1 from each add()
      expect(rig.scheduler.cancelled, [r1.id]); // only the remove()
    });

    test('refresh() re-schedules every active reminder for the profile',
        () async {
      final rig = await _makeRig(
        activeConnectionName: 'conn',
      );
      addTearDown(rig.container.dispose);

      // Pre-seed the store with two reminders, then build the
      // notifier via refresh() to exercise the rehydrate path.
      final store = rig.container.read(reminderStoreProvider);
      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      await store.add(Reminder(
        id: ReminderStore.makeId(channelId: 1, startTime: start),
        channelId: 1,
        channelName: 'BBC One',
        programmeTitle: 'Show A',
        startTime: start,
        endTime: start.add(const Duration(minutes: 30)),
        leadTime: const Duration(minutes: 5),
        profileName: 'conn',
      ));
      final start2 = start.add(const Duration(hours: 1));
      await store.add(Reminder(
        id: ReminderStore.makeId(channelId: 2, startTime: start2),
        channelId: 2,
        channelName: 'ITV',
        programmeTitle: 'Show B',
        startTime: start2,
        endTime: start2.add(const Duration(minutes: 30)),
        leadTime: const Duration(minutes: 5),
        profileName: 'conn',
      ));

      await rig.container.read(remindersProvider.notifier).refresh();

      expect(rig.scheduler.rehydrateCalls, 1);
      expect(rig.scheduler.scheduled, hasLength(2));
      final titles = rig.scheduler.scheduled.map((r) => r.programmeTitle).toList();
      expect(titles, ['Show A', 'Show B']);
    });

    test('refresh() drops reminders that belong to other profiles', () async {
      final rig = await _makeRig(
        activeConnectionName: 'conn',
      );
      addTearDown(rig.container.dispose);

      final store = rig.container.read(reminderStoreProvider);
      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      await store.add(Reminder(
        id: ReminderStore.makeId(channelId: 1, startTime: start),
        channelId: 1,
        channelName: 'BBC One',
        programmeTitle: 'Mine',
        startTime: start,
        endTime: start.add(const Duration(minutes: 30)),
        leadTime: const Duration(minutes: 5),
        profileName: 'conn',
      ));
      final start2 = start.add(const Duration(hours: 1));
      await store.add(Reminder(
        id: ReminderStore.makeId(channelId: 2, startTime: start2),
        channelId: 2,
        channelName: 'ITV',
        programmeTitle: 'Theirs',
        startTime: start2,
        endTime: start2.add(const Duration(minutes: 30)),
        leadTime: const Duration(minutes: 5),
        profileName: 'other-profile',
      ));

      await rig.container.read(remindersProvider.notifier).refresh();

      final titles = rig.scheduler.scheduled.map((r) => r.programmeTitle).toList();
      expect(titles, ['Mine']); // not 'Theirs'
    });

    test('add() still persists to the store when the scheduler is missing',
        () async {
      // Verifies the notifier tolerates a missing scheduler override
      // — this is the path exercised by reminders_list_screen_test.dart
      // (no scheduler override) when it calls add() and then checks
      // the in-memory list.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final credsStore = _FakeCredentialsStore(activeName: 'conn');
      final profileStore = ProfileStore(prefs);
      await profileStore.addProfile(name: 'conn');
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(profileStore),
          credentialsStoreProvider.overrideWithValue(credsStore),
          // Note: no reminderSchedulerProvider override — _safeScheduler
          // returns null, the notifier still persists.
        ],
      );
      addTearDown(container.dispose);
      await container.read(activeCredentialsProvider.future);

      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final end = start.add(const Duration(minutes: 30));
      final r = await container.read(remindersProvider.notifier).add(
            channelId: 11,
            channelName: 'C5',
            programmeTitle: 'Show',
            startTime: start,
            endTime: end,
          );

      expect(r.id, isNotEmpty);
      expect(container.read(remindersProvider), hasLength(1));
    });
  });
}
