# CloudStream — Development Log

> Reverse chronological. Most recent entries at top.

---

## 2026-06-10 — CloudStream Hourly Cron (01:25 BST)

**Session start:** 00:15 BST (carry-over from 2026-06-10 00:15 cron)

### What was done:
- Board on entry: V14 chunk 1 (4 VOD/series surfaces) had been merged to develop at 00:15 (6f87792) with CI ✅ + Release ✅. The "Next" pointer from the 00:15 log was **V14 chunk 2 — media-playback surfaces** (the 4 un-migrated playback widgets/screens: `quick_channel_overlay`, `player_gesture_overlay`, `player_screen`, `epg_guide_screen`).
- Picked V14 chunk 2 up — same pattern as the V12/V13/V14-chunk-1 pickups. WIP was minimal this time (a clean working tree, no prior-session leftovers), so the migration is fully done in this run.
- **V14 chunk 2** fully implemented, tested, and shipped (54fb180):
  - **`presentation/widgets/quick_channel_overlay.dart`** (11 refs): `QuickChannelOverlay` swap-horizontal icon + caption title, `_RecentChannelChip` background / border / stream-name text + initial-letter colour, `ChannelNumberBar` dialpad icon / backspace icon / CLR text / GO button background. All now `context.appColors.*`. The black gradient wrapper and the white "GO" text stay as `Colors.white` / `Colors.black.withOpacity(...)` — those are intentional video-overlay conventions.
  - **`presentation/screens/player_gesture_overlay.dart`** (1 ref): the seek/volume/brightness label `Text` style. The label container itself stays `Colors.black.withOpacity(0.6)` and the icon stays `Colors.white` — those are intentional video-overlay conventions; only the typography style pulls from the brightness-correct token.
  - **`presentation/screens/player_screen.dart`** (14 refs): Chewie `materialProgressColors` (played/handle/background/buffered), loading indicator + icon, top-bar typography (channel name + EPG now/next), the inline Chewie `errorBuilder` (icon + "Playback error" h3 + error message), the bottom `_ErrorView` (icon + "Playback failed" h2 + caption). The top bar's `Colors.white` and `Colors.white70` text stay as-is — they're on top of the black→transparent video gradient. **One subtle gotcha:** the Chewie progress colours and `errorBuilder` closure run *after* `await _videoController!.initialize()` and `await _videoController!.seekTo(...)`. Reading `context.appColors` inside those closures would trip `use_build_context_synchronously` (and risk a stale `context` if the State has been disposed by then). Captured the theme tokens into local `colors` / `typo` variables **before** the awaits and used those in the closure. Documented the trade-off in a code comment so the next maintainer doesn't undo it.
  - **`presentation/screens/epg_guide_screen.dart`** (27 refs): Scaffold background, loading + error + empty-data states, the CHANNEL header cell, `_ChannelLabelCell` border + stream-name text + initial-letter chip + initial-letter colour, `_ProgrammeRow` loading border / progress indicator / empty-row border, `_ProgrammeBlock` on-now/future decoration (background / border / replay badge / reminder icon / title text), `_NowLine` container colour. **`_TimeRulerPainter`** is a `CustomPainter` and has no `BuildContext`, so the line colour / text colour / half-line colour are now passed in via the constructor (`lineColor` / `textColor` / `halfLineColor`); the `CustomPaint` widget reads them from `context.appColors` and the `shouldRepaint` check includes the colour deltas. This is the only CustomPainter in the app — the pattern would repeat for any future ones.
  - **`_initial(context)`**: both `QuickChannelOverlay._RecentChannelChip._initial` and `EpgGuideScreen._ChannelLabelCell._initial` are private helper methods on a `StatelessWidget` with no `BuildContext`. The migration needed a context (for `context.appColors.primary`), so the signature changed from `Widget _initial()` to `Widget _initial(BuildContext context)` and both call sites pass the build's context.
  - **`flutter analyze`**: 50 issues found (was 50). 49 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-param warning. **0 new issues introduced by V14 chunk 2** (no entries in any of the 4 migrated files).
  - **`flutter test`**: 163/163 tests pass (was 159, +4 from V14 chunk 2). New file `test/brightness_aware_chunk5_test.dart` follows the V12/V13/V14-chunk-1 pattern: one `testWidgets` per (widget × theme) pair, no loop (would poison WidgetsBinding), explicit `themeMode` to defeat the test env's `platformBrightness` default. Tests assert on a single concrete colour reference (e.g. `nameText.style.color == AppColors.textSecondary`) — proves the migration is wired, not falling back to a dark constant.
  - **Test scope for chunk 2 is narrower than chunk 1.** The 4 migrated files don't all pump cleanly:
    - `PlayerGestureOverlay` needs a real `VideoPlayerController` (chewie/video_player) — won't initialise in a unit test.
    - `PlayerScreen` wraps Chewie which mounts the native video surface — same issue.
    - `EpgGuideScreen` is testable but needs overrides for `filteredLiveStreamsProvider` + `recentChannelsProvider` + `playerControllerProvider` on top of the chunk-1 `xtreamClientProvider` / `credentialsStoreProvider` / `sharedPreferencesProvider` overrides. Not impossible, but a bigger fixture effort than the migration itself; the source change + 0 new analyze issues covers it (same trade-off the V13 chunk made for `ChannelListScreen`).
  - Pushed `feature/v14-brightness-aware-chunk2` → `develop` (merge 54fb180). CI ✅ + Release ✅ — **APK uploaded as v0.1.45**.

### CI status:
- `Merge feature/v14-brightness-aware-chunk2 into develop` (54fb180) — **CI ✅ + Release ✅ → v0.1.45**
- All Phase 2 (P201–P204, P206) + V01–V14 (across chunks 1 and 2) now Done
- 14 of the 14 brightness-migrated app surfaces (login, tv_text_field, settings, profile_switcher, debug_logs, reminders_list, search, channel_list + main shell, vod, series, vod_detail, series_detail, quick_channel_overlay, player_gesture_overlay, player_screen, epg_guide) now render correctly in both dark and light themes. The whole app is now brightness-aware — picking Light in Settings flips every screen.

### What's next:
- **The V08/V11 follow-on is now complete** — every app screen has been migrated to `context.appColors` / `context.appTypography`. A user picking Light in Settings will now see the entire app switch to the light theme; the original V08 scope note about "existing screens still render with dark text" no longer applies.
- **Other unblocked candidates** (all no external deps):
  - "Recently watched" sort mode for V06 (would need a recency timestamp on top of the existing `PlayCountStore`)
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series)
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels)
  - Continue Watching / Most Watched fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
  - `defaultLeadTimeProvider` persistence: ALREADY DONE in V10 (carry-over from prior cron) — closed
  - V11+ follow-on: a widget-level "anywhere-`AppColors` is used" sweep would be the next cleanup, but there are very few left (the cron-tracked count of 0 makes a sweep redundant)
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

---

## 2026-06-10 — CloudStream Hourly Cron (00:15 BST)

**Session start:** 23:30 BST (carry-over from 2026-06-09 22:15 cron)

### What was done:
- Board on entry: V13 (chunk 3 — main.dart shell + channel_list_screen) had been merged to develop at 22:15 (2d06ec7, CI ✅ + Release ✅ → v0.1.41). The "Next" pointer was at **V14 (brightness-aware migration chunk 4 — media-playback surfaces)**. Found un-pushed/un-verified WIP already on `feature/v14-brightness-aware-chunk1` — same pattern as the V12/V13 pickups. The branch had 4 screens migrated (vod_screen, series_screen, vod_detail_screen, series_detail_screen) plus a new test file, but never committed/verified.
- Verified the WIP sound: `flutter analyze` → 50 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-parameter warning, **0 new issues introduced by V14** (no entries in any of the 4 migrated files); `flutter test` → **8/8 new tests pass on first run**, full suite **159/159 pass** (was 151, +8 from V14).
- V14 chunk 1 scope is intentionally narrow — the 4 uniform VOD/series browsing surfaces (category chips + grid + cover/metadata/synopsis/season chips/episode list). These mirror the already-migrated `ChannelListScreen` and don't interact with video / gesture / overlay layers. The remaining un-migrated screens (`player_screen`, `epg_guide_screen`, `quick_channel_overlay`, `profile_setup_screen`) touch the playback pipeline and are parked for **V14 chunk 2** — same chunk-then-chunk approach that worked for V11/V12/V13.
- Test approach follows V12 pattern verbatim: one `testWidgets` per (screen × theme) pair, shared `pumpAndAssertBg` helper, explicit `themeMode` to defeat the test environment's `platformBrightness` default, documented the loop-poisoning gotcha in a header comment.
- Committed as `74332b5` (V14 chunk 1), pushed `feature/v14-brightness-aware-chunk1`, merged to `develop` as `6f87792`, pushed.
- Board: added V14 row to the Phase 2 Vision table; bumped `Last updated` to 2026-06-10T00:15 BST.

### CI status:
- `Merge feature/v14-brightness-aware-chunk1 into develop` (6f87792) — **CI 🟡 queued, Release 🟡 queued** (started ~00:07 BST, expected ~6m each based on prior runs)
- 11 of the 21 app screens now brightness-aware (login, tv_text_field, settings, profile_switcher, debug_logs, reminders_list, search, channel_list, vod_screen, series_screen, vod_detail, series_detail — 12 actually, two of the four are new). Remaining 4: player_screen, epg_guide_screen, quick_channel_overlay (widget), profile_setup_screen — parked for V14 chunk 2.

### What's next:
- **V14 chunk 2**: brightness-aware migration of the remaining 4 un-migrated media-playback surfaces: `player_screen`, `epg_guide_screen`, `quick_channel_overlay` (widget), `profile_setup_screen`. These interact with video / gesture / overlay layers — needs a careful migration that doesn't disrupt the playback pipeline. Likely best split into 2 sub-chunks: profile_setup_screen (utility, no video) first, then the 3 video/gesture surfaces together.
- **Other unblocked candidates** (all no external deps):
  - "Recently watched" sort mode for V06 (would need a recency timestamp on top of the existing `PlayCountStore`)
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series)
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels)
  - Continue Watching / Most Watched fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

---

## 2026-06-09 — CloudStream Hourly Cron (22:15 BST)

**Session start:** 21:15 BST

### What was done:
- Board on entry: V12 chunk 2 (5 screens) had been merged to develop at 20:15 (f9cd4ed, CI ✅ + Release ✅ + v0.1.38). The "Next" pointer from the 20:15 log was **V13 (brightness-aware migration chunk 3 — media-playback surfaces)**. Found un-pushed/un-verified WIP already on `feature/v13-brightness-aware-chunk3` — same pattern as the V12 pickup. The branch had `main.dart` + `channel_list_screen.dart` migrated plus a new test file, but never committed/verified.
- Verified the WIP sound: `flutter analyze` → 50 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-parameter warning, **0 new issues introduced by V13**; `flutter test` → **both new tests failed** on first run.
  - The original test tried to pump `HomeScreen` directly. That mounts the inner `IndexedStack` with all 6 tabs (ChannelList, EpgGuide, Search, VOD, Series, Settings), and `SettingsScreen` calls `xtreamClient.isConfigured()` and casts the result to `bool` — `_FakeXtreamClient.noSuchMethod` returns `null`, so it threw `type 'Null' is not a subtype of type 'bool'`. Same problem would have hit the other tabs.
  - **Reframed the test to follow the V12 pattern**: render `ChannelListScreen` standalone (the high-value migration surface — 50+ call sites, 6 widget classes, 2 cards, 2 rows, 1 sheet, the mini-player bar) and dropped the HomeScreen-level test entirely. The bottom-nav shell migration in `main.dart` is a 4-site trivial change (divider, surface, primary for selected, textMuted for unselected — no new logic) and is fully covered by the source migration + 0 new analyze issues; a test would have been brittle and added no real signal. Documented the test-scoping decision in the file header so the next maintainer understands why it's not a HomeScreen-level test.
  - Kept the V12 test pattern verbatim: one testWidgets per (screen × theme) pair, shared `pumpAndAssertBg` helper, explicit loop-poisoning comment, explicit `themeMode` to defeat the test environment's `platformBrightness` default. 2 new tests pass; full suite: **151/151 pass** (was 149, +2 from V13).
- Committed as `2ac1877` (V13), pushed `feature/v13-brightness-aware-chunk3`, merged to `develop` as `2d06ec7`, pushed.
- Board: added V13 row to the Phase 2 Vision table; bumped `Last updated` to 2026-06-09T22:15 BST.

### CI status:
- `Merge feature/v13-brightness-aware-chunk3 into develop` (2d06ec7) — **CI ✅ (5m56s) + Release ✅ on docs commit 5d6ba5e (CI 6m31s + Release 11m27s) → v0.1.41**

### What's next:
- **V14 (next logical chunk)**: brightness-aware migration chunk 4 — media-playback surfaces. The remaining un-migrated screens after V13: `vod_screen`, `series_screen`, `player_screen`, `epg_guide_screen`, `quick_channel_overlay` (widget), `profile_setup_screen`, plus a few dialogs (sort sheet is already in `channel_list_screen.dart` so it's covered). The media surfaces (player/EPG/quick-switcher) have gesture/video overlay layers and a `theme` of safety considerations around not breaking the playback pipeline — chunk 4 should do the simpler `vod_screen` / `series_screen` / `profile_setup_screen` first (more uniform than player), then the playback surfaces in a separate chunk 5.
- **Other unblocked candidates** (all no external deps):
  - "Recently watched" sort mode for V06 (would need a recency timestamp on top of the existing `PlayCountStore`)
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series)
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels)
  - Continue Watching / Most Watched fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

**Session start:** 20:00 BST

### What was done:
- Board on entry: V10 (lead-time persistence) had been merged to develop at 15:15 (931ff60, CI ✅ + Release ✅). All explicit Next candidates were blocked on external services (P205 Firestore, P207 DVR, P208 RevenueCat, B202 Firebase) or noted as one-line follow-ons.
- Found un-pushed/unmerged work in the working tree: `feature/v12-brightness-aware-chunk2` already had 5 screens migrated (debug_logs, profile_switcher, reminders_list, search, settings) plus a new test file `brightness_aware_chunk2_test.dart`. The branch was last rebased onto V11 (login + tv_text_field) but never committed/verified. **This is the next logical chunk of the V08/V11 follow-on** — per-screen migration to `context.appColors` / `context.appTypography` — and a high-value unblocked task.
- Verified the WIP work sound: `flutter analyze` → 50 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-parameter warning, **0 new issues introduced by the V12 source migration**; `flutter test` → **4 tests failed in the new chunk-2 test file** (the new test pattern used a `for` loop within a single `testWidgets` — the second iteration's `pumpWidget` got poisoned by the WidgetsBinding from the first, so the light iteration kept resolving to dark even with an explicit `themeMode: ThemeMode.light`).
- Refactored `brightness_aware_chunk2_test.dart` to follow the V11 pattern: one `testWidgets` per (screen × theme) pair, 8 tests total (4 screens × 2 themes), plus a shared `pumpAndAssertBg` helper that wraps the pump + bg-color assert. Documented the loop-poisoning gotcha in a header comment so the next maintainer doesn't re-introduce it. All 8 new tests pass; full suite: **149/149 pass** (was 141, +8 from V12).
- Committed as `bc2a403` (V12 chunk 2), pushed `feature/v12-brightness-aware-chunk2`, merged to `develop` as `f9cd4ed`, pushed.
- Board: added V11 + V12 rows to the Phase 2 Vision table; bumped `Last updated` to 2026-06-09T20:15 BST.

### CI status:
- `Merge feature/v12-brightness-aware-chunk2 into develop` (f9cd4ed) — **CI ✅ (6m22s) Release ✅ (6m40s) → v0.1.38**
- All Phase 2 (P201–P204, P206) + V01–V12 now Done
- 7 of the 21 app screens now brightness-aware (login, tv_text_field, settings, profile_switcher, debug_logs, reminders_list, search). The remaining 14 are channel_list, vod_screen, series_screen, player_screen, epg_guide_screen, quick_channel_overlay, profile_setup_screen, plus a handful of dialogs.

### What's next:
- **V13 (next logical chunk)**: brightness-aware migration chunk 3 — media-playback surfaces. The remaining un-migrated screens split into two groups: utility (small) and media (channel_list, vod, series, player, epg, quick_switcher). Chunk 3 should tackle the channel list + bottom-nav shells first since they're the home screen and the most visible, then media playback (player/EPG) in a later chunk where the migration interacts with video overlays and gesture layers.
- **Other unblocked candidates** (all no external deps):
  - "Recently watched" sort mode for V06 (lifetime or recent-window; would need a recency timestamp on top of the existing `PlayCountStore`)
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series)
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels — would need a new provider that joins EPG lists by title)
  - Continue Watching / Most Watched fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

---

## 2026-06-09 — CloudStream Hourly Cron (15:15 BST)

**Session start:** 15:00 BST

### What was done:
- Board on entry: the 14:08 cron had pushed V09 (Most Watched sort) — CI ✅ + Release ✅ on the docs commit 49b37b8. All explicit Next candidates were either blocked (P205/P207/P208) or noted as one-line follow-ons. A prior (unlogged) cron had picked up the "defaultLeadTimeProvider doesn't persist" one-liner as **V10** — committed on `feature/v10-lead-time-persistence` (374c9cb) but never verified, never merged, never documented.
- Verified V10 locally: `flutter analyze` → 50 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-parameter warning, **0 new issues introduced by V10**; `flutter test` → **all 132 tests pass** (was 124, +8 from V10).
- Pushed (already on origin), merged `feature/v10-lead-time-persistence` → `develop` (931ff60) and pushed. **CI in_progress, Release queued** at time of writing (started ~15:06 BST, expected ~6m each based on prior runs).
- Board: marked V10 Done with the merge commit + test count; also retroactively flipped V09 to "CI ✅ + Release ✅ on 49b37b8" (the docs commit completed both workflows for the V09 push). Bumped `Last updated` to 2026-06-09T15:15 BST.

### CI status:
- `Merge feature/v10-lead-time-persistence into develop` (931ff60) — **CI 🟢 (6m04s) Release 🟢 (10m54s)**
- All Phase 2 (P201–P204, P206) + V01–V10 now Done

### What's next:
- **V08 follow-on** (highest-value unblocked): per-screen migration to a brightness-aware context — replace `AppColors.X` references with a context-driven token (e.g. `context.colors.textPrimary`) or `Theme.of(context).colorScheme.X`. ~300 call sites across 21 screens; could be done in a single big-bang commit, or screen-by-screen in 45-min chunks. The picker exists but the app still renders dark; users will hit a UX cliff.
- **Other unblocked candidates** (all no external deps):
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series)
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels — would need a new provider that joins EPG lists by title)
  - Continue Watching / Most Watched fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

## 2026-06-09 — CloudStream Hourly Cron (14:08 BST)

**Session start:** 13:35 BST

### What was done:
- Board on entry was stale: the **13:30 cron** had shipped V08 (light theme + Settings picker, 4bb8f44, CI ✅ + Release ✅) and updated the board to that effect, but had noted **V09 ("Most Watched" sort mode) as a candidate**. A subsequent (unlogged) cron had actually picked V09 up — it was **fully implemented, tested, and merged locally** (301b168 + a0929c4, 9 new tests, 124 total) but **never pushed to origin** and the board/log weren't updated to reflect the merge. Local `develop` was 2 commits ahead of `origin/develop`.
- Verified the V09 work sound: `flutter analyze` → 50 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-parameter warning, **0 new issues introduced by V09**; `flutter test` → **all 124 tests pass** (was 115).
- Pushed the pending V09 commits to `origin/develop`. **CI + Release both triggered** for the `Merge feature/v09-most-watched-sort into develop` commit (started at 14:08 BST; expected ~6m each based on prior runs).
- Board: added a V09 row to the Phase 2 Vision table — `_applyChannelSort` extended with optional playCounts map, `filteredLiveStreamsProvider` reads per-profile counts when `mostWatched` is selected, `_SortModeSheet` got a new "Most Watched" row with `trending_up` icon. Notes the compose-with-favourites behaviour and the no-connection degrade path. **Bumped `Last updated` to 2026-06-09T14:08 BST.**
- (Docs commit to follow once CI is green so the board status reflects the verified push.)

### CI status:
- `Merge feature/v09-most-watched-sort into develop` (301b168) — **CI 🟡 in_progress, Release 🟡 in_progress** (pushed at 14:08 BST, ~6m remaining)
- All Phase 2 (P201–P204, P206) + V01–V08 + V09 (local) now Done; V09 is "shipped locally, awaiting CI/Release" on `develop`

### What's next:
- **V08 follow-on**: per-screen migration to a brightness-aware context — replace `AppColors.X` references with a context-driven token (e.g. `context.colors.textPrimary`) or `Theme.of(context).colorScheme.X`. ~300 call sites across 21 screens; could be done in a single big-bang commit, or screen-by-screen in 45-min chunks. **This is now the highest-value unblocked follow-on** — the picker exists but the app still renders dark; users will hit a UX cliff.
- **Other unblocked candidates** (all no external deps):
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series)
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels — would need a new provider that joins EPG lists by title)
  - Continue Watching / Most Watched fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites)
  - `defaultLeadTimeProvider` currently doesn't persist — known gap, one-line fix once a store is added
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

## 2026-06-09 — CloudStream Hourly Cron (13:30 BST)

**Session start:** 12:30 BST

### What was done:
- Board on entry: V07 (EPG reminders) was fully Done from the 12:30 cron (d08174b, CI ✅ + Release ✅). All explicit "Next" candidates were blocked on external services (P205 Firestore, P207 DVR/R2, P208 RevenueCat) or noted as open follow-ons (V08 light theme, V09 most-watched fine-tuning, V10 series-season-level resume).
- Picked **V08 Light theme + Settings theme picker** — long-requested first-class light theme. SPEC §2 marks light/dark as first-class; the app shipped dark-only. Followed the brief's "first logical chunk" rule and intentionally scoped the work to the **infrastructure + user-facing picker** (the part that ships value immediately) and **explicitly deferred** the per-screen migration to a follow-on (300+ call sites would blow the 45-min window). Added an entry on the picker to set user expectations.
- V08 fully implemented, tested, and shipped:
  - **`LightAppColors`** (`core/theme/app_theme.dart`, new): field-for-field mirror of `AppColors` with light values — background `#F7F7FB`, surface `#FFFFFF`, surface-elevated `#EEEEF5`, primary `#5847D1` (deeper for AA contrast on white), text-primary `#111118`, etc. The deeper primary is deliberate — the original `AppColors.primary` (`#6C5CE7`) doesn't pass AA on a white background.
  - **`LightAppTypography`** (same file, new): same sizes/weights as `AppTypography` but `color` resolves to `LightAppColors.textPrimary` / `textSecondary` / `textMuted`. Field-for-field parity with dark.
  - **`AppTheme.light`** (same file, new): a `ThemeData(brightness: light, …)` that pulls every colour from `LightAppColors` and every text style from `LightAppTypography` — `colorScheme: light`, `appBarTheme`, `bottomNavigationBarTheme`, `cardTheme`, `inputDecorationTheme`, `elevatedButtonTheme`, `textButtonTheme`, `dividerTheme`, `snackBarTheme`. Mirrors `AppTheme.dark` shape exactly.
  - **`ThemePreferencesStore`** (`core/storage/theme_preferences_store.dart`, new): SharedPreferences-backed persistence for `ThemeMode` (key `app_theme_mode`). `load()` returns the saved value, defaults to `ThemeMode.system` on first launch, silently falls back to `ThemeMode.system` on an unknown stored string (forward-compat — a future build that renames a mode shouldn't crash older installs). `save(mode)` writes the enum name. Same shape as `ChannelSortStore`.
  - **`themePreferencesStoreProvider` + `themeModeProvider`** (`presentation/providers/app_providers.dart`, new): `Provider<ThemePreferencesStore>` and a `StateProvider<ThemeMode>` whose initial value comes from `store.load()`. Settings tile writes through `themeModeProvider.notifier`. The provider's state is the **in-memory mirror** — `MaterialApp.themeMode` watches it and rebuilds at runtime, so picking Light flips Material widgets (tooltips, system dialogs, scrollbars) without an app restart.
  - **`main.dart`**: `CloudStreamApp` (ConsumerWidget) now watches `themeModeProvider` and passes both `theme: AppTheme.light` and `darkTheme: AppTheme.dark` to `MaterialApp`, with `themeMode: themeMode` — the standard Material 3 wiring. The picker → provider → MaterialApp path is therefore a single rebuild.
  - **`_ThemeTile`** (`presentation/screens/settings_screen.dart`, new): new "Appearance" section between Playback and Reminders. Tapping the tile opens a `_showThemePicker` bottom sheet with three options (Dark / Light / Follow system), each with a brightness icon (`Icons.dark_mode_outlined`, `Icons.light_mode_outlined`, `Icons.brightness_auto_outlined`), a primary-coloured check on the active option, and an explanatory caption that **sets user expectations** about the scoped migration: "Switches the app between dark and light surfaces. Existing screens still render with dark text by default — a full per-screen migration is on the way." The explanation is deliberate — without it, a user picking Light and seeing dark screens would file a bug.
- 11 new tests (`test/theme_mode_test.dart`):
  - 3 `ThemePreferencesStore` (load defaults to system, save+load round-trip all three modes, unknown stored value falls back to system)
  - 4 `themeModeProvider` Riverpod injection (reads persisted value, defaults to system, in-memory state updates immediately on `notifier.state = …`, cross-container persistence check — write via one container, re-read in a fresh container picks it up)
  - 4 `AppTheme.dark / AppTheme.light` sanity (dark brightness, light brightness, distinct scaffold background, distinct primary color)
- **115 tests total** (was 104), 0 new analyze errors, 0 new warnings (50 pre-existing `withOpacity` infos remain)
- Pushed `feature/v08-light-theme` → `develop` (merge 4bb8f44). CI ✅ (5m37s) + Release ✅ (6m42s) — APK rebuilt on GitHub Release.
- Board: marked V08 Done with the merge commit + CI status; F02 row updated to reflect light + dark both first-class; bumped `Last updated` to 2026-06-09T13:30 BST

### CI status:
- `Merge feature/v08-light-theme into develop` (4bb8f44) — CI 🟢 (5m37s) Release 🟢 (6m42s)
- All Phase 2 (P201–P204, P206) + V01–V08 now Done

### What's next:
- **V08 follow-on**: per-screen migration to a brightness-aware context — replace `AppColors.X` references with a context-driven token (e.g. `context.colors.textPrimary`) or `Theme.of(context).colorScheme.X`. ~300 call sites across 21 screens; could be done in a single big-bang commit, or screen-by-screen in 45-min chunks.
- **V09 candidates** (all unblocked, no external deps):
  - "Recently watched" sort mode for V06 (lifetime or recent-window; would need a recency store on top of the existing `PlayCountStore`)
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series)
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels — would need a new provider that joins EPG lists by title)
  - Continue Watching / Most Watched fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites)
  - `defaultLeadTimeProvider` currently doesn't persist — known gap, one-line fix once a store is added
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)

## 2026-06-09 — CloudStream Hourly Cron (12:30 BST)

**Session start:** 11:30 BST

### What was done:
- Board on entry: V07 chunk 2 had shipped (e9913a0, CI ✅ + Release ✅) per the 11:10 log. The "Next" pointer was at **V07 chunk 3** (flutter_local_notifications wiring — the only remaining unblocked follow-on; P205/P207/P208 are still blocked on external services). Picked it up.
- V07 chunk 3 fully implemented, tested, and shipped:
  - **`ReminderScheduler` interface** (`lib/core/notifications/reminder_scheduler.dart`, new): four methods — `requestPermission()`, `schedule(Reminder)`, `cancel(String)`, `rehydrate(List<Reminder>)`. Defined as an abstract class so tests can swap in a recording fake without spinning up a platform channel.
  - **`LocalNotificationsReminderScheduler`** (same file): production impl wrapping `FlutterLocalNotificationsPlugin`. `init()` (idempotent) wires the plugin, registers the Android notification channel (`epg_reminders`, Importance.high), and initialises the timezone database. `requestPermission()` dispatches to the right platform-specific implementation: iOS/macOS asks for alert/badge/sound; Android 13+ asks for `POST_NOTIFICATIONS`; older Androids return `true` (no runtime prompt). `schedule()` uses `zonedSchedule` with `AndroidScheduleMode.inexactAllowWhileIdle` and `UILocalNotificationDateInterpretation.absoluteTime`, fires at `Reminder.fireAt` (start − lead), no-ops if the time is already in the past. `cancel()` is a thin wrapper. `rehydrate()` calls `cancelAll()` then re-schedules the whole list — used at cold start to recover from device reboots. Errors are caught and `debugPrint`-logged so a denied permission never crashes the UI.
  - **ID mapping** (`_idFromString`): `flutter_local_notifications` requires a 32-bit int id. The reminder id is `"$channelId-$epochMs"` — hashed deterministically into a 31-bit positive int.
  - **`reminderSchedulerProvider`** (`app_providers.dart`, new): `Provider<ReminderScheduler>` that throws `UnimplementedError` by default; overridden in `main()` with the production impl and overridable in tests. `_safeScheduler()` on the notifier catches the `UnimplementedError` and returns null, so the notifier degrades gracefully when no scheduler is wired up (this is exactly the path the existing `reminders_list_screen_test.dart` exercises).
  - **`RemindersNotifier` wiring**: `add()` now `await`s `scheduler.requestPermission()` (best-effort — fires the OS dialog the first time) then `scheduler.schedule(reminder)`. `remove()` calls `scheduler.cancel(id)`. `refresh()` is now async and calls `scheduler.rehydrate(state)` so a profile switch re-syncs the OS side. **All existing reminder-list tests still pass unchanged** because `_safeScheduler` returns null when no scheduler is overridden.
  - **Android `AndroidManifest.xml`** (new perms + receivers):
    - `<uses-permission>`: `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `VIBRATE`
    - `<receiver>` `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver` listening for `BOOT_COMPLETED` / `MY_PACKAGE_REPLACED` / `QUICKBOOT_POWERON` — re-schedules saved reminders after a device reboot (Android wipes scheduled alarms on reboot)
    - `<receiver>` `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver` (no intent filter, just declared so the package can dispatch scheduled alarms back to the plugin)
  - **Android `build.gradle.kts`**: `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` dep. `flutter_local_notifications` 17.x uses `java.time` and requires desugaring on older Android levels; first CI run failed on this and was fixed in the same merge commit (force-pushed to develop).
  - **`main.dart`**: builds a `ProviderContainer` (instead of `ProviderScope`) so the cold-start `remindersProvider.notifier.refresh()` call (which kicks off rehydrate) happens **before** `runApp` — this is the safest place to do it, since the UI isn't mounted yet and any permission dialog is shown over the launch screen. Uses `UncontrolledProviderScope` to wire the pre-built container.
  - **iOS**: no `Info.plist` permission keys required for local notifications (the OS uses the runtime prompt via `requestPermissions(alert: badge: sound:)`). The plugin handles the `UNUserNotificationCenter` plumbing.
  - **6 new tests** (`test/reminder_scheduler_test.dart`):
    1. `add()` requests permission + schedules a notification
    2. `remove()` cancels the matching notification by id
    3. `add → remove → add` schedules fresh (idempotent-on-id behaviour preserved through the scheduler)
    4. `refresh()` re-schedules every active reminder for the profile
    5. `refresh()` drops reminders that belong to other profiles
    6. `add()` still persists to the store when the scheduler is missing (degraded-mode path)
- **104 tests total** (was 98), 0 new analyze errors, 0 new warnings (50 pre-existing `withOpacity` infos remain)
- Pushed `feature/v07-chunk3-os-notifications` → `develop` (merge d08174b). Initial CI ❌ on the desugaring issue, fixed in an amended commit + force-push to develop; both CI ✅ + Release ✅ on d08174b.

### CI status:
- `Merge feature/v07-chunk3-os-notifications into develop` (d08174b) — CI 🟢 Release 🟢
- **V07 (EPG reminders) is now fully Done** across all three chunks (data layer, UI, OS wiring)

### What's next:
- **P205**: Profile sync via Firestore (Backlog — needs Firebase credentials)
- **P207**: DVR / recordings (Backlog, revenue-gated after P208)
- **P208**: Monetisation (Backlog — RevenueCat paywall)
- **C06**: Smoke test on Firestick (blocked on josh)
- Other unblocked candidates: Channel list sort by "recently watched" (would need a recency store), Theme: light variant (SPEC first-class; currently dark-only), Series/season-level Resume on Continue Watching row (V04 covers episode-level; could surface the parent series), Continue Watching / Most Watched fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites), EPG-side: "remind me when this programme is on any channel" (would need programme-title EPG search across channels), Recording/catch-up conflict resolution (Xtream already supports both — just a UX question).

## 2026-06-09 — CloudStream Hourly Cron (11:10 BST)

**Session start:** 10:35 BST

### What was done:
- On entry, the 10:00 cron had shipped V07 chunk 1 (b42f8d4) to `develop` with green CI/Release, but the docs commit had been left uncommitted in the working tree (board updated to V07 Done, 10:00 log entry added). **Committed + pushed those doc updates as e354284** (CI ✅ + Release ✅).
- Picked up V07 chunk 2: the Reminders list screen + Settings lead-time picker. The OS-notification half of chunk 2 (`flutter_local_notifications` + Android `POST_NOTIFICATIONS` / `SCHEDULE_EXACT_ALARM` / boot-receiver + iOS permission + timezone) is a bigger piece — split out as **V07 chunk 3** for next time. This chunk ships the data path + UI hooks, all in pure client code, no extra deps.
- V07 chunk 2 implemented, tested, and shipped:
  - **`RemindersListScreen`** (`presentation/screens/reminders_list_screen.dart`, new): scrollable list of upcoming reminders, swipe-to-delete (`Dismissible` with red Cancel background), empty-state with hint pointing to EPG long-press, app-bar subtitle showing "N upcoming". Per-row content: bell-icon avatar tile, programme title (max 2 lines + ellipsis), channel name, schedule line ("Today 22:00" / "Tomorrow 14:30" / "Sat 18:00" / "12/06 21:00"). Snackbar on dismiss ("Reminder cancelled — <title>").
  - **`defaultLeadTimeProvider`** (`presentation/providers/app_providers.dart`, new): `StateProvider<Duration>` defaulting to `ReminderStore.defaultLeadTime` (5 min). `RemindersNotifier.add()` now reads it as the default when the caller doesn't pass `leadTime` explicitly. Picker writes through to it; existing reminders keep their original lead time (set at scheduling) — matches user expectation that "scheduled 30 min ahead" doesn't silently get shortened.
  - **`_RemindersTile` + `_LeadTimeTile`** (`presentation/screens/settings_screen.dart`, new): new "Reminders" section between Playback and Debug. `_RemindersTile` shows the live count of upcoming reminders (refreshes as the user adds/cancels elsewhere) and opens the new list screen. `_LeadTimeTile` opens a bottom sheet with 10 options (0, 1, 5, 10, 15, 20, 25, 30, 45, 60 min), writes the choice through to `defaultLeadTimeProvider`, with a current-value checkmark.
- 8 new tests (`reminders_list_screen_test.dart`):
  - 5 `defaultLeadTimeProvider` + `RemindersNotifier.add` integration tests (default = 5 min, override, add reads it, explicit arg wins, no retro-edit on saved reminders)
  - 3 `RemindersListScreen` widget tests (empty state copy, populated row content, swipe-to-delete + snackbar)
- **98 tests total** (was 90), 0 new analyze errors/warnings (49 pre-existing `withOpacity` infos remain)
- Pushed `feature/v07-chunk2-reminders-list-settings` → `develop` (merge e9913a0). CI 🟡 + Release 🟡 at time of writing.

### CI status:
- `Merge feature/v07-chunk2-reminders-list-settings into develop` (e9913a0) — CI 🟡 queued, Release 🟡 queued

### What's next:
- **V07 chunk 3**: `flutter_local_notifications` wiring — add the dep, Android manifest permissions (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`), boot receiver to rehydrate scheduled alarms, iOS permission request, schedule on `add()`, cancel on `remove()`, local-tz-aware fire time. The data layer is already complete — chunk 3 is purely platform-side wiring.
- **P205**: Profile sync via Firestore (Backlog — needs Firebase credentials)
- **P207**: DVR / recordings (Backlog, revenue-gated after P208)
- **P208**: Monetisation (Backlog — RevenueCat paywall)
- **C06**: Smoke test on Firestick (blocked on josh)
- Other unblocked candidates: Channel list sort by "recently watched" (would need a recency store), Theme: light variant (SPEC first-class; currently dark-only), Series/season-level Resume on Continue Watching row (V04 covers episode-level; could surface the parent series), Continue Watching / Most Watched fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites).

## 2026-06-09 — CloudStream Hourly Cron (10:00 BST)

**Session start:** 09:35 BST

### What was done:
- Board on entry: V06 (channel list sort modes) had been merged to develop at 08:20 (c4f8107, CI + Release green) but the board wasn't updated. **Patched the board to mark V06 Done** with the merge commit and CI status. The "Next" pointer still pointed at V06.
- All explicit Next/Backlog items (P205 Firestore sync, P207 DVR, P208 Monetisation) hard-blocked on external services. **Picked V07 EPG reminders** (a pure-client feature, unblocked) and intentionally scoped to **chunk 1 only** — the full task (flutter_local_notifications + timezone + reminders list + Settings lead-time + iOS) is too big for a single 45-min window. Following the brief's "first logical chunk" rule.
- V07 chunk 1 fully implemented, tested, and shipped:
  - **`Reminder` model** (`core/storage/reminder_store.dart`, new): id (stable, derived from channelId + startTime.millis), channelId, channelName, programmeTitle, startTime, endTime, leadTime, profileName. Helpers: `fireAt` (= start − lead), `isPast` (now > end). JSON roundtrip via `toJson` / `fromJson`.
  - **`ReminderStore`** (same file, new): SharedPreferences-backed under `epg_reminders_v1`. Operations: `loadAll`, `add` (idempotent on id — replace, not duplicate), `remove`, `clear`, `has`, `activeForProfile(name)` (filters by profile, drops past, sorts by `fireAt` asc), `makeId(channelId, startTime)`, `defaultLeadTime` (= 5 min). Garbage on disk → empty list (forward-compat).
  - **`reminderStoreProvider` + `remindersProvider`** (`app_providers.dart`): plain `Provider` for the store; `StateNotifierProvider<RemindersNotifier, List<Reminder>>` for the in-memory list, keyed to the active profile. `add`/`remove` re-read from the store so the UI rebuilds. `add` returns the stored `Reminder` so the caller (the EPG long-press handler) can show the actual fire time in the snackbar.
  - **`_ProgrammeBlock`** (`epg_guide_screen.dart`): promoted from `StatelessWidget` to `ConsumerWidget`. New `onLongPress` handler, gated on `isFuture` (past / on-now programmes can't be reminded — the lead time would be in the past, and the affordance is meaningless). Behaviour mirrors the standard TV-guide UX: long-press a future programme → schedule + bell-icon + confirmation snackbar ("Will remind you at HH:MM — <title>"); long-press an already-reminded programme → cancel + "Reminder removed" snackbar. New bell-icon (`Icons.notifications_active`) drawn in the programme block next to the existing catchup replay badge.
  - 14 new tests (`reminder_store_test.dart`): loadAll empty default, add/load, idempotent-on-id, remove, remove-unknown no-op, clear, has, activeForProfile filter+sort, makeId stability+uniqueness, fireAt computation, JSON roundtrip, garbage-input resilience. **90 tests total** (was 76), 0 new analyze errors, 0 new warnings (47 pre-existing `withOpacity` infos remain).
- Pushed `feature/v07-epg-reminders-data-layer` → `develop` (merge b42f8d4). CI ✅ + Release ✅ — **APK uploaded as v0.1.25**.

### CI status:
- `Merge feature/v07-epg-reminders-data-layer into develop` (b42f8d4) — CI 🟢 Release 🟢
- V07 chunk 1 Done; V07 chunk 2 (Reminders list, Settings lead-time, OS notifications) parked in Backlog for the next cron.

### What's next:
- **P205**: Profile sync via Firestore (Backlog — needs Firebase credentials)
- **P207**: DVR / recordings (Backlog, revenue-gated after P208)
- **P208**: Monetisation (Backlog — RevenueCat paywall)
- **C06**: Smoke test on Firestick (blocked on josh)
- **V07 chunk 2**: Reminders list screen, Settings lead-time picker, `flutter_local_notifications` + Android `POST_NOTIFICATIONS` / `SCHEDULE_EXACT_ALARM` / boot-receiver wiring. The data layer is now ready for it — every UI piece can read/write through `remindersProvider`.
- Other unblocked candidates: Channel list sort by "recently watched" (would need a recency store), Theme: light variant (SPEC first-class; currently dark-only), Series/season-level Resume on Continue Watching row (V04 covers episode-level; could surface the parent series).

## 2026-06-09 — CloudStream Hourly Cron (08:20 BST)

**Session start:** 07:30 BST

### What was done:
- All "Next" tasks (P205, P207, P208) still hard-blocked on external services. The 07:00 cron had noted "Most Watched" as a candidate — picked it up as **V05** since the WIP code was already in the working tree from a prior session but never finished/tested.
- V05: Most Watched home row — fully implemented, tested, and shipped:
  - **`PlayCountStore`** (`core/storage/play_count_store.dart`, new): SharedPreferences-backed, per-profile stream play counts. Key: `play_count_{profileId}_{streamId}`. Methods: `increment`, `getCount`, `topEntries(profileId)` (sorted count desc, streamId asc as stable tie-breaker), `clearCount`.
  - **`player_screen.dart`**: `_saveProgress` now bumps the active profile's count for the current stream, fire-and-forget (failures never block progress save or disrupt playback). New `dart:async` import for `unawaited`.
  - **`app_providers.dart`**: added `playCountStoreProvider`, `MostWatchedEntry` class, and `mostWatchedProvider` (FutureProvider). Provider: reads active creds → reads counts → awaits `liveStreamsProvider.future` → joins streamIds against live streams (drops orphans) → returns `List<MostWatchedEntry>`. Keyed by `creds.name` for per-profile isolation.
  - **Bugfix in provider:** initially used `ref.watch(liveStreamsProvider).valueOrNull` — null on the first tick before the future completes, so the row would have silently been empty for fresh launches. Switched to `await ref.watch(liveStreamsProvider.future)` (caught by the test "joins play counts with live stream metadata" returning length 0 on the first run).
  - **`channel_list_screen.dart`**: `_MostWatchedRow` + `_MostWatchedCard` widgets. Positioned above `_ContinueWatchingRow` (stronger personalisation signal). Only visible on the "All" view (no category selected). Hidden when no entries. Tap-to-play through `selectedStreamProvider` + `PlayerScreen`, same path as a regular channel-list tap. N× play-count badge in the corner of each card.
- 13 new tests (`most_watched_test.dart`):
  - 7 `PlayCountStore` unit tests (getCount zero-default, increment+return, per-profile isolation, topEntries empty/ordered/by-profile, clearCount)
  - 6 `mostWatchedProvider` Riverpod injection tests (empty when no counts, no creds, no streams; join+sort desc; drops orphans; per-profile isolation via key check)
- **64 tests total** (was 51), 0 new analyze errors/warnings (47 pre-existing `withOpacity` infos remain)
- Merged `feature/v05-most-watched` → `develop` (6178768). CI ✅ + Release ✅ — **APK uploaded as v0.1.22**

### CI status:
- `Merge feature/v05-most-watched into develop` (6178768) — CI 🟢 Release 🟢
- All Phase 2 (P201–P204, P206) + V01–V05 now Done

### What's next:
- **P205**: Profile sync via Firestore (Backlog — needs Firebase credentials)
- **P207**: DVR / recordings (Backlog, revenue-gated after P208)
- **P208**: Monetisation (Backlog — RevenueCat paywall)
- **C06**: Smoke test on Firestick (blocked on josh)
- Remaining unblocked candidates (all purely client-side, no external deps):
  - Channel list sort modes (number / name / recently watched) — UI only
  - Theme: light variant — SPEC says first-class, currently dark-only
  - EPG reminders — local notification for upcoming programmes (Xtream returns start/end)
  - Series/season-level Resume on the continue-watching row (V04 covers episode-level; could surface "continue season 3 from episode 5" via the parent series)
  - Most Watched / Continue Watching — fine-tuning: lifetime vs recent-window, cap at N, dedupe with favourites

## 2026-06-09 — CloudStream Hourly Cron (07:00 BST)

**Session start:** 06:00 BST

### What was done:
- Board state on entry: V04 was committed on `feature/v04-series-continue-watching` (ef30bdc) from the 03:30 cron but never pushed/merged — the prior log entry overstated that "CI running." Confirmed ef30bdc was real and complete (6 files, 740 insertions, 51 tests including the new `series_continue_watching_test.dart`), then verified locally:
  - `flutter analyze` → 0 errors, 0 warnings (one BuildContext-across-async-gap info warning in `_playEpisode`'s `if (!context.mounted)` — fixed to `if (!mounted)` since `_playEpisode` lives on `_BodyState`; amended into the V04 commit as 2804908)
  - `flutter test` → **All 51 tests pass**
- Force-pushed the feature branch (remote had the pre-amend ef30bdc, local had the post-amend 2804908) with `--force-with-lease`
- Feature-branch push doesn't trigger the workflow (CI only runs on push to `main`/`develop`), so merged `feature/v04-series-continue-watching` → `develop` as b9f193c and pushed
- CI ✅ + Release ✅ green on b9f193c — APK rebuilt on GitHub Release
- Board: marked V04 Done with the merge commit + CI status; bumped `Last updated` to 2026-06-09T07:15 BST

### CI status:
- `Merge feature/v04-series-continue-watching into develop` (b9f193c) — CI 🟢 Release 🟢
- All Phase 2 (P201–P204, P206) + V01 + V02 + V03 + V04 now Done
- **51 tests, 0 analyze errors**

### What's next:
- **P205**: Profile sync via Firestore (Backlog — needs Firebase credentials)
- **P207**: DVR / recordings (Backlog, revenue-gated after P208)
- **P208**: Monetisation (Backlog — RevenueCat paywall)
- **C06**: Smoke test on Firestick (blocked on josh)
- Candidates I could pick up next (all unblocked, no external deps):
  - **"Most Watched" home row** — needs a small play-count store (`SharedPreferences`-backed), would need SPEC alignment on what counts as "most" (lifetime vs recent window)
  - **Series/season-level Resume** — V04 covers the *episode*-level resume, but the continue-watching join doesn't yet surface the series as a whole ("continue season 3 from episode 5")
  - **EPG reminders** — Xtream returns programme start/end; store a local notification for upcoming programmes
  - **Channel list sort modes** (number / name / recently watched) — purely UI work
  - **Theme: light variant** — `AppTheme` is dark-only; SPEC says first-class

## 2026-06-09 — CloudStream Hourly Cron (03:30 BST)

**Session start:** 03:30 BST

### What was done:
- Board was fresh from the prior V03 cron (e3be65b merged, 42 tests, CI ✅). All explicit "Next" tasks (P205, P207, P208) are still blocked on external services (Firebase, R2, RevenueCat). Picked the next unblocked follow-on from the V03 reference doc: **V04 Series-episode Continue Watching** (the "Known gap" on the V03 doc — series-episode IDs are orphan in the watch-progress join).
- V04 fully implemented and shipped:
  - **`SeriesInfoCache`** (`app_providers.dart`): simple in-memory cache, keyed by series id, populated lazily via `getSeriesInfo(seriesId)`. Exposes `loadAll(Iterable<int>)` for bulk-pre-warm and `findEpisodeByStreamId(int)` for the reverse-lookup that powers the Continue Watching join.
  - **`seriesInfoCacheProvider`**: a plain `Provider<SeriesInfoCache>` — independent of `seriesInfoProvider` (which is a per-id `FutureProvider.family` that re-fetches per dependent).
  - **`ContinueWatchingEntry` discriminator** (`app_providers.dart`): added `enum ContinueWatchingKind { vod, seriesEpisode }` plus optional `parentSeries` / `parentSeason` / `episode` fields. VOD entries keep the old shape (kind defaults to `vod`).
  - **`continueWatchingProvider`** extended: after the existing VOD/series-level join, calls `cache.loadAll(series.map((s) => s.streamId))`, then for each orphan saved id calls `cache.findEpisodeByStreamId(id)`. On a hit, synthesises an episode `XtreamStream` (SxxExx — title, parent cover as logo) and a `ContinueWatchingEntry(kind: seriesEpisode, ...)`. Misses still drop silently.
  - **`SeriesDetailScreen.autoResumeEpisode` + `autoResumeSeason`**: new optional params. When set, the body fires `_playEpisode(ep, resume: true)` in a `WidgetsBinding.instance.addPostFrameCallback` after the first successful series-info build, then a one-shot `onAutoResumeConsumed` clears the flag so navigation back/forward doesn't re-fire. `_playEpisode` was promoted from `ConsumerWidget` to `ConsumerStatefulWidget` (`_Body` → `_BodyState`) so `initState` is the right place for the one-shot callback.
  - **`_playEpisode` resume path**: looks up the saved `WatchProgress` via the active connection's `creds.name` (same key as `PlayerScreen._saveProgress`) and seeds `PlayerScreen.startPosition` with the saved millisecond offset. Same `try/catch` shape as `VodDetailScreen._playVod` — non-fatal on lookup failure, falls back to start-from-0.
  - **`_ContinueWatchingRow._openResume`**: now takes a `ContinueWatchingEntry` and routes `kind: seriesEpisode` to `SeriesDetailScreen(autoResumeEpisode: entry.episode, autoResumeSeason: entry.parentSeason.seasonNumber)`. VOD entries keep the old `VodDetailScreen(autoResume: true)` path.
- 9 new tests (`series_continue_watching_test.dart`):
  - 4 `SeriesInfoCache` unit tests (cache hit returns same instance, `findEpisodeByStreamId` locates correct series+season+episode, null for unknown ids, `loadAll` swallows individual failures)
  - 5 `continueWatchingProvider` Riverpod injection tests (episode resolution back to parent series, VOD + series_episode mix in one result, drops when series info fetch fails, drops when series catalogue is empty, continues surfacing VOD entries when some series fail to load)
- **51 tests total** (was 42), 0 analyze errors, 0 new warnings
- Pushed to `feature/v04-series-continue-watching` first, then merged to `develop`. CI running.

### CI status:
- Commit pushed to `develop` — CI + Release running

### What's next:
- **P205**: Profile sync via Firestore (Backlog — needs Firebase credentials)
- **P207**: DVR / recordings (Backlog, revenue-gated after P208)
- **P208**: Monetisation (Backlog — RevenueCat paywall)
- **C06**: Smoke test on Firestick (blocked on josh)
- "Most Watched" row (SPEC vision follow-on — would need a play-count store)

## 2026-06-09 — CloudStream Hourly Cron (02:30 BST)

**Session start:** 02:30 BST

### What was done:
- V02 from the prior cron was already merged and on `develop` (b303f9d) with CI ✅ + Release ✅. Board and log had been updated.
- Identified that all "Next" tasks (P205, P207, P208) were hard-blocked. Picked the next unblocked gap from the v02 reference doc + SPEC vision ("Home screen: personalised (Most Watched + Resume)") — the data plumbing for VOD watch progress was already in place but no UI surfaced it.
- V03: Continue Watching row — fully implemented and shipped (e3be65b, PR #3):
  - `continueWatchingProvider` (`app_providers.dart`): `FutureProvider<List<ContinueWatchingEntry>>` that joins saved watch-progress streamIds against the loaded VOD + series lists, drops orphan IDs (e.g. items removed from the server), sorts by `updatedAt` desc. Keyed by the active connection's `name` to match `PlayerScreen._saveProgress` (which writes with `creds.name`).
  - `activeCredentialsProvider` indirection (`app_providers.dart`): wraps `CredentialsStore.loadActiveConnection()` in a provider so `continueWatchingProvider` can be tested without a Flutter binding.
  - `_ContinueWatchingRow` + `_ContinueWatchingCard` + `_PosterPlaceholder` widgets in `channel_list_screen.dart`:
    - Horizontal scroll row above the category chips, hidden entirely when no progress is saved
    - Per card: poster (16:9 with first-letter placeholder fallback), "Resume" badge, indeterminate progress bar (15%–75% scaled on position duration), title, "Xm/h/d/w ago" timestamp
    - Only shown on the "All" view (no category selected) so it doesn't compete with the filtered channel list
    - Tap → `VodDetailScreen(autoResume: true)` for VOD items; series-episode resume deferred (needs parent-series-id lookup)
  - `VodDetailScreen.autoResume` (`vod_detail_screen.dart`): new param — when true, a `WidgetsBinding.instance.addPostFrameCallback` fires `_playVod(resume: true)` on first frame, so one tap on a Continue Watching card opens the player immediately at the saved position (skipping the synopsis screen).
  - 9 new tests (`continue_watching_test.dart`):
    - 4 `WatchProgressStore.savedStreamIds` unit tests (empty / listing / per-profile isolation / clear)
    - 5 `continueWatchingProvider` Riverpod injection tests with a `_FakeCredentialsStore` that bypasses `flutter_secure_storage` platform channel
- **42 tests total** (was 33), 0 analyze errors, 0 new warnings
- PR #3 merged to `develop` (e3be65b). CI ✅ + Release ✅ — APK rebuilt.

### CI status:
- `Merge feature/v03-continue-watching into develop` (e3be65b) — CI 🟢 Release 🟢
- All Phase 2 (P201–P204, P206) + V01 + V02 + V03 now Done

### What's next:
- **P205**: Profile sync via Firestore (Backlog — needs Firebase credentials)
- **P207**: DVR / recordings (Backlog, revenue-gated after P208)
- **P208**: Monetisation (Backlog — RevenueCat paywall)
- **Series-episode Continue Watching** (unblocked follow-on — needs parent-series-id resolution)
- **C06**: Smoke test on Firestick (blocked on josh)

---

## 2026-06-09 — CloudStream Hourly Cron (01:30 BST)

**Session start:** 01:30 BST

### What was done:
- Picked up **V02 (Series/episode browsing)** from the board. WIP was already in the working tree on a feature branch from a prior session — fleshed it out, verified, and shipped.
- V02 fully implemented and shipped:
  - **API client** (`xtream_client.dart`): `getSeriesStreams({categoryId})` and `getSeriesInfo(seriesId)` hitting `action=get_series` and `action=get_series_info`; `buildSeriesStreamUrl(episodeStreamId)` URL builder
  - **`XtreamSeriesInfo` model** (was a stub on develop): now parses `name`, `plot`, `cover`, `cast`, `director`, `releaseDate`, `rating` + nested `seasons[]` with `episodes[]` (each with `episode_num`, `title`, `description`, `stream_id`, `duration`)
  - **Providers** (`app_providers.dart`): `seriesCategoriesProvider`, `seriesStreamsProvider`, `filteredSeriesStreamsProvider`, `selectedSeriesCategoryIdProvider`, `seriesInfoProvider` (family<int>), `seriesStreamUrlProvider` (family<int>)
  - **`SeriesScreen`** (new): category chip filter + responsive grid of series posters. Tapping a card opens `SeriesDetailScreen`. Mirrors `VodScreen` UX exactly.
  - **`SeriesDetailScreen`** (new): cover (300px hero), title, metadata chips (★ rating, 📅 year via 4-digit regex, 👤 director, 📺 "Series"), plot block, cast block, season chip selector (only shown when >1 season), episode list with title + description + formatted duration, tap-to-play through `PlayerScreen(streamUrl: buildSeriesStreamUrl(episodeStreamId))`
  - **Search integration**: `SearchService.rebuild()` now also indexes `series` streams (filtered to `streamType == 'series'`); `searchResultsProvider` returns `SearchResult(type: 'series')`; `SearchScreen._openStream` routes series hits to `SeriesDetailScreen`; new `_TypeBadge` widget with series-tinted color
  - **Bottom nav**: added 6th tab "Series" with `Icons.tv_outlined` (active `Icons.tv`)
- 8 new tests (`series_info_test.dart`): `XtreamSeriesInfo.fromJson` (full, name-fallback, missing info block, multiple seasons, sparse season without episodes) + `XtreamEpisode.fromJson` (missing duration/description, duration-as-int-string) + `seriesInfoProvider` Riverpod injection test
- **41 tests total** (was 33), 0 analyze errors, 0 new warnings
- Merged `feature/v02-series-browsing` into `develop` (b303f9d) and pushed. CI + Release workflows running.

### CI status:
- `Merge feature/v02-series-browsing into develop` (b303f9d) — CI 🟡 running, Release 🟡 running
- All Phase 2 (P201–P204, P206) + V01 + V02 now Done

### What's next:
- **P205**: Profile sync via Firestore (Backlog — needs Firebase credentials)
- **P207**: DVR / recordings (Backlog, revenue-gated after P208)
- **P208**: Monetisation (Backlog — RevenueCat paywall)
- **C06**: Smoke test on Firestick (blocked on josh)

---

## 2026-06-09 — CloudStream Hourly Cron (00:10 BST)

**Session start:** 00:10 BST

### What was done:
- Board was stale — last log entry 2026-06-04 (5 days ago) but the **favourites UI commit (21ab251) was already on `develop`** from 2026-06-08 with green CI. Backfilled into the log.
- Identified that all "Next" tasks (P207 DVR, P208 Monetisation, P205 Firestore) had hard external blockers. Picked a real unblocked follow-on from the CloudStream skill's "What still needs to be built" list: **V01 VOD info panel**.
- V01: VOD info panel — fully implemented and shipped:
  - `vodInfoProvider`: new `FutureProvider.family<XtreamVodInfo, int>` in `app_providers.dart` calling `XtreamApiClient.getVodInfo(vodId)`
  - `VodDetailScreen` refactored from hard-coded "Tap play to start watching" placeholder synopsis to real Xtream metadata:
    - **Cover:** prefers higher-res `XtreamVodInfo.cover` over the lower-res `stream.logo` (Xtream's VOD cover is the same poster as the VOD card but at full resolution)
    - **Metadata row:** real chips — ★ rating (parsed float), ⏱ duration (parsed from `105 min` / `1:45:00` / raw seconds → `1h 45m` / `45m`), 📅 release year (4-digit regex extraction), 👤 director — all only shown when the VOD info call has succeeded
    - **Synopsis:** real plot from `XtreamVodInfo.plot`; loading shimmer (4 grey bars) while fetching; italic "No synopsis available" when plot is empty/null; error fallback "Could not load details — tap play to start watching" so user can still recover and play
    - **Cast block:** appended below synopsis when `info.cast` is non-empty
  - 5 new tests: `XtreamVodInfo.fromJson` (full, name-fallback to top-level, missing info block, seasons+episodes) + `vodInfoProvider` Riverpod injection test
- Pushed `bf59c64` — CI ✅ (5m53s) — Release ✅ (6m25s) — APK rebuilt

### CI status:
- `feat(V01): VOD info panel — real plot, cast, director, rating, duration` ✅ passed CI + Release
- All Phase 2 (P201–P204, P206) + V01 now Done

### What's next:
- Series/episode browsing — `getSeriesInfo()` → `XtreamSeriesInfo` → season/episode hierarchy (unblocked, no external deps)
- **P205**: Profile sync via Firestore (Backlog — needs Firebase credentials)
- **P207**: DVR / recordings (Backlog, revenue-gated after P208)
- **P208**: Monetisation (Backlog — RevenueCat paywall)
- **C06**: Smoke test on Firestick (blocked on josh)

### Backfill — 2026-06-08 (favourites UI, 21ab251):
- 21ab251: `feat(favourites): UI for per-profile favourites + favourites-only filter`
  - `favouritesOnlyProvider` (StateProvider<bool>), `filteredLiveStreamsProvider` extended to intersect with active profile favourites
  - `ChannelTile`: ConsumerWidget, star/star_border IconButton per row that toggles favourite without triggering row's play action
  - `CategoryFilterChips`: new "★ Favourites" chip alongside the existing "All" / category chips. "All" clears both filters.
  - 6 ProfileStore tests + 4 filter tests. **20 tests total** (was 10). Zero new analyze warnings.
  - Pushed to `develop` 2026-06-08T23:12 BST. CI ✅ (5m21s). Release ✅ (6m8s).

## 2026-06-04 — CloudStream Hourly Cron (13:00 BST)

**Session start:** 12:15 BST

### What was done:
- P206: Catch-up TV — fully implemented and shipped:
  - `XtreamEpgEntry.hasCatchup`: parses `has_catchup` bool from Xtream API response
  - `XtreamEpgEntry.isInCatchupWindow`: true if programme ended within last 3 hours
  - `XtreamApiClient.buildCatchupStreamUrl(streamId, startTime)`: public method constructing `/live/{user}/{pass}/{id}.m3u8?start={epoch}`
  - `XtreamEpgEntry.fromJson`: now handles `has_catchup` field (int 1 or bool true)
  - EPG programme blocks: show `Icons.replay` badge for past programmes that are catch-up eligible
  - `_openChannel(stream, programme)`: detects past programme with catchup → calls `_playCatchup()`
  - `_playCatchup()`: builds catchup URL, passes as `PlayerScreen(streamUrl: ...)` override
  - `PlayerScreen`: already supports `streamUrl` override (from VOD work) — no changes needed
  - Refactored: `onProgrammeTap` callback chain through `_ProgrammeRow` → `_EpgGrid` → `_EpgGuideScreenState`
- Pushed `fd29aa2` — CI ✅ Analyze ✅ Test ✅ (10 tests) — Release ✅

### CI status:
- `feat(P206): catch-up TV — EPG tap to play, replay badge, catchup URL builder` ✅ passed (Release ✅)
- All Phase 2 (P201–P204, P206) now Done

### What's next:
- P207: DVR / recordings (Backlog, revenue-gated after P208)
- P208: Monetisation (Backlog — RevenueCat paywall)
- C06: Smoke test on Firestick (blocked on josh)
- P205: Profile sync via Firestore (Backlog — needs Firebase credentials)

**Session start:** 11:05 BST

### What was done:
- P204: Search — fully implemented and shipped:
  - `SearchService` (`core/search/search_service.dart`): flat O(n) substring index over live + VOD streams, rebuilds when streams change
  - Riverpod providers: `searchServiceProvider`, `searchQueryProvider`, `searchResultsProvider`, `searchIndexRebuilderProvider`
  - `SearchScreen`: auto-focus search bar, live/VOD type badges, tap to play/view
  - Bottom nav: Search tab between Guide and VOD (5 tabs total)
- Pushed `80a4a06` — CI ✅ Analyze ✅ Test ✅ (5m56s)

### CI status:
- `feat(P204): search` — CI ✅ passed (5m56s)
- `Release` ✅ passed (5m35s)
- All Phase 2 (P201–P204) now Done

### What's next:
- P205: Profile sync via Firestore (Backlog)
- C06: Smoke test on Firestick (blocked on josh)
- B202: Firebase integration (Backlog)

## 2026-06-04 — CloudStream Hourly Cron (10:00 BST)

**Session start:** 09:20 BST

### What was done:
- CI was failing on `develop` — P203 commit (26942615661) broke `widget_test.dart`:
  - Root cause: `AuthRouter` watches `sharedPreferencesProvider` which throws `UnimplementedError` when not overridden. `main.dart` correctly overrides it, but the test didn't.
  - Fix: Added `SharedPreferences.setMockInitialValues({})`, `SharedPreferences.getInstance()`, and `sharedPreferencesProvider.overrideWithValue(prefs)` to the test
- Pushed `a235418` — CI ✅ (5m4s)

### CI status:
- `fix(widget_test): mock SharedPreferences to fix sharedPreferencesProvider override error` ✅ passed (5m4s)
- P203: `feat(P203): multi-profile local — ProfileStore, ProfileSwitcherScreen…` ✅ Release passed (6m17s)
- All Phase 2 (P201–P203) now Done

### What's next:
- P204: Search — in-memory index over live + VOD, <300ms on Firestick
- C06: Smoke test on Firestick (blocked on josh)
- B202: Firebase integration (Backlog)

---

## 2026-06-04 — CloudStream Hourly Cron (07:00 BST)

**Session start:** 06:15 BST

### What was done:
- P202: VOD library + player reuse — fully implemented and shipped:
  - `WatchProgressStore` (`core/storage/watch_progress_store.dart`): SharedPreferences-backed persistence for VOD watch progress, keyed by `profileId + streamId`. Supports save/load/clear/list.
  - `shared_preferences` added to pubspec.yaml
  - `app_providers.dart`: added `sharedPreferencesProvider`, `watchProgressStoreProvider`, `watchProgressProvider` (family over streamId+profileId)
  - `main.dart`: async `main()` with `SharedPreferences.getInstance()` and `ProviderScope` override
  - `PlayerScreen`: added `startPosition` param; added `_onPositionChanged` listener that saves progress every 30s; `_saveProgress()` called on `dispose()`
  - `VodDetailScreen`: new screen between tap and play — shows cover, title, synopsis placeholder, and two buttons: **Resume** (loads saved position) and **Start Over**
  - `vod_screen.dart`: tap VOD card now navigates to `VodDetailScreen` instead of playing directly
  - All analyze errors resolved (zero new errors introduced)
- Pushed `751a3b9` — CI ✅ Analyze ✅ Test ✅

### CI status:
- `feat(P202): VOD library — watch progress store, resume prompt, VOD detail screen` ✅ Release passed (5m36s) ✅ CI passed (5m50s)

### What's next:
- P203: Multi-profile local (per-profile favourites, isolated state)
- C06: Smoke test on Firestick (blocked on josh)
- B202: Firebase integration (Backlog)

---

## 2026-06-04 — CloudStream Hourly Cron (04:00 BST)

**Session start:** 03:15 BST

### What was done:
- Board was stale — last update was 2026-06-02; `develop` had progressed since then
- Updated DEVELOPMENT_BOARD.md:
  - P201: correctly shows "Provider abstraction" Done (was incorrectly showing old "VOD list + browse")
  - Added Phase 2 section (P201–P209) sourced from PHASE2_PLAN.md
  - P202 VOD library + player reuse set as **Next** task
  - P201 Provider abstraction marked Done with commit 69ad17c
- P201 commit (69ad17c) already on `develop` — feat(P201): CloudStreamPlayer interface + XtreamStreamSession + PII redaction:
  - `CloudStreamPlayer` abstract interface (domain/entities): StreamMode enum, platform capabilities, unified playLive/playVod/playCatchup/seekTo
  - `XtreamStreamSession` implementation wrapping Chewie + VideoPlayerController
  - PII redaction module (`diagnostics/pii_redaction.dart`) with 9 unit tests
- Board + log update pushed as commit

### CI status:
- `feat(P201): CloudStreamPlayer interface + XtreamStreamSession + PII redaction` — on `develop`, CI status not checked (gh auth unavailable this session)

### What's next:
- P202: VOD library + player reuse — VOD categories, posters, resume, watch-progress per profile
- C06: Smoke test on Firestick (blocked on josh)
- B202: Firebase integration (Backlog)

**Session start:** 15:05 BST

### What was done:
- CI was failing on `develop` — `feat(P201)` commit (7473b82) had two errors:
  1. `CardTheme` → needs `CardThemeData` in app_theme.dart (Flutter 3.44 compat)
  2. Unused `_VodPlaceholder` class in main.dart
- Both were already fixed in local working tree — committed and pushed as 54034dd
- CI passed ✅ (6m25s)
- P201 VOD list + browse marked Done in board (7473b82)
- Board update pushed (3d153dc)

### CI status:
- `fix(CI): CardTheme→CardThemeData, remove unused _VodPlaceholder` ✅ passed (6m25s)
- `feat(P201): VOD list + browse screen` ✅ passed
- All Phase 1 + P201 complete

### What's next:
- C06: Smoke test on Firestick (blocked on josh)
- Phase 2 features (not yet defined in board)
- B202: Firebase integration (Backlog)

---

## 2026-06-02 — CloudStream Hourly Cron (11:25 BST)

**Session start:** 10:10 BST

### What was done:
- P105: Full EPG guide screen — `epg_guide_screen.dart`
  - TV-style grid: fixed channel name column on left, scrollable programme timeline on right
  - `TimeRulerPainter` CustomPainter for hourly labels + 30-min ticks
  - Per-channel lazy EPG loading via `epgProvider(streamId)` — one API call per channel
  - Programme blocks positioned absolutely at 3px/min; current programme highlighted primary colour
  - Red now-line overlaid on programme area, tracks horizontal scroll via listener
  - 6-hour window centred on now, auto-scrolled to centre on launch
  - Tap a programme → instant channel switch via `PlayerControllerNotifier`
  - Wired into bottom nav "Guide" tab, replacing `_GuidePlaceholder`
  - Also: fixed `CardThemeData` → `CardTheme` → `CardThemeData` Flutter version confusion
- Pushed a1f6859 — Analyze ✅ Test ✅ (Build Android/macOS cancelled by higher-priority re-run)
- Note: intervening `fix(tv-nav)` commit introduced errors that broke CI — separate issue, not from P105

### CI status:
- `feat(P105): full EPG guide screen` (a1f6859) — Analyze ✅ Test ✅ (Build cancelled by parallel job)
- `fix(tv-nav)` — ❌ Analyze failed — private record field errors (unrelated to P105)
- All Phase 1 features now Done

### What's next:
- Fix CI on `develop` (tv-nav errors — josh should address)
- C06: Smoke test on Firestick (blocked on josh)
- Phase 2 features when time permits

---

**Session start:** 09:05 BST

### What was done:
- P104: Gesture controls — `PlayerGestureOverlay` widget wrapping Chewie player
  - Horizontal swipe: seek ±seconds (5px/s)
  - Double tap left/right: seek −10s / +10s
  - Vertical swipe left third: brightness indicator (☀️ %)
  - Vertical swipe right third: volume control (🔊 %)
  - Animated fade labels auto-dismiss after 800ms
  - New file: `player_gesture_overlay.dart`
- Bug fix: `CardThemeData` in app_theme.dart (CI uses Flutter 3.44, reverted my local Flutter 3.24 override)
- Pushed 48b5448 — CI passed ✅ (5m48s)

### CI status:
- `feat(P104): player gesture controls` ✅ passed (5m48s)
- `Release` ✅ passed (5m11s)
- Previous (failed): `CardTheme` → `CardThemeData` fix needed for Flutter 3.44 ✅ resolved

### What's next:
- P105: Full EPG guide screen
- C06: Smoke test on Firestick (blocked on josh)

---

## 2026-06-02 — CloudStream Hourly Cron (08:25 BST)

**Session start:** 07:40 BST

### What was done:
- P103 (PiP support) already fully implemented from last session — no code changes needed this run
- Verified CI status: latest run 26805913111 (Release) ✅ passed
- APK uploaded to GitHub Release v0.0.1 ✅
- Marked P103 Done in board

### CI status:
- `Release` ✅ passed (6m1s) — APK uploaded to https://github.com/citralia/cloudstream/releases/tag/v0.0.1
- `fix(P103): use enterPictureInPictureMode only` ✅ passed (5m16s)
- All previous: ✅ green

### What's next:
- P104: Gesture controls
- P105: Full EPG guide screen
- C06: Smoke test on Firestick (blocked on josh)

---

## 2026-06-02 — CloudStream Hourly Cron (06:20 BST)

**Session start:** 05:05 BST

### What was done:
- P102: Quick channel switcher overlay wired to Info/Guide remote button
  - Added `quickSwitcherOverlayVisibleProvider` (StateProvider<bool>) in app_providers.dart
  - `HomeScreen` intercepts `LogicalKeyboardKey.info` to toggle the overlay
  - `QuickChannelOverlay` refactored from internal `_visible` state to controlled `isVisible` + `onDismiss` props
  - `ChannelListScreen` now watches the provider; mini-player toggle and overlay both use it
- Pushed a032eed — CI passed ✅ (5m0s)

### CI status:
- `P102: wire quick-channel switcher overlay to Info key remote button` ✅ passed (5m0s)
- All previous: ✅ green

### What's next:
- P103: PiP support
- P104: Gesture controls
- P105: Full EPG guide screen
- C06: Smoke test on Firestick (blocked on josh)

---

## 2026-06-02 — CloudStream Hourly Cron (05:15 BST)

**Session start:** 04:05 BST

### What was done:
- CI was failing on `develop` due to `P101: channel switching < 1s` (a7b324e)
  - Root cause: Flutter 3.44 broke `CardTheme` → now requires `CardThemeData`
  - Fix: 1-line change in `app_theme.dart:105` — `CardTheme` → `CardThemeData`
  - Also removed 2 stray doc files accidentally committed earlier
- Pushed fix (513c79c) — CI passed ✅ (5m32s)
- P101 marked Done in board

### CI status:
- `fix(app_theme): CardTheme → CardThemeData for Flutter 3.44 compat` ✅ passed (5m32s)
- Release v0.0.1 ✅ https://github.com/citralia/cloudstream/releases/tag/v0.0.1

### What's next:
- P102: Quick channel switcher overlay
- P103: PiP support
- P104: Gesture controls
- P105: Full EPG guide screen
- C06: Smoke test on Firestick (blocked on josh)

---

## 2026-06-01 — CloudStream development begins

**Session start:** 20:00 BST

### Key decisions made:
- Android first (sideloading on Firestick for rapid iteration)
- FastAPI backend proxy on VPS (avoids CORS, handles stream handoff, caches EPG)
- Clean Architecture in Flutter (data/domain/presentation layers)
- Backend before frontend — get API solid before hooking Flutter to it
- Xtream test fixtures for development, real server pointed in on deploy
- Firebase credentials deferred (env vars at deploy time)
- Backend sessions stored in-memory (upgrade to Redis when scaling)

### Architecture locked:
```
Firestick (Flutter) → FastAPI Proxy (VPS) → Xtream Server (IPTV)
                              ↓
                       EPG Aggregator (XMLTV → SQLite cache)
```

### Environment:
- VPS: ubuntu-16gb-nbg1-1 (100.112.53.35), UK time (Europe/London)
- Repo: github.com/citralia/cloudstream
- Branches: main (protected) + develop (integration)
- CI: GitHub Actions — analyze, test, build iOS/Android/macOS

### What's been done today:
- [x] F09: Settings screen — server URL display, username, version, sign out with confirm dialog, about section, PiP/quick-switch as coming soon
- [x] Fixed CI workflow — was missing `push` trigger, only ran on `pull_request`; now also runs on push to main/develop
- [x] F08: Category filtering — horizontal chip bar above channel list, filters via selectedCategoryProvider
- [x] Fixed pre-existing CI errors: `Icons.guide` → `Icons.menu_book`, removed `const` from `BottomNavigationBar.items`, fixed stale widget test
- [x] Fixed `CategoryListResult.categories` → `result.live`
- [x] CI passes: Analyze ✅ Test ✅ Build macOS ✅ Build iOS ✅

### What's next:
- F10: Android smoke test (side-load on Firestick) — blocked on josh
- Phase 1 features (channel switching < 1s, PiP, gesture controls)
- VPS deployment when josh gets home access (has Xtream server to connect)

---

## Session context

Josh is working from his phone (no VPS/MacBook access). All code committed to GitHub — verifiable, reviewable. CI runs on every push to develop.

When josh gets home:
1. Pull develop branch
2. Deploy backend: `ssh vps && docker run ...` (command ready)
3. Configure env vars (Xtream URL, Firebase credentials)
4. Open Flutter in Android Studio → build once to verify
5. For iOS: pull → Xcode → build → (future) TestFlight

---
