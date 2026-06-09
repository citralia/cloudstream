import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/core/storage/reminder_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';
import 'package:cloudstream_app/presentation/screens/reminders_list_screen.dart';

/// Minimal [CredentialsStore] that holds a single named connection
/// in memory. Mirrors the pattern in `continue_watching_test.dart` /
/// `most_watched_test.dart` so we don't have to spin up a
/// [FlutterSecureStorage] platform channel.
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

Future<ProviderContainer> _makeContainer({
  String? activeConnectionName,
  Duration? initialLeadTime,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final credsStore = _FakeCredentialsStore(activeName: activeConnectionName);
  final profileStore = ProfileStore(prefs);
  if (activeConnectionName != null) {
    await profileStore.addProfile(name: activeConnectionName);
  }
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      profileStoreProvider.overrideWithValue(profileStore),
      credentialsStoreProvider.overrideWithValue(credsStore),
      if (initialLeadTime != null)
        defaultLeadTimeProvider.overrideWith((ref) => initialLeadTime),
    ],
  );
  // Force the FutureProvider<XtreamCredentials?> to resolve so
  // downstream consumers (RemindersNotifier) can read it.
  await container.read(activeCredentialsProvider.future);
  return container;
}

void main() {
  group('defaultLeadTimeProvider', () {
    test('defaults to ReminderStore.defaultLeadTime (5 min)', () async {
      // V10: the provider now reads from LeadTimePreferencesStore on
      // first read, so we have to provide a SharedPreferences override.
      // An empty mock = first-launch path = 5-min default.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);
      expect(container.read(defaultLeadTimeProvider), ReminderStore.defaultLeadTime);
    });

    test('can be overridden to a custom value', () {
      final container = ProviderContainer(
        overrides: [
          defaultLeadTimeProvider.overrideWith((ref) => Duration(minutes: 20)),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(defaultLeadTimeProvider), Duration(minutes: 20));
    });

    test('is read by RemindersNotifier.add when scheduling', () async {
      final container = await _makeContainer(
        activeConnectionName: 'conn',
        initialLeadTime: Duration(minutes: 30),
      );
      addTearDown(container.dispose);

      // Schedule a reminder ~2h in the future so it isn't auto-pruned.
      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final end = start.add(const Duration(minutes: 30));
      final reminder = await container.read(remindersProvider.notifier).add(
            channelId: 1,
            channelName: 'BBC One',
            programmeTitle: 'News',
            startTime: start,
            endTime: end,
          );

      // The lead time on the stored reminder should be the
      // overridden 30 min, NOT the static 5 min default.
      expect(reminder.leadTime, Duration(minutes: 30));
      // And the in-memory list should reflect it.
      final list = container.read(remindersProvider);
      expect(list, hasLength(1));
      expect(list.first.leadTime, Duration(minutes: 30));
    });

    test('explicit leadTime argument to add() wins over the provider', () async {
      final container = await _makeContainer(
        activeConnectionName: 'conn',
        initialLeadTime: Duration(minutes: 30),
      );
      addTearDown(container.dispose);

      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final end = start.add(const Duration(minutes: 30));
      final reminder = await container.read(remindersProvider.notifier).add(
            channelId: 2,
            channelName: 'ITV',
            programmeTitle: 'Documentary',
            startTime: start,
            endTime: end,
            leadTime: Duration(minutes: 2),
          );
      expect(reminder.leadTime, Duration(minutes: 2));
    });

    test('changing the provider after construction does not retro-edit saved reminders',
        () async {
      final container = await _makeContainer(
        activeConnectionName: 'conn',
        initialLeadTime: Duration(minutes: 5),
      );
      addTearDown(container.dispose);

      // Schedule with the initial 5-min lead.
      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final end = start.add(const Duration(minutes: 30));
      final original = await container.read(remindersProvider.notifier).add(
            channelId: 7,
            channelName: 'Ch7',
            programmeTitle: 'Show A',
            startTime: start,
            endTime: end,
          );
      expect(original.leadTime, Duration(minutes: 5));

      // User opens Settings and changes the default to 30 min.
      container.read(defaultLeadTimeProvider.notifier).state =
          Duration(minutes: 30);

      // The already-saved reminder should keep its original lead
      // time — the picker only affects new reminders.
      final list = container.read(remindersProvider);
      expect(list, hasLength(1));
      expect(list.first.leadTime, Duration(minutes: 5));
    });
  });

  group('RemindersListScreen', () {
    Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
      final container = await _makeContainer(
        activeConnectionName: 'conn',
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RemindersListScreen()),
        ),
      );
      return container;
    }

    testWidgets('shows the empty state when no reminders are scheduled',
        (tester) async {
      final container = await pumpScreen(tester);
      addTearDown(container.dispose);
      // The empty state copy.
      expect(find.text('No reminders yet'), findsOneWidget);
      expect(
        find.text('Long-press a programme in the EPG guide to schedule a reminder.'),
        findsOneWidget,
      );
      // No list items.
      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('lists scheduled reminders with their title, channel, and time',
        (tester) async {
      final container = await _makeContainer(
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      // Schedule one reminder, 2 hours out.
      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final end = start.add(const Duration(minutes: 30));
      await container.read(remindersProvider.notifier).add(
            channelId: 1,
            channelName: 'BBC One',
            programmeTitle: 'News at 10',
            startTime: start,
            endTime: end,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RemindersListScreen()),
        ),
      );
      await tester.pump();

      // The row content is rendered.
      expect(find.text('News at 10'), findsOneWidget);
      expect(find.text('BBC One'), findsOneWidget);
      // 1 upcoming subtitle on the app bar.
      expect(find.text('1 upcoming'), findsOneWidget);
      // The schedule line should mention "Today" (or Tomorrow etc.
      // depending on the wall clock — for the "2h ahead" fixture
      // it's almost always Today; we just assert that some kind of
      // schedule line is rendered next to the clock icon).
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('swipe-to-delete dismisses a reminder and shows a snackbar',
        (tester) async {
      final container = await _makeContainer(
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final end = start.add(const Duration(minutes: 30));
      await container.read(remindersProvider.notifier).add(
            channelId: 1,
            channelName: 'BBC One',
            programmeTitle: 'News at 10',
            startTime: start,
            endTime: end,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RemindersListScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('News at 10'), findsOneWidget);

      // Swipe the Dismissible from right to left.
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // The reminder is gone from the in-memory list, the empty
      // state is back, and a snackbar confirms.
      expect(container.read(remindersProvider), isEmpty);
      expect(find.text('No reminders yet'), findsOneWidget);
      expect(
        find.text('Reminder cancelled — News at 10'),
        findsOneWidget,
      );
    });
  });
}
