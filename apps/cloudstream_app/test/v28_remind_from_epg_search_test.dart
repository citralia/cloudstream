// V28 — "Remind me when this programme is on" — long-press on EPG
// search result.
//
// Closes the V07+V27 follow-on gap: V07 added the EPG-programme
// reminder feature (long-press a programme block in the EPG guide
// → RemindersNotifier.add → OS notification scheduled by the
// ReminderScheduler implementation). V27 added programme-title
// search to the search screen, surfacing `EpgProgrammeHit`s as
// `_EpgResultTile`s below the existing in-memory results. A user
// searching for a programme title had no way to set a reminder from
// the search screen — they had to tap into the EPG guide first, then
// long-press the programme block. V28 closes that gap: long-press a
// V27 `_EpgResultTile` directly to toggle a reminder for that
// programme.
//
// V28 is a pure widget-layer change (no new provider, no data-layer
// shape changes). `_EpgResultTile` becomes a `ConsumerWidget` (was
// `StatelessWidget`), reads `remindersProvider.select(...)` to
// decide whether to show a small `Icons.notifications_active`
// indicator on the tile, and adds a long-press handler that mirrors
// the EPG guide's `_ProgrammeBlock._onLongPress` flow:
//   - future-only guard (`hit.programme.startTime > now`)
//   - toggle: RemindersNotifier.add if no reminder, .remove if there is
//   - snackbar with fire time on add / "Reminder removed" on remove
//
// The "already-reminded" predicate is the headline data-layer wiring
// the V28 long-press path depends on: it uses
// `ReminderStore.makeId(channelId, startTime)` — the exact same id
// shape the EPG guide uses — so a reminder set from either surface
// is reflected in the other's indicator/badge.
//
// Test scope follows the V22 / V23 / V24 / V26 / V27 pattern: pure
// data-layer / Riverpod injection tests for the new behaviour. The
// widget changes (`_EpgResultTile` ConsumerWidget + onLongPress +
// bell icon) are thin and covered by source migration + analyze
// (same trade-off V14 chunk 2 + V15 made for player surfaces that
// don't pump cleanly in unit tests).
//
// Fixture pattern follows v27_epg_programme_search_test.dart:
// `_FakeCredentialsStore` + `_FakeXtreamClient` (with liveStreams +
// per-stream EPG via getEpg) + `makeContainer` helper that overrides
// the storage + client + live + epg providers. Per-channel EPG seed
// lets us construct deterministic multi-channel scenarios (the V27
// fakes are intentionally in-file for self-containment — see V22
// entry's "intentionally per-file" note).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/core/storage/reminder_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

// ─── Test doubles ────────────────────────────────────────────────────────

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

class _FakeXtreamClient extends XtreamApiClient {
  _FakeXtreamClient({
    required this.liveStreams,
    required this.epgByStreamId,
  });

  final List<XtreamStream> liveStreams;
  final Map<int, List<XtreamEpgEntry>> epgByStreamId;

  @override
  Future<List<XtreamStream>> getLiveStreams({int? categoryId}) async {
    if (categoryId == null) return liveStreams;
    return liveStreams.where((s) => s.categoryId == categoryId).toList();
  }

  @override
  Future<List<XtreamEpgEntry>> getEpg(int streamId) async {
    final entries = epgByStreamId[streamId];
    if (entries == null) {
      throw Exception('epg unavailable for stream $streamId');
    }
    return entries;
  }
}

// ─── Fixture helpers ─────────────────────────────────────────────────────

XtreamEpgEntry _epg({
  required int start,
  required int end,
  required String title,
  String? description,
  String channelId = 'c',
}) {
  return XtreamEpgEntry(
    channelId: channelId,
    start: start,
    end: end,
    title: title,
    description: description,
  );
}

Future<ProviderContainer> _makeContainer({
  required List<XtreamStream> liveStreams,
  required Map<int, List<XtreamEpgEntry>> epgByStreamId,
  String? activeConnectionName,
  Duration? initialLeadTime,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final profileStore = ProfileStore(prefs);
  if (activeConnectionName != null) {
    await profileStore.addProfile(name: activeConnectionName);
  }
  final credsStore = _FakeCredentialsStore(activeName: activeConnectionName);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      profileStoreProvider.overrideWithValue(profileStore),
      credentialsStoreProvider.overrideWithValue(credsStore),
      xtreamClientProvider.overrideWith(
        (ref) => _FakeXtreamClient(
          liveStreams: liveStreams,
          epgByStreamId: epgByStreamId,
        ),
      ),
      if (initialLeadTime != null)
        defaultLeadTimeProvider.overrideWith((ref) => initialLeadTime),
    ],
  );
  // Force the FutureProvider<XtreamCredentials?> to resolve so
  // RemindersNotifier (which reads it on construction) sees the
  // active profile. Same dance as reminders_list_screen_test.dart.
  await container.read(activeCredentialsProvider.future);
  return container;
}

// ─── Tests ───────────────────────────────────────────────────────────────

void main() {
  group('V28 — remind from EPG search result', () {
    // Future programme, anchored ~2h ahead so the data path doesn't
    // prune it (ReminderStore drops reminders whose fire time is in
    // the past) and the V28 long-press future-only guard passes.
    final futureStartMs = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 2))
        .millisecondsSinceEpoch;
    final futureStartSec = futureStartMs ~/ 1000;
    final futureEndSec =
        futureStartSec + 30 * 60; // 30-min programme window

    final stream = const XtreamStream(
      streamId: 42,
      name: 'BBC One',
      categoryId: 1,
      streamType: 'live',
    );

    final epgEntry = _epg(
      start: futureStartSec,
      end: futureEndSec,
      title: 'Match of the Day',
    );

    test('EpgProgrammeHit carries exactly the data RemindersNotifier.add needs',
        () async {
      // Headline V28 invariant: the `EpgProgrammeHit` shape
      // (channel.streamId / channel.name / programme.title /
      // programme.startTime / programme.endTime) is a structural
      // subset of the `RemindersNotifier.add` parameters. A future
      // maintainer can wire the long-press handler without any data
      // shimming. This test is the "trust but verify" companion to
      // the in-file _onLongPress call site.
      //
      // Note: `XtreamEpgEntry.startTime` is a local-time DateTime
      // derived from the unix-seconds field via
      // `DateTime.fromMillisecondsSinceEpoch(start * 1000)` (no
      // `isUtc: true`). The instant it represents is the same as the
      // UTC unix-seconds moment — so comparing the millisecondsSinceEpoch
      // round-trip is correct (millisecondsSinceEpoch is always
      // UTC-anchored).
      final hit = EpgProgrammeHit(channel: stream, programme: epgEntry);
      expect(hit.channel.streamId, 42);
      expect(hit.channel.name, 'BBC One');
      expect(hit.programme.title, 'Match of the Day');
      // Compare at second precision — the epgEntry's start is
      // constructed from `futureStartSec * 1000` (truncated).
      expect(
        hit.programme.startTime.millisecondsSinceEpoch,
        futureStartSec * 1000,
      );
      expect(
        hit.programme.endTime.millisecondsSinceEpoch,
        futureEndSec * 1000,
      );
    });

    test(
        'RemindersNotifier.add stores a reminder with the (channelId, startTime) id',
        () async {
      // The V28 long-press handler computes
      // `ReminderStore.makeId(channelId, startTime)` and passes it to
      // `add()`. The same id is computed by the EPG guide for its own
      // bell-icon check. This test asserts the id shape so the V28
      // "already reminded?" predicate and the EPG guide's
      // `remindersProvider.any((r) => r.id == id)` predicate agree.
      final container = await _makeContainer(
        liveStreams: [stream],
        epgByStreamId: {42: [epgEntry]},
        activeConnectionName: 'conn',
        initialLeadTime: const Duration(minutes: 5),
      );
      addTearDown(container.dispose);

      final expectedId = ReminderStore.makeId(
        channelId: stream.streamId,
        startTime: epgEntry.startTime,
      );

      final reminder = await container.read(remindersProvider.notifier).add(
            channelId: stream.streamId,
            channelName: stream.name,
            programmeTitle: epgEntry.title,
            startTime: epgEntry.startTime,
            endTime: epgEntry.endTime,
          );
      expect(reminder.id, expectedId);

      final list = container.read(remindersProvider);
      expect(list, hasLength(1));
      expect(list.first.id, expectedId);
      expect(list.first.channelId, stream.streamId);
      expect(list.first.channelName, stream.name);
      expect(list.first.programmeTitle, epgEntry.title);
    });

    test(
        'remindersProvider.select(id-membership) flips true on add, false on remove',
        () async {
      // The V28 bell-icon display logic reads
      // `remindersProvider.select((list) => list.any((r) => r.id == id))`
      // — i.e. an id-membership predicate. This test is the
      // direct read of that predicate: false initially, true after
      // add, false again after remove. The id is computed from the
      // EpgProgrammeHit data (the V28 long-press handler's exact
      // computation).
      final container = await _makeContainer(
        liveStreams: [stream],
        epgByStreamId: {42: [epgEntry]},
        activeConnectionName: 'conn',
        initialLeadTime: const Duration(minutes: 5),
      );
      addTearDown(container.dispose);

      final id = ReminderStore.makeId(
        channelId: stream.streamId,
        startTime: epgEntry.startTime,
      );
      bool hasReminder() => container
          .read(remindersProvider.select((list) => list.any((r) => r.id == id)));

      expect(hasReminder(), isFalse, reason: 'no reminder scheduled yet');

      await container.read(remindersProvider.notifier).add(
            channelId: stream.streamId,
            channelName: stream.name,
            programmeTitle: epgEntry.title,
            startTime: epgEntry.startTime,
            endTime: epgEntry.endTime,
          );
      expect(hasReminder(), isTrue,
          reason: 'reminder just added — bell should be visible');

      await container.read(remindersProvider.notifier).remove(id);
      expect(hasReminder(), isFalse,
          reason: 'reminder removed — bell should hide');
    });

    test('two add() calls for the same (channelId, startTime) collapse to one',
        () async {
      // The V28 bell icon should appear after the FIRST add, not
      // after the second — proves `ReminderStore.makeId` is a pure
      // function of (channelId, startTime) so duplicate adds are
      // idempotent at the id level (the notifier's `add` updates
      // the same record in place; it doesn't create a duplicate).
      // The on-disk store would also dedupe by id, but the in-memory
      // notifier is the one the V28 `select` watches.
      final container = await _makeContainer(
        liveStreams: [stream],
        epgByStreamId: {42: [epgEntry]},
        activeConnectionName: 'conn',
        initialLeadTime: const Duration(minutes: 5),
      );
      addTearDown(container.dispose);

      final id = ReminderStore.makeId(
        channelId: stream.streamId,
        startTime: epgEntry.startTime,
      );
      bool hasReminder() => container
          .read(remindersProvider.select((list) => list.any((r) => r.id == id)));

      await container.read(remindersProvider.notifier).add(
            channelId: stream.streamId,
            channelName: stream.name,
            programmeTitle: epgEntry.title,
            startTime: epgEntry.startTime,
            endTime: epgEntry.endTime,
          );
      expect(hasReminder(), isTrue);

      // Second add for the same (channel, programme) — bell stays
      // visible, list size is 1.
      await container.read(remindersProvider.notifier).add(
            channelId: stream.streamId,
            channelName: stream.name,
            programmeTitle: epgEntry.title,
            startTime: epgEntry.startTime,
            endTime: epgEntry.endTime,
          );
      expect(hasReminder(), isTrue);
      expect(container.read(remindersProvider), hasLength(1));
    });

    test(
        'reminders are isolated per profile — conn-A\'s reminder does not surface for conn-B',
        () async {
      // The V07 reminders are keyed by `creds.name` (the profile
      // name) and persisted to SharedPreferences under that key. A
      // reminder added under conn-A must not surface in
      // `remindersProvider` for conn-B. This test mirrors the V18 /
      // V21 / V24 per-profile-isolation pattern: pre-seed a reminder
      // for conn-A directly into the on-disk store, then construct
      // a container whose active profile is conn-B and assert the
      // notifier's in-memory list is empty (i.e. the bell icon for
      // the same programme would NOT show under conn-B).
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final profileStore = ProfileStore(prefs);
      await profileStore.addProfile(name: 'conn-A');
      await profileStore.addProfile(name: 'conn-B');

      // Pre-seed a reminder for conn-A directly into the store.
      // Same `Reminder` shape that `RemindersNotifier.add` would
      // produce, so the on-disk record is indistinguishable from
      // one added via the notifier path.
      final reminderStore = ReminderStore(prefs);
      final id = ReminderStore.makeId(
        channelId: stream.streamId,
        startTime: epgEntry.startTime,
      );
      await reminderStore.add(
        Reminder(
          id: id,
          channelId: stream.streamId,
          channelName: stream.name,
          programmeTitle: epgEntry.title,
          startTime: epgEntry.startTime,
          endTime: epgEntry.endTime,
          leadTime: const Duration(minutes: 5),
          profileName: 'conn-A',
        ),
      );

      // Build a container whose active profile is conn-B — not
      // conn-A. The notifier's _load reads
      // `activeCredentialsProvider`, which resolves to conn-B's
      // credentials, so the in-memory list comes from
      // `reminderStore.activeForProfile('conn-B')` — which is
      // empty.
      final credsStore = _FakeCredentialsStore(activeName: 'conn-B');
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(profileStore),
          credentialsStoreProvider.overrideWithValue(credsStore),
          xtreamClientProvider.overrideWith(
            (ref) => _FakeXtreamClient(
              liveStreams: [stream],
              epgByStreamId: {42: [epgEntry]},
            ),
          ),
          defaultLeadTimeProvider.overrideWith((ref) => const Duration(minutes: 5)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(activeCredentialsProvider.future);

      // The on-disk store has conn-A's reminder — sanity check.
      expect(reminderStore.loadAll(), hasLength(1));

      // But the notifier, active under conn-B, sees no reminders.
      expect(container.read(remindersProvider), isEmpty,
          reason: 'conn-A\'s reminder must not surface under conn-B — '
              'bell hides on profile switch');
      expect(
        container.read(
          remindersProvider.select((list) => list.any((r) => r.id == id)),
        ),
        isFalse,
      );
    });

    test(
        'composes with V27 programmeTitleSearchProvider — add a reminder, re-run search, the hit is still matchable + the id is the same',
        () async {
      // The headline V28 behaviour: a user searches for a programme,
      // long-presses a hit to set a reminder, runs the same search
      // again — the hit still appears, AND the (channelId,
      // startTime) id computed from the V27 `EpgProgrammeHit` is
      // exactly the same as the one stored by `RemindersNotifier.add`.
      // This proves the V07 + V27 data layers compose correctly.
      final container = await _makeContainer(
        liveStreams: [stream],
        epgByStreamId: {42: [epgEntry]},
        activeConnectionName: 'conn',
        initialLeadTime: const Duration(minutes: 5),
      );
      addTearDown(container.dispose);

      // 1. Run the V27 search.
      final hits = await container.read(
        programmeTitleSearchProvider('match').future,
      );
      expect(hits, hasLength(1));
      final hit = hits.single;
      expect(hit.channel.streamId, 42);
      expect(hit.programme.title, 'Match of the Day');

      // 2. Long-press → set a reminder (the V28 path). The id is
      //    computed from `EpgProgrammeHit` data.
      final id = ReminderStore.makeId(
        channelId: hit.channel.streamId,
        startTime: hit.programme.startTime,
      );
      await container.read(remindersProvider.notifier).add(
            channelId: hit.channel.streamId,
            channelName: hit.channel.name,
            programmeTitle: hit.programme.title,
            startTime: hit.programme.startTime,
            endTime: hit.programme.endTime,
          );

      // 3. Re-run the V27 search — the same hit must still surface.
      final hitsAgain = await container.read(
        programmeTitleSearchProvider('match').future,
      );
      expect(hitsAgain, hasLength(1));
      final hitAgain = hitsAgain.single;
      expect(hitAgain.channel.streamId, 42);
      expect(hitAgain.programme.title, 'Match of the Day');

      // 4. The id computed from the V27 hit matches the id stored
      //    in `remindersProvider` — so the V28 bell icon and the EPG
      //    guide's badge (which use the same id) would both light up.
      final idAgain = ReminderStore.makeId(
        channelId: hitAgain.channel.streamId,
        startTime: hitAgain.programme.startTime,
      );
      expect(idAgain, id,
          reason:
              'V27 hit reshapes must produce the same id as V07\'s stored reminder');
      expect(
        container.read(
          remindersProvider.select((list) => list.any((r) => r.id == id)),
        ),
        isTrue,
      );
    });

    test('past programme is accepted by the notifier (the UI is the guard)',
        () async {
      // The V28 long-press handler gates on `now < programme.startTime`
      // — past programmes get the "Can't remind you about a
      // programme that's already started" snackbar and the handler
      // returns early. The `RemindersNotifier.add` data path itself
      // does NOT reject a past start time (it'd be over-restrictive
      // — the data layer shouldn't enforce a UI-level concern). This
      // test asserts the notifier's `add` returns a `Reminder` with
      // the requested fields, even when the start time is in the
      // past. The downstream `ReminderStore.activeForProfile`
      // filter (which drops past reminders from the in-memory list
      // — see ReminderStore.activeForProfile's `!r.isPast` clause)
      // is a separate concern from the V28 path; the bell icon's
      // `select` predicate just won't fire on a never-scheduled
      // programme, which is the desired behaviour. Mirrors the EPG
      // guide's handler-level guard / notifier-level non-guard
      // separation.
      final pastStart = DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 2));
      final pastEnd = pastStart.add(const Duration(minutes: 30));
      final pastEpg = _epg(
        start: pastStart.millisecondsSinceEpoch ~/ 1000,
        end: pastEnd.millisecondsSinceEpoch ~/ 1000,
        title: 'Already aired show',
      );

      final container = await _makeContainer(
        liveStreams: [stream],
        epgByStreamId: {42: [pastEpg]},
        activeConnectionName: 'conn',
        initialLeadTime: const Duration(minutes: 5),
      );
      addTearDown(container.dispose);

      final reminder = await container.read(remindersProvider.notifier).add(
            channelId: stream.streamId,
            channelName: stream.name,
            programmeTitle: pastEpg.title,
            startTime: pastEpg.startTime,
            endTime: pastEpg.endTime,
          );
      // The past start is stored as a unix-seconds value
      // (second precision), so the round-trip is truncated to the
      // second. Compare at second precision to avoid the 148ms
      // (or similar) drift between when the test computes
      // `pastStart` and when the EPG entry is built from it.
      expect(reminder.startTime.millisecondsSinceEpoch,
          (pastStart.millisecondsSinceEpoch ~/ 1000) * 1000);
      // The reminder is on disk, just hidden from the notifier's
      // in-memory list by the `activeForProfile` past-filter. The
      // on-disk record survives a fresh `loadAll` call:
      final reminderStore = container.read(reminderStoreProvider);
      expect(reminderStore.loadAll(), hasLength(1),
          reason: 'data layer persists past reminders; the UI is the guard');
    });
  });
}
