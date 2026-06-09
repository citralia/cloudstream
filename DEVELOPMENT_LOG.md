# CloudStream — Development Log

> Reverse chronological. Most recent entries at top.

---

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
