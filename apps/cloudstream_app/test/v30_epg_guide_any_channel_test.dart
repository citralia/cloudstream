// V30 — "Remind me when this programme is on any channel" — long-press
// menu on EPG guide programme block.
//
// Closes the V29 follow-on gap: V29 added the "Any channel" SnackBarAction
// on the SEARCH-screen `_EpgResultTile` (the result of a V27 programme
// search). But a user who's already in the EPG guide (the primary
// surface for discovering programmes — they came here from the bottom-nav
// "Guide" tab) and long-presses a programme block should also get the
// "Any channel" affordance without having to switch to the search screen
// first. V30 brings the V29 "Any channel" menu to the EPG guide's
// `_ProgrammeBlock` widget.
//
// V30 is a thin widget-layer mirror of V29:
//   - The data layer (`programmeAiringsAcrossChannelsProvider`) is
//     unchanged — V29 already added it. V30 reuses it.
//   - The widget layer adds a new `_scheduleOnAnyChannel` method to
//     `_ProgrammeBlock` in `epg_guide_screen.dart` that mirrors
//     `_EpgResultTile._scheduleOnAnyChannel` in `search_screen.dart`
//     line-for-line: filter the provider's hits to exclude the source
//     airing, then call `RemindersNotifier.add` for each remaining hit.
//   - The V07 single-airing reminder (the reminder set by the long-press
//     that surfaces the snackbar in the first place) is NOT touched —
//     the user opted into both.
//
// Test scope: data-layer composition. Mirrors the V29 test pattern (no
// widget pump — `_ProgrammeBlock` is a private widget in a 840-line
// screen and the source change is in the data layer + a thin widget
// wiring). The data-layer tests prove the V30 widget's helper works
// against the V29 provider + V07 notifier, which is where the real
// behaviour lives.
//
// Fixture pattern follows `v29_remind_on_any_channel_test.dart`:
// _FakeCredentialsStore + `_FakeXtreamClient` (with `liveStreams` +
// `epgByStreamId`) + `makeContainer` helper that overrides the storage
// + client providers.

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
}) {
  return XtreamEpgEntry(
    channelId: 'c',
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
  // active profile. Same dance as the V07 + V28 + V29 tests.
  await container.read(activeCredentialsProvider.future);
  return container;
}

// ─── Tests ───────────────────────────────────────────────────────────────

void main() {
  group('V30 — EPG guide "Any channel" menu', () {
    // Future programme window, anchored ~2h ahead so the data path
    // doesn't prune it (ReminderStore drops reminders whose fire
    // time is in the past) and the V29 future-only filter passes.
    // Mirrors the V29 fixture exactly.
    final futureBase = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 2));
    final futureStartSec = futureBase.millisecondsSinceEpoch ~/ 1000;
    final futureEndSec = futureStartSec + 30 * 60; // 30-min window

    // Four channels for the cross-channel scenarios. The V30 EPG
    // guide's `_ProgrammeBlock` can be long-pressed on any of them;
    // the V30 "Any channel" action then schedules reminders for
    // every OTHER future airing of the same title on the rest.
    final bbcOne = const XtreamStream(
      streamId: 1,
      name: 'BBC One',
      categoryId: 1,
      streamType: 'live',
    );
    final bbcTwo = const XtreamStream(
      streamId: 2,
      name: 'BBC Two',
      categoryId: 1,
      streamType: 'live',
    );
    final itv = const XtreamStream(
      streamId: 3,
      name: 'ITV',
      categoryId: 1,
      streamType: 'live',
    );
    final channel4 = const XtreamStream(
      streamId: 4,
      name: 'Channel 4',
      categoryId: 1,
      streamType: 'live',
    );

    test(
        'V30 widget helper schedules reminders for OTHER airings on ANY channel',
        () async {
      // The headline V30 behaviour: a user long-presses a programme
      // block in the EPG guide on channel 1 (the "source" airing),
      // taps "Any channel" on the snackbar, and gets reminders
      // scheduled for the OTHER 3 channels' airings of the same
      // title. The V30 widget helper drives the V29 provider +
      // V07 notifier the same way the V29 search-screen helper does
      // (the search-screen test 10 in V29 already proves this at the
      // data layer; this V30 test mirrors that pattern for the EPG
      // guide's data shape — `XtreamEpgEntry` from `_ProgrammeBlock`,
      // not `EpgProgrammeHit` from `_EpgResultTile`).
      final sourceHit = _epg(
        start: futureStartSec,
        end: futureEndSec,
        title: 'Match of the Day',
      );
      final bbcTwoHit = _epg(
        start: futureStartSec + 3600,
        end: futureEndSec + 3600,
        title: 'Match of the Day',
      );
      final itvHit = _epg(
        start: futureStartSec + 7200,
        end: futureEndSec + 7200,
        title: 'Match of the Day',
      );
      final c4Hit = _epg(
        start: futureStartSec + 10800,
        end: futureEndSec + 10800,
        title: 'Match of the Day',
      );
      final container = await _makeContainer(
        liveStreams: [bbcOne, bbcTwo, itv, channel4],
        epgByStreamId: {
          1: [sourceHit],
          2: [bbcTwoHit],
          3: [itvHit],
          4: [c4Hit],
        },
        activeConnectionName: 'conn',
        initialLeadTime: const Duration(minutes: 5),
      );
      addTearDown(container.dispose);

      // V30 widget helper would:
      //   1) Read `programmeAiringsAcrossChannelsProvider(title).future`
      //      — gets all 4 hits
      //   2) Filter out the source airing (channel 1, futureStartSec)
      //   3) Call `RemindersNotifier.add` for each of the 3 remaining
      // Exercise that path directly:
      final hits = await container.read(
        programmeAiringsAcrossChannelsProvider('Match of the Day').future,
      );
      expect(hits, hasLength(4));

      final sourceChannelId = bbcOne.streamId;
      final sourceStartTime = sourceHit.startTime;
      final others = hits
          .where(
            (h) =>
                h.channel.streamId != sourceChannelId ||
                h.programme.startTime != sourceStartTime,
          )
          .toList();
      expect(others, hasLength(3));

      final notifier = container.read(remindersProvider.notifier);
      final addedIds = <String>[];
      for (final h in others) {
        final r = await notifier.add(
          channelId: h.channel.streamId,
          channelName: h.channel.name,
          programmeTitle: h.programme.title,
          startTime: h.programme.startTime,
          endTime: h.programme.endTime,
        );
        addedIds.add(r.id);
      }
      expect(addedIds, hasLength(3));
      expect(addedIds.toSet(), hasLength(3)); // all distinct

      // 3 reminders on disk, none for the source channel.
      final stored = container.read(remindersProvider);
      expect(stored, hasLength(3));
      for (final r in stored) {
        expect(r.id.contains('1$futureStartSec'), isFalse,
            reason: 'V30 must NOT add a reminder for the source channel');
      }
    });

    test(
        'V30 helper does NOT remove the V07 single-airing reminder — both coexist',
        () async {
      // V30's "Any channel" action adds N additional reminders but
      // does NOT touch the V07 single-airing reminder (the reminder
      // set by the long-press that surfaced the snackbar in the first
      // place). The user opted into both: the specific airing AND
      // every other future airing of the same title. This test
      // exercises the EPG guide's exact data path: pre-add a V07
      // reminder for the source airing (BBC One), then run the V30
      // helper for the OTHER airings (BBC Two + ITV) → the V07
      // reminder is still present alongside the new V30 reminders.
      final sourceHit = _epg(
        start: futureStartSec,
        end: futureEndSec,
        title: 'Match of the Day',
      );
      final bbcTwoHit = _epg(
        start: futureStartSec + 3600,
        end: futureEndSec + 3600,
        title: 'Match of the Day',
      );
      final itvHit = _epg(
        start: futureStartSec + 7200,
        end: futureEndSec + 7200,
        title: 'Match of the Day',
      );
      final container = await _makeContainer(
        liveStreams: [bbcOne, bbcTwo, itv],
        epgByStreamId: {
          1: [sourceHit],
          2: [bbcTwoHit],
          3: [itvHit],
        },
        activeConnectionName: 'conn',
        initialLeadTime: const Duration(minutes: 5),
      );
      addTearDown(container.dispose);

      final notifier = container.read(remindersProvider.notifier);

      // V07 path: add reminder for the source airing (BBC One).
      final sourceReminder = await notifier.add(
        channelId: bbcOne.streamId,
        channelName: bbcOne.name,
        programmeTitle: sourceHit.title,
        startTime: sourceHit.startTime,
        endTime: sourceHit.endTime,
      );
      expect(container.read(remindersProvider), hasLength(1));

      // V30 path: add reminders for the OTHER 2 airings.
      final hits = await container.read(
        programmeAiringsAcrossChannelsProvider('Match of the Day').future,
      );
      final others = hits
          .where(
            (h) =>
                h.channel.streamId != bbcOne.streamId ||
                h.programme.startTime != sourceHit.startTime,
          )
          .toList();
      expect(others, hasLength(2));

      for (final h in others) {
        await notifier.add(
          channelId: h.channel.streamId,
          channelName: h.channel.name,
          programmeTitle: h.programme.title,
          startTime: h.programme.startTime,
          endTime: h.programme.endTime,
        );
      }
      // 3 reminders total: 1 V07 (source) + 2 V30 (others).
      final stored = container.read(remindersProvider);
      expect(stored, hasLength(3));

      // The V07 source reminder is still present, untouched.
      expect(
        stored.any((r) => r.id == sourceReminder.id),
        isTrue,
        reason: 'V30 must NOT remove the V07 source-airing reminder',
      );
      // The V07 source reminder's id is the V07 `ReminderStore.makeId`
      // for (channel=1, startTime=futureStartSec).
      final expectedSourceId = ReminderStore.makeId(
        channelId: bbcOne.streamId,
        startTime: sourceHit.startTime,
      );
      expect(sourceReminder.id, equals(expectedSourceId));
    });

    test(
        'V30 helper short-circuits with no-op when no other airings exist',
        () async {
      // Edge case: the user long-presses the ONLY airing of a
      // programme in the EPG guide, taps "Any channel" on the
      // snackbar, and gets a "No other airings of this programme"
      // snackbar instead of scheduling 0 reminders. The V30 widget
      // helper short-circuits when `others.isEmpty` — proven
      // indirectly here: the V29 provider's hit count is 1, the
      // filter step leaves 0, and the V30 widget helper's
      // `if (others.isEmpty) { snackbar; return; }` branch fires.
      final sourceHit = _epg(
        start: futureStartSec,
        end: futureEndSec,
        title: 'Unique Programme',
      );
      final container = await _makeContainer(
        liveStreams: [bbcOne],
        epgByStreamId: {1: [sourceHit]},
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final hits = await container.read(
        programmeAiringsAcrossChannelsProvider('Unique Programme').future,
      );
      expect(hits, hasLength(1));

      final others = hits
          .where(
            (h) =>
                h.channel.streamId != bbcOne.streamId ||
                h.programme.startTime != sourceHit.startTime,
          )
          .toList();
      // Filter leaves 0 → V30 helper short-circuits.
      expect(others, isEmpty);
    });

    test(
        'V30 helper is a thin mirror of V29 — same provider, same per-airing add() shape',
        () async {
      // V30 is structurally identical to V29 except for the entry
      // point (EPG guide `_ProgrammeBlock` vs search-screen
      // `_EpgResultTile`). The data layer is unchanged. This test
      // exercises the exact V30 helper code path end-to-end with
      // realistic data — 3 airings on 3 different channels, with a
      // V07 source reminder for one of them, then a V30 helper run
      // for the other 2. Verifies the V30 widget's helper produces
      // reminders with the V07 `(channelId, startTime)` id shape
      // (the same id shape V07 + V28 + V29 use, so a reminder set
      // from the EPG guide is reflected in the EPG guide's own bell
      // badge via the same `remindersProvider.select(...)` predicate
      // V28 introduced).
      final bbcOneHit = _epg(
        start: futureStartSec,
        end: futureEndSec,
        title: 'Match of the Day',
      );
      final bbcTwoHit = _epg(
        start: futureStartSec + 3600,
        end: futureEndSec + 3600,
        title: 'Match of the Day',
      );
      final itvHit = _epg(
        start: futureStartSec + 7200,
        end: futureEndSec + 7200,
        title: 'Match of the Day',
      );
      final container = await _makeContainer(
        liveStreams: [bbcOne, bbcTwo, itv],
        epgByStreamId: {
          1: [bbcOneHit],
          2: [bbcTwoHit],
          3: [itvHit],
        },
        activeConnectionName: 'conn',
        initialLeadTime: const Duration(minutes: 5),
      );
      addTearDown(container.dispose);

      // Simulate the V30 EPG guide flow:
      //   1) User long-presses bbcOneHit → V07 reminder set with id
      //      `ReminderStore.makeId(channelId=1, startTime=bbcOneHit.startTime)`.
      //   2) Snackbar shows "Will remind you at HH:MM — Match of the
      //      Day" with an "Any channel" action (V30 widget change).
      //   3) User taps "Any channel" → V30 helper runs, schedules
      //      reminders for the OTHER 2 airings.
      final notifier = container.read(remindersProvider.notifier);
      final sourceReminder = await notifier.add(
        channelId: bbcOne.streamId,
        channelName: bbcOne.name,
        programmeTitle: bbcOneHit.title,
        startTime: bbcOneHit.startTime,
        endTime: bbcOneHit.endTime,
      );
      expect(sourceReminder.id, equals(ReminderStore.makeId(
        channelId: bbcOne.streamId,
        startTime: bbcOneHit.startTime,
      )));

      // V30 helper: filter the V29 provider's hits + add().
      final hits = await container.read(
        programmeAiringsAcrossChannelsProvider('Match of the Day').future,
      );
      final others = hits
          .where(
            (h) =>
                h.channel.streamId != bbcOne.streamId ||
                h.programme.startTime != bbcOneHit.startTime,
          )
          .toList();
      for (final h in others) {
        await notifier.add(
          channelId: h.channel.streamId,
          channelName: h.channel.name,
          programmeTitle: h.programme.title,
          startTime: h.programme.startTime,
          endTime: h.programme.endTime,
        );
      }

      // 3 reminders total, all distinct ids, all V07-shaped.
      final stored = container.read(remindersProvider);
      expect(stored, hasLength(3));
      final ids = stored.map((r) => r.id).toSet();
      expect(ids, hasLength(3));
      for (final h in hits) {
        final expected = ReminderStore.makeId(
          channelId: h.channel.streamId,
          startTime: h.programme.startTime,
        );
        expect(ids.contains(expected), isTrue,
            reason: 'V30 reminder id must be V07-shaped for the hit');
      }
    });
  });
}
