import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/storage/reminder_store.dart';

void main() {
  group('ReminderStore', () {
    late SharedPreferences prefs;
    late ReminderStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = ReminderStore(prefs);
    });

    test('loadAll returns empty list when nothing is saved', () {
      expect(store.loadAll(), isEmpty);
    });

    test('add then loadAll returns the saved reminder', () async {
      final r = Reminder(
        id: 'c1-1000',
        channelId: 1,
        channelName: 'BBC One',
        programmeTitle: 'News at 10',
        startTime: DateTime.utc(2026, 6, 9, 22, 0),
        endTime: DateTime.utc(2026, 6, 9, 22, 30),
        leadTime: ReminderStore.defaultLeadTime,
        profileName: 'Test',
      );
      await store.add(r);
      final loaded = store.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first, r);
    });

    test('add is idempotent on id (replace, not duplicate)', () async {
      final r = Reminder(
        id: 'c1-1000',
        channelId: 1,
        channelName: 'BBC One',
        programmeTitle: 'News at 10',
        startTime: DateTime.utc(2026, 6, 9, 22, 0),
        endTime: DateTime.utc(2026, 6, 9, 22, 30),
        leadTime: ReminderStore.defaultLeadTime,
        profileName: 'Test',
      );
      await store.add(r);
      // Same id, different title — should replace, not append.
      await store.add(Reminder(
        id: r.id,
        channelId: r.channelId,
        channelName: r.channelName,
        programmeTitle: 'News at 11 (updated)',
        startTime: r.startTime,
        endTime: r.endTime,
        leadTime: r.leadTime,
        profileName: r.profileName,
      ));
      final loaded = store.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.programmeTitle, 'News at 11 (updated)');
    });

    test('remove deletes the matching reminder', () async {
      final r1 = Reminder(
        id: 'c1-1000',
        channelId: 1,
        channelName: 'BBC One',
        programmeTitle: 'News at 10',
        startTime: DateTime.utc(2026, 6, 9, 22, 0),
        endTime: DateTime.utc(2026, 6, 9, 22, 30),
        leadTime: ReminderStore.defaultLeadTime,
        profileName: 'Test',
      );
      final r2 = Reminder(
        id: 'c2-2000',
        channelId: 2,
        channelName: 'CNN',
        programmeTitle: 'World Today',
        startTime: DateTime.utc(2026, 6, 9, 23, 0),
        endTime: DateTime.utc(2026, 6, 9, 23, 30),
        leadTime: ReminderStore.defaultLeadTime,
        profileName: 'Test',
      );
      await store.add(r1);
      await store.add(r2);

      await store.remove(r1.id);
      final loaded = store.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, r2.id);
    });

    test('remove is a no-op when id is unknown', () async {
      final r = Reminder(
        id: 'c1-1000',
        channelId: 1,
        channelName: 'BBC One',
        programmeTitle: 'News',
        startTime: DateTime.utc(2026, 6, 9, 22, 0),
        endTime: DateTime.utc(2026, 6, 9, 22, 30),
        leadTime: ReminderStore.defaultLeadTime,
        profileName: 'Test',
      );
      await store.add(r);
      await store.remove('does-not-exist');
      expect(store.loadAll(), hasLength(1));
    });

    test('clear removes all reminders', () async {
      for (var i = 0; i < 3; i++) {
        await store.add(Reminder(
          id: 'c$i-1000',
          channelId: i,
          channelName: 'Channel $i',
          programmeTitle: 'Programme $i',
          startTime: DateTime.utc(2026, 6, 9, 22, i),
          endTime: DateTime.utc(2026, 6, 9, 22, i + 1),
          leadTime: ReminderStore.defaultLeadTime,
          profileName: 'Test',
        ));
      }
      expect(store.loadAll(), hasLength(3));
      await store.clear();
      expect(store.loadAll(), isEmpty);
    });

    test('has returns true only when the id is stored', () async {
      final r = Reminder(
        id: 'c1-1000',
        channelId: 1,
        channelName: 'BBC One',
        programmeTitle: 'News',
        startTime: DateTime.utc(2026, 6, 9, 22, 0),
        endTime: DateTime.utc(2026, 6, 9, 22, 30),
        leadTime: ReminderStore.defaultLeadTime,
        profileName: 'Test',
      );
      expect(store.has(r.id), isFalse);
      await store.add(r);
      expect(store.has(r.id), isTrue);
      expect(store.has('something-else'), isFalse);
    });

    test('activeForProfile filters by profile and drops past', () async {
      // Future reminder on the target profile.
      final future = Reminder(
        id: 'c1-future',
        channelId: 1,
        channelName: 'BBC',
        programmeTitle: 'Future show',
        startTime: DateTime.now().toUtc().add(const Duration(hours: 2)),
        endTime: DateTime.now().toUtc().add(const Duration(hours: 3)),
        leadTime: ReminderStore.defaultLeadTime,
        profileName: 'Test',
      );
      // Past reminder on the target profile.
      final past = Reminder(
        id: 'c1-past',
        channelId: 1,
        channelName: 'BBC',
        programmeTitle: 'Past show',
        startTime: DateTime.now().toUtc().subtract(const Duration(hours: 3)),
        endTime: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        leadTime: ReminderStore.defaultLeadTime,
        profileName: 'Test',
      );
      // Future reminder on a different profile.
      final otherProfile = Reminder(
        id: 'c2-other',
        channelId: 2,
        channelName: 'CNN',
        programmeTitle: 'Other profile show',
        startTime: DateTime.now().toUtc().add(const Duration(hours: 4)),
        endTime: DateTime.now().toUtc().add(const Duration(hours: 5)),
        leadTime: ReminderStore.defaultLeadTime,
        profileName: 'OtherProfile',
      );
      await store.add(future);
      await store.add(past);
      await store.add(otherProfile);

      final active = store.activeForProfile('Test');
      expect(active, hasLength(1));
      expect(active.first.id, future.id);
    });

    test('activeForProfile sorts by fireAt ascending', () async {
      final later = Reminder(
        id: 'c1-later',
        channelId: 1,
        channelName: 'BBC',
        programmeTitle: 'Later show',
        startTime: DateTime.now().toUtc().add(const Duration(hours: 5)),
        endTime: DateTime.now().toUtc().add(const Duration(hours: 6)),
        leadTime: ReminderStore.defaultLeadTime,
        profileName: 'Test',
      );
      final sooner = Reminder(
        id: 'c1-sooner',
        channelId: 1,
        channelName: 'BBC',
        programmeTitle: 'Sooner show',
        startTime: DateTime.now().toUtc().add(const Duration(hours: 1)),
        endTime: DateTime.now().toUtc().add(const Duration(hours: 2)),
        leadTime: ReminderStore.defaultLeadTime,
        profileName: 'Test',
      );
      // Add in non-sorted order; the API should still return sorted.
      await store.add(later);
      await store.add(sooner);
      final active = store.activeForProfile('Test');
      expect(active.map((r) => r.id), ['c1-sooner', 'c1-later']);
    });

    test('makeId is stable for the same (channel, startTime)', () {
      final t = DateTime.utc(2026, 6, 9, 22, 0);
      final a = ReminderStore.makeId(channelId: 5, startTime: t);
      final b = ReminderStore.makeId(channelId: 5, startTime: t);
      expect(a, b);
    });

    test('makeId differs for different channels or start times', () {
      final t = DateTime.utc(2026, 6, 9, 22, 0);
      expect(
        ReminderStore.makeId(channelId: 5, startTime: t),
        isNot(ReminderStore.makeId(channelId: 6, startTime: t)),
      );
      expect(
        ReminderStore.makeId(channelId: 5, startTime: t),
        isNot(ReminderStore.makeId(
          channelId: 5,
          startTime: t.add(const Duration(minutes: 1)),
        )),
      );
    });
  });

  group('Reminder.fireAt', () {
    test('is start minus leadTime', () {
      final r = Reminder(
        id: 'x',
        channelId: 1,
        channelName: 'BBC',
        programmeTitle: 'News',
        startTime: DateTime.utc(2026, 6, 9, 22, 0),
        endTime: DateTime.utc(2026, 6, 9, 22, 30),
        leadTime: const Duration(minutes: 5),
        profileName: 'Test',
      );
      expect(r.fireAt, DateTime.utc(2026, 6, 9, 21, 55));
    });
  });

  group('Reminder roundtrip', () {
    test('toJson / fromJson preserves all fields', () {
      final r = Reminder(
        id: 'c1-1000',
        channelId: 1,
        channelName: 'BBC One',
        programmeTitle: 'News at 10',
        startTime: DateTime.utc(2026, 6, 9, 22, 0),
        endTime: DateTime.utc(2026, 6, 9, 22, 30),
        leadTime: const Duration(minutes: 7),
        profileName: 'Test',
      );
      final cloned = Reminder.fromJson(r.toJson());
      expect(cloned.id, r.id);
      expect(cloned.channelId, r.channelId);
      expect(cloned.channelName, r.channelName);
      expect(cloned.programmeTitle, r.programmeTitle);
      expect(cloned.startTime, r.startTime);
      expect(cloned.endTime, r.endTime);
      expect(cloned.leadTime, r.leadTime);
      expect(cloned.profileName, r.profileName);
    });
  });

  group('ReminderStore corruption', () {
    test('loadAll returns empty list when the on-disk json is garbage',
        () async {
      SharedPreferences.setMockInitialValues({
        'epg_reminders_v1': 'not valid json {[',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = ReminderStore(prefs);
      expect(store.loadAll(), isEmpty);
    });
  });
}
