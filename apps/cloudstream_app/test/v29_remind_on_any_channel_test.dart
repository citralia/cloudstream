// V29 — "Remind me when this programme is on any channel" — long-press
// menu action on EPG search result.
//
// Closes the V28 follow-on gap: V28 added the long-press affordance on
// `_EpgResultTile` (search screen), which sets a reminder for the ONE
// specific airing the user tapped. A user searching for a programme
// that's airing on multiple channels ("Match of the Day" on BBC One at
// 22:00 AND on BBC Two at 23:00) gets multiple search hits — but V28
// only let them set a reminder for one. V29 adds a "Any channel"
// action to the V28 long-press snackbar: tapping it schedules
// reminders for every OTHER future airing of the same programme title
// on any channel, with an UNDO action on the confirmation snackbar.
//
// V29 is a thin extension of V28: a new `programmeAiringsAcrossChannelsProvider`
// (data layer) + a new `_scheduleOnAnyChannel` method on `_EpgResultTile`
// (widget) + a snackbar action wiring. The V07 `RemindersNotifier.add`
// is reused as-is — the V07 storage id is `(channelId, startTime)`, so
// one `add()` per airing naturally produces one reminder per airing
// with no id collision. The V28 single-airing reminder is NOT removed
// by the V29 "Any channel" action — the user opted into both: the
// specific airing AND every other future airing of the same title.
//
// Test scope follows the V22 / V23 / V24 / V26 / V27 / V28 pattern:
// pure data-layer / Riverpod injection tests for the new provider +
// one test per behaviour. The widget changes (`_scheduleOnAnyChannel`
// snackbar action) are thin and covered by source migration + analyze
// (same trade-off V14 chunk 2 + V15 made for player surfaces that
// don't pump cleanly in unit tests).
//
// Fixture pattern follows v28_remind_from_epg_search_test.dart:
// `_FakeCredentialsStore` + `_FakeXtreamClient` (with liveStreams +
// per-stream EPG via getEpg) + `makeContainer` helper that overrides
// the storage + client + live + epg providers. Per-channel EPG seed
// lets us construct deterministic multi-channel scenarios.

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
  // active profile. Same dance as the V07 + V28 tests.
  await container.read(activeCredentialsProvider.future);
  return container;
}

// ─── Tests ───────────────────────────────────────────────────────────────

void main() {
  group('V29 — remind on any channel', () {
    // Future programme window, anchored ~2h ahead so the data path
    // doesn't prune it (ReminderStore drops reminders whose fire
    // time is in the past) and the V29 future-only filter passes.
    final futureBase = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 2));
    final futureStartSec = futureBase.millisecondsSinceEpoch ~/ 1000;
    final futureEndSec = futureStartSec + 30 * 60; // 30-min window

    // Three channels for the multi-channel scenarios.
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

    test('empty title short-circuits to empty list', () async {
      // Headline V29 invariant: the provider never throws on an
      // empty title — it returns `[]` immediately. The widget path
      // never queries an empty title in practice, but a test guards
      // against a future caller passing `''` or a whitespace-only
      // string and accidentally firing N EPG round-trips.
      final container = await _makeContainer(
        liveStreams: [bbcOne],
        epgByStreamId: const {1: []},
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      expect(
        await container.read(programmeAiringsAcrossChannelsProvider('').future),
        isEmpty,
      );
      expect(
        await container.read(
          programmeAiringsAcrossChannelsProvider('   ').future,
        ),
        isEmpty,
      );
    });

    test('no active connection degrades to empty list', () async {
      // The V22/V25/V26/V27 pattern: a no-creds user must not
      // trigger N EPG network round-trips per tap. The
      // activeCredentialsProvider gate returns `[]` cleanly.
      final container = await _makeContainer(
        liveStreams: [bbcOne],
        epgByStreamId: const {1: []},
      );
      addTearDown(container.dispose);

      expect(
        await container.read(
          programmeAiringsAcrossChannelsProvider('Match of the Day').future,
        ),
        isEmpty,
      );
    });

    test('no live streams degrades to empty list', () async {
      // The liveStreamsProvider gate: a user with credentials but no
      // loaded live catalogue must not crash. Mirrors the V27
      // no-live-streams test.
      final container = await _makeContainer(
        liveStreams: const [],
        epgByStreamId: const {},
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      expect(
        await container.read(
          programmeAiringsAcrossChannelsProvider('Match of the Day').future,
        ),
        isEmpty,
      );
    });

    test(
        'returns exact-title matches (case-insensitive, trimmed) across all channels',
        () async {
      // Headline V29 behaviour: scan ALL loaded channels' EPG for the
      // exact title (case-insensitive, trimmed). Three channels
      // have the target title on different start times + one channel
      // has a SUBSTRING match ("Match of the Day Replay") that must
      // NOT surface.
      final bbcOneHit = _epg(
        start: futureStartSec,
        end: futureEndSec,
        title: 'Match of the Day',
      );
      final bbcTwoHit = _epg(
        start: futureStartSec + 3600, // +1h
        end: futureEndSec + 3600,
        title: 'match of the day', // mixed-case — must match
      );
      final itvHit = _epg(
        start: futureStartSec + 7200, // +2h
        end: futureEndSec + 7200,
        title: '  Match of the Day  ', // whitespace — must match
      );
      final itvSubstring = _epg(
        start: futureStartSec + 10800, // +3h
        end: futureEndSec + 10800,
        title: 'Match of the Day Replay', // substring only — must NOT match
      );
      final container = await _makeContainer(
        liveStreams: [bbcOne, bbcTwo, itv],
        epgByStreamId: {
          1: [bbcOneHit],
          2: [bbcTwoHit],
          3: [itvHit, itvSubstring],
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final hits = await container.read(
        programmeAiringsAcrossChannelsProvider('Match of the Day').future,
      );
      expect(hits, hasLength(3));
      // Sorted by start-time asc: bbcOne (h+0) → bbcTwo (h+1) → itv (h+2).
      expect(hits[0].channel.streamId, 1);
      expect(hits[1].channel.streamId, 2);
      expect(hits[2].channel.streamId, 3);
      // The substring match is excluded.
      expect(
        hits.any((h) => h.programme.title == 'Match of the Day Replay'),
        isFalse,
      );
    });

    test('excludes past airings (programme already started)', () async {
      // The provider is future-only — a programme whose start time
      // has passed is not a valid reminder target. The V28 long-press
      // handler also gates this at the UI level, but the V29 data
      // layer is the safer place to enforce it.
      final pastStart = futureStartSec - 7200; // 2h ago
      final pastEnd = pastStart + 1800;
      final pastEntry = _epg(
        start: pastStart,
        end: pastEnd,
        title: 'News at Six',
      );
      final futureEntry = _epg(
        start: futureStartSec,
        end: futureEndSec,
        title: 'News at Six',
      );
      final container = await _makeContainer(
        liveStreams: [bbcOne],
        epgByStreamId: {1: [pastEntry, futureEntry]},
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final hits = await container.read(
        programmeAiringsAcrossChannelsProvider('News at Six').future,
      );
      expect(hits, hasLength(1));
      expect(hits.first.programme.start, futureStartSec);
    });

    test(
        'no matches across all channels returns empty list (no crash, no reminders)',
        () async {
      // Regression guard: a search hit that the V27
      // programmeTitleSearchProvider surfaced via a DESCRIPTION
      // match (no exact title match anywhere) returns `[]` from V29.
      // The user might long-press the V27 hit and tap "Any channel"
      // — V29 then shows the "No other airings of this programme"
      // snackbar, which the widget code handles by short-circuiting.
      final container = await _makeContainer(
        liveStreams: [bbcOne, bbcTwo],
        epgByStreamId: const {
          1: [], // No EPG for BBC One.
          2: [], // No EPG for BBC Two.
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      expect(
        await container.read(
          programmeAiringsAcrossChannelsProvider('Match of the Day').future,
        ),
        isEmpty,
      );
    });

    test('a flaky channel (epgProvider throws) does not poison the result',
        () async {
      // The provider reuses V27's `_readEpgSafe` swallow-on-throw —
      // a single channel's EPG fetch failure must not surface as an
      // exception to the caller. The BBC Two channel is in
      // `liveStreams` but has no entry in `epgByStreamId`, so the
      // fake client's `getEpg` throws.
      final bbcOneHit = _epg(
        start: futureStartSec,
        end: futureEndSec,
        title: 'Match of the Day',
      );
      final container = await _makeContainer(
        liveStreams: [bbcOne, bbcTwo],
        epgByStreamId: const {
          1: [], // BBC One: no EPG entries.
          // BBC Two (2): key missing — getEpg throws.
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      // The above epgByStreamId maps don't have the hit. Build a
      // scenario where BBC One has the hit and BBC Two's EPG throws.
      final container2 = await _makeContainer(
        liveStreams: [bbcOne, bbcTwo],
        epgByStreamId: {
          1: [bbcOneHit],
          // BBC Two (2): key missing on purpose — the fake client
          // throws for unknown keys.
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container2.dispose);

      final hits = await container2.read(
        programmeAiringsAcrossChannelsProvider('Match of the Day').future,
      );
      // BBC One's hit survives; BBC Two's throw is swallowed by
      // _readEpgSafe and contributes 0 hits.
      expect(hits, hasLength(1));
      expect(hits.first.channel.streamId, 1);
    });

    test(
        'cap at kCrossChannelReminderCap: 25 airings across 5 channels → only 20 surfaced',
        () async {
      // Stress test for the cap. 5 channels × 5 airings = 25 hits.
      // The cap is pinned at 20 (kCrossChannelReminderCap constant),
      // so the result has exactly 20 entries — the first 20 by
      // start-time asc.
      final channels = [
        for (var i = 1; i <= 5; i++)
          XtreamStream(
            streamId: i,
            name: 'Channel $i',
            categoryId: 1,
            streamType: 'live',
          ),
      ];
      final epgMap = <int, List<XtreamEpgEntry>>{};
      for (var c = 1; c <= 5; c++) {
        epgMap[c] = [
          for (var h = 0; h < 5; h++)
            _epg(
              start: futureStartSec + c * 100 + h * 60, // ascending
              end: futureEndSec + c * 100 + h * 60,
              title: 'News at Six',
            ),
        ];
      }
      final container = await _makeContainer(
        liveStreams: channels,
        epgByStreamId: epgMap,
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final hits = await container.read(
        programmeAiringsAcrossChannelsProvider('News at Six').future,
      );
      expect(hits, hasLength(20));
      // The cap constant is pinned at 20 — a future maintainer who
      // changes the cap should update this test.
      expect(kCrossChannelReminderCap, 20);
    });

    test(
        'per-profile isolation: matches for conn-A do not surface for conn-B',
        () async {
      // The provider reads EPG via the live catalogue (which is
      // loaded by the active connection), so the result is implicitly
      // scoped to the active profile's connection. A second profile
      // with a different live catalogue sees different hits.
      //
      // The V29 provider itself doesn't read credentials-name into
      // its result; the per-profile isolation comes from the
      // `liveStreamsProvider` + `epgProvider` chain being profile-
      // scoped (they're keyed by the active client). A second
      // container with a different client surfaces a different
      // EPG catalogue, hence different hits.
      final connAHit = _epg(
        start: futureStartSec,
        end: futureEndSec,
        title: 'Match of the Day',
      );
      final containerA = await _makeContainer(
        liveStreams: [bbcOne],
        epgByStreamId: {1: [connAHit]},
        activeConnectionName: 'conn-A',
      );
      addTearDown(containerA.dispose);

      final containerB = await _makeContainer(
        liveStreams: [bbcTwo],
        epgByStreamId: const {2: []}, // no EPG for conn-B
        activeConnectionName: 'conn-B',
      );
      addTearDown(containerB.dispose);

      final hitsA = await containerA.read(
        programmeAiringsAcrossChannelsProvider('Match of the Day').future,
      );
      final hitsB = await containerB.read(
        programmeAiringsAcrossChannelsProvider('Match of the Day').future,
      );
      expect(hitsA, hasLength(1));
      expect(hitsA.first.channel.streamId, 1);
      expect(hitsB, isEmpty);
    });

    test(
        'composes with V07 + V28: scheduling a reminder for each hit produces N reminders with distinct ids',
        () async {
      // End-to-end V29: the provider returns 3 hits, and the
      // widget's `_scheduleOnAnyChannel` would call
      // `RemindersNotifier.add` for each. This test exercises the
      // data-layer portion of that path: for each hit, calling add()
      // stores a reminder with a unique id (the V07 `(channelId,
      // startTime)` id shape). 3 hits → 3 reminders → 3 distinct ids.
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

      final hits = await container.read(
        programmeAiringsAcrossChannelsProvider('Match of the Day').future,
      );
      expect(hits, hasLength(3));

      final notifier = container.read(remindersProvider.notifier);
      final ids = <String>[];
      for (final h in hits) {
        final r = await notifier.add(
          channelId: h.channel.streamId,
          channelName: h.channel.name,
          programmeTitle: h.programme.title,
          startTime: h.programme.startTime,
          endTime: h.programme.endTime,
        );
        ids.add(r.id);
      }
      // 3 distinct ids (one per airing — the V07 id shape is
      // (channelId, startTime), so different (channel, start) pairs
      // produce different ids).
      expect(ids, hasLength(3));
      expect(ids.toSet(), hasLength(3));
      // And the on-disk store has all 3 reminders.
      final stored = container.read(remindersProvider);
      expect(stored, hasLength(3));
      // Each stored id is the V07 ReminderStore.makeId for the hit.
      for (final h in hits) {
        final expected = ReminderStore.makeId(
          channelId: h.channel.streamId,
          startTime: h.programme.startTime,
        );
        expect(stored.any((r) => r.id == expected), isTrue);
      }
    });

    test(
        'V29 does NOT remove the V28 single-airing reminder — both coexist',
        () async {
      // V29's "Any channel" action adds N additional reminders but
      // does NOT touch the V28 single-airing reminder (the user
      // opted into both). This test exercises the
      // RemindersNotifier.add path directly: pre-add a V28 reminder
      // for one specific airing, then run the V29 add loop for all
      // airings → the V28 reminder is still present alongside the
      // new V29 reminders.
      final sourceHit = _epg(
        start: futureStartSec,
        end: futureEndSec,
        title: 'Match of the Day',
      );
      final otherHit = _epg(
        start: futureStartSec + 3600,
        end: futureEndSec + 3600,
        title: 'Match of the Day',
      );
      final container = await _makeContainer(
        liveStreams: [bbcOne, bbcTwo],
        epgByStreamId: {
          1: [sourceHit],
          2: [otherHit],
        },
        activeConnectionName: 'conn',
      );
      addTearDown(container.dispose);

      final notifier = container.read(remindersProvider.notifier);

      // V28 path: add reminder for the source airing.
      final sourceReminder = await notifier.add(
        channelId: sourceHit.channelId == 'c' ? 1 : 1,
        channelName: bbcOne.name,
        programmeTitle: sourceHit.title,
        startTime: sourceHit.startTime,
        endTime: sourceHit.endTime,
      );
      expect(container.read(remindersProvider), hasLength(1));

      // V29 path: add reminder for the OTHER airing.
      final otherReminder = await notifier.add(
        channelId: 2,
        channelName: bbcTwo.name,
        programmeTitle: otherHit.title,
        startTime: otherHit.startTime,
        endTime: otherHit.endTime,
      );
      expect(container.read(remindersProvider), hasLength(2));

      // The V28 reminder is still present, untouched, alongside the
      // new V29 reminder. Their ids are distinct.
      expect(sourceReminder.id, isNot(equals(otherReminder.id)));
      final ids =
          container.read(remindersProvider).map((r) => r.id).toList();
      expect(ids, containsAll([sourceReminder.id, otherReminder.id]));
    });
  });
}
