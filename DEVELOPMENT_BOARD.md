# CloudStream — Development Board

> Last updated: 2026-06-09T13:30:00+01:00

## Architecture Decision (2026-06-01)

> **Previous error:** Built backend as sessionful Xtream proxy — wrong. Backend stored credentials, proxied all Xtream calls.
>
> **Correct architecture:** App → Xtream server directly. No backend involvement in IPTV operations. Credentials stored on-device in flutter_secure_storage.
>
> **ADR-004 and ONBOARDING.md are authoritative.** Backend serves no purpose for IPTV flow.

---

## Legend
| Status | Meaning |
|--------|---------|
| **Next** | Queued, next to pick up |
| **In Progress** | Active work, owned |
| **In Review** | Code written, testing/verification |
| **Done** | Merged, verified, shipped |
| **Backlog** | Not yet started |

---

## Phase 0 — Foundation (corrected)

### Flutter App — Direct Xtream Architecture

| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| F01 | Flutter project clean structure | Done | agent | Clean Architecture dirs, pubspec with deps |
| F02 | Design tokens + app theme | Done | agent | AppTheme dark + AppColors, AppTypography, AppSpacing; **AppTheme.light + LightAppColors/LightAppTypography added in V08 (4bb8f44) — light + dark themes now both first-class** |
| F03 | Xtream data models | Done | agent | Channel, Programme, Category, User entities + DTOs |
| F04 | Xtream API client | Done | agent | Dio ApiClient + CloudStreamRemoteDataSource |
| F05 | Login screen | Done | agent | Form validation, Xtream auth flow |
| F06 | Channel list screen | Done | agent | Grouped by category, channel tiles with logos |
| F07 | Video player (Chewie/HLS) | Done | agent | PlayerScreen with Chewie, EPG now/next overlay |
| F08 | Category filtering | Done | agent | Category chips, filtered channel list |
| F09 | Settings screen | Done | agent | Server URL display, logout with confirm, about section |
| F10 | Android build smoke test | Blocked | josh | Side-load on Firestick |

### Correct Architecture — Flutter (pending rebuild)

| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| C01 | Strip backend proxy from Xtream client | Done | agent | App → Xtream direct, no backend in middle — XtreamApiClient via Riverpod, CloudStreamRemoteDataSource dead code |
| C02 | flutter_secure_storage integration | Done | agent | CredentialsStore with flutter_secure_storage — done |
| C03 | Add Playlist screen | Done | agent | PlaylistScreen + _ConnectionFormSheet — done in b68eacc |
| C04 | Connection management | Done | agent | Multi-profile support via CredentialsStore — done in b68eacc |
| C05 | Rebuild APK with direct Xtream | Done | agent | GitHub Release v0.0.1 — APK uploaded, direct Xtream architecture |
| C06 | Smoke test on Firestick | Blocked | josh | Verify login, channels, playback |

### Backend — Obsolete (IPTV layer)

| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| B01-B08 | Sessionful proxy layer | **Obsolete** | — | Killed 2026-06-01 — wrong architecture |

### Backend — Minimal Future Use (Phase 2+)

| # | Task | Status | Notes |
|---|------|--------|-------|
| P201 | Provider abstraction | **Done** | CloudStreamPlayer interface + XtreamStreamSession + PII redaction — 69ad17c |
| B202 | Firebase integration | Backlog | Analytics, crashlytics, app distribution |

---

## Phase 2 — Provider Abstraction + Multi-Profile

| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| P201 | Provider abstraction (CloudStreamPlayer + XtreamStreamSession) | **Done** | agent | CloudStreamPlayer interface, XtreamStreamSession impl, PII redaction — 69ad17c |
| P202 | VOD library + player reuse | **Done** | agent | WatchProgressStore via SharedPreferences, VodDetailScreen with resume/start-over, PlayerScreen saves position every 30s — 751a3b9 |
| P203 | Multi-profile local | **Done** | agent | ProfileStore, ProfileSwitcherScreen — 26942615661 ✅ |
| P204 | Search | **Done** | agent | In-memory index over live + VOD, SearchScreen in bottom nav — 80a4a06 |
| P205 | Profile sync via Firestore | Backlog | agent | Mirror favourites/watch-progress, server-side cred encryption |
| P206 | Catch-up TV | **Done** | agent | Xtream catch-up HLS, seek via EPG tap — replay badge, _openChannel detects past programme → buildCatchupStreamUrl → PlayerScreen(streamUrl) |
| P207 | DVR / recordings | Backlog | agent | Cloudflare R2 only, revenue-gated after P208 |
| P208 | Monetisation | Backlog | agent | RevenueCat paywall on multi-profile + sync + catch-up |
| P209 | Cast + multi-screen | Backlog | agent | AirPlay + Cast + PiP orchestration |
| V01 | VOD info panel | **Done** | agent | vodInfoProvider + VodDetailScreen: real plot, cast, director, rating, duration, higher-res cover, loading shimmer + error fallback — bf59c64 |
| V02 | Series/episode browsing | **Done** | agent | getSeriesStreams + seriesInfoProvider + SeriesScreen + SeriesDetailScreen (season selector, episode list, tap-to-play via buildSeriesStreamUrl); 8 new tests, 41 total, 0 analyze errors — 7d51715 |
| V03 | Continue Watching row | **Done** | agent | continueWatchingProvider + _ContinueWatchingRow on Live TV home — joins saved watch-progress streamIds against VOD/series lists, sorts by updatedAt, hidden when empty, 9 new tests, 42 total — e3be65b |
| V04 | Series-episode Continue Watching | **Done** | agent | SeriesInfoCache (lazy LRU) + reverse-lookup: saved episode stream_id → (parent series, season, episode). ContinueWatchingEntry.kind = vod|seriesEpisode. SeriesDetailScreen.autoResumeEpisode opens right season, plays via post-frame callback, reads saved position. _openResume routes series_episode entries to SeriesDetailScreen. 9 new tests, 51 total. **Merged to develop (b9f193c) — CI ✅ + Release ✅.** |
| V05 | Most Watched home row | **Done** | agent | PlayCountStore (SharedPreferences-backed, per-profile, key `play_count_{profileId}_{streamId}`), player_screen _saveProgress bumps count every 30s + dispose, mostWatchedProvider joins counts with liveStreamsProvider (drops orphans, awaits live), _MostWatchedRow on home above Continue Watching with N× badge. 13 new tests, 64 total. **Merged to develop (6178768) — CI ✅ + Release ✅ + v0.1.22.** |
| V06 | Channel list sort modes | **Done** | agent | ChannelSortMode enum + ChannelSortStore (SharedPreferences), channelSortProvider + filteredLiveStreamsProvider re-sort, AppBar sort-icon → _SortModeSheet (Default / Name A–Z / Number — null-num entries to bottom). 12 new tests, 76 total. **Merged to develop (c4f8107) — CI ✅ + Release ✅.** |
| V07 | EPG reminders | **Done** | agent | V07 chunk 1 (b42f8d4) + V07 chunk 2 (e9913a0) + V07 chunk 3 (d08174b) all merged. Chunk 1: data layer + EPG long-press toggle + bell-icon. Chunk 2: RemindersListScreen (swipe-to-delete, empty state, schedule formatting), Settings lead-time picker (bottom sheet, 0/1/5/10/15/20/25/30/45/60 min), defaultLeadTimeProvider wired through RemindersNotifier.add. Chunk 3: flutter_local_notifications wiring — ReminderScheduler interface + LocalNotificationsReminderScheduler impl + reminderSchedulerProvider override, Android POST_NOTIFICATIONS / SCHEDULE_EXACT_ALARM / RECEIVE_BOOT_COMPLETED perms + ScheduledNotificationBootReceiver + core-library desugaring + multiDex, iOS requestPermissions via resolvePlatformSpecificImplementation, schedule on add / cancel on remove / rehydrate on cold start, requestPermission() on first add, profile-scoped rehydrate drops other profiles' reminders. 6 new tests (add→schedule+permission, remove→cancel, re-add after remove, rehydrate scope, missing-scheduler tolerance, other-profile drop), 104 total. **Merged to develop (d08174b) — CI ✅ + Release ✅.** |
| V08 | Light theme + Settings theme picker | **Done** | agent | LightAppColors / LightAppTypography token classes mirror dark AppColors / AppTypography field-for-field; AppTheme.light ThemeData pulls every value from light tokens; MaterialApp picks AppTheme.dark vs AppTheme.light at runtime via themeModeProvider (no restart); ThemePreferencesStore (SharedPreferences-backed persistence, system default + forward-compat fallback); Settings → Appearance tile + bottom sheet picker (Dark / Light / Follow system) writes through to themeModeProvider. **Scope intentionally narrow** — existing screens still hardcode AppColors / AppTypography, so a 'pick Light' smoke test only flips Material widgets (tooltips, dialogs, scrollbars); a full per-screen migration to a brightness-aware context is a deliberate follow-on. 11 new tests (store persistence + system-default + unknown-fallback + provider reads-persisted + provider in-memory mirror + cross-container persistence + AppTheme.dark/light sanity), 115 total. **Merged to develop (4bb8f44) — CI ✅ + Release ✅.** |
| V09 | Most Watched sort mode | **Done** | agent | ChannelSortMode.mostWatched — extends V06 (channel list sort modes) with a 4th option. Reuses PlayCountStore (V05) for per-profile isolation: live channels ordered by play count desc, ties broken by name (case-insensitive asc), unplayed streams pushed to the bottom and sorted by name as a stable secondary key. filteredLiveStreamsProvider reads counts for the active profile when mostWatched is selected; _applyChannelSort extended with optional playCounts map; _SortModeSheet gets new "Most Watched" row with trending_up icon. Degrades to default order if no active connection. Composes with the existing category and favourites-only filters. 9 new tests (ordering, ties, unplayed bucket, no-counts default, no-connection degrade, composes with category + favourites, per-profile isolation, runtime re-sort), 124 total. 0 new analyze errors. **Merged to develop (301b168) — CI ✅ + Release ✅ on docs commit 49b37b8.** |
| V10 | Persist reminder lead time | **Done** | agent | Closes the V08-cron "defaultLeadTimeProvider doesn't persist" gap. LeadTimePreferencesStore (SharedPreferences-backed, single key `reminder_default_lead_minutes`, minute-granular) mirrors ThemePreferencesStore (V08). `defaultLeadTimeProvider` now reads `store.load()` on first read instead of the hard-coded 5-min default; Settings `_LeadTimeTile.onTap` writes through to both the in-memory provider and the store. Forward-compat fallback to 5 min on missing/invalid/negative stored values. 8 new tests (4 store: defaults-to-5, round-trip 10 picker options, negative-value fallback, missing-key fallback; 4 provider: reads-persisted, fresh-install, in-memory-doesn't-overwrite-persisted, store.save observable from fresh container), 132 total. 0 new analyze errors. **Merged to develop (931ff60) — CI ✅ (6m04s) + Release ✅ (10m54s).** |
| V11 | Brightness-aware context tokens (extension + login + tv_text_field) | **Done** | agent | `ThemeTokens` extension on `BuildContext` returns brightness-resolved `AppColorTokens` / `AppTypographyTokens` (separate dark/light impls that match the existing `AppColors` / `LightAppColors` / `AppTypography` / `LightAppTypography` field-for-field). Login + `tv_text_field` (used by login + playlist connection form) migrated. 9 new tests (6 extension sanity + 3 login renders in dark/light/auth-error), 141 total. **Merged to develop (23243dd / d058e78) — CI ✅ + Release ✅.** |
| V12 | Brightness-aware migration chunk 2 (settings + 4 more screens) | **Done** | agent | Continues V11: settings_screen, profile_switcher_screen, debug_logs_screen, reminders_list_screen, search_screen all now pull every colour / text-style through `context.appColors` / `context.appTypography`. 8 new tests (one per migrated screen × 2 themes, 149 total). All migrated screens now render correctly in both dark and light themes. **Merged to develop (f9cd4ed) — CI ✅ (6m22s) + Release ✅ (6m40s) + v0.1.38.** |
| V13 | Brightness-aware migration chunk 3 (main.dart shell + channel_list_screen) | **Done** | agent | Largest remaining gap in the V08/V11/V12 migration. Migrated `main.dart`'s `_HomeScreen` + `_TvNavBar` + `_NavBarItem` (the bottom-nav shell, 4 sites) and the entire `ChannelListScreen` (the home tab — 50+ call sites across Scaffold, ChannelTile, _FavouriteButton, _GroupedChannelList, CategoryFilterChips, _FilterChip, _ContinueWatchingRow + _Card, _PosterPlaceholder, _MostWatchedRow + _Card, _MiniPlayerBar, _SortModeSheet + _Row). All `AppColors.X` / `AppTypography.X` references are now `context.appColors.X` / `context.appTypography.X`. 2 new tests (`brightness_aware_chunk3_test.dart`, one per theme — channel-list Scaffold bg asserts to `LightAppColors.background` / `AppColors.background`, proving the migration is wired not falling back to a dark constant), 151 total. 0 new analyze errors. Test approach follows V12 pattern: render `ChannelListScreen` standalone (pumping `HomeScreen` would also pump the other 5 tabs via `IndexedStack` — EpgGuide / Search / VOD / Series / Settings — each needing its own fixture; standalone is sufficient to prove the migration pulls brightness-correct tokens). Bottom-nav shell migration is a 4-site trivial change with no new logic — covered by the source migration + 0 analyze issues. **Merged to develop (2d06ec7) — CI ✅ (5m56s) + Release ✅ on docs commit 5d6ba5e (CI 6m31s + Release 11m27s) → v0.1.41.** |

---

> Last updated: 2026-06-09T22:25:00+01:00

---

## Phase 1 — Core Player

| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| P101 | Channel switching < 1s | Done | agent | Persistent player + quick switcher overlay (a7b324e) — CI fixed: CardTheme→CardThemeData (513c79c) |
| P102 | Quick channel switcher overlay | Done | agent | Wired to Info/Guide remote button via quickSwitcherOverlayVisibleProvider (a032eed) |
| P103 | PiP support | Done | agent | Android PiP via platform channel — APK in v0.0.1 release |
| P104 | Gesture controls | Done | agent | PlayerGestureOverlay — swipe seek, double-tap ±10s, vertical vol/brightness (48b5448) |
| P105 | Full EPG guide screen | Done | agent | TV-style grid with fixed channel column + scrollable timeline — a1f6859 — Analyze ✅ Test ✅ |

---

## iOS (deferred — full build on Mac)

| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| I01 | Flutter iOS target config | Done | agent | scaffolded |
| I02 | Native iOS signing + provisioning | Backlog | josh | Mac only |
| I03 | TestFlight deployment | Backlog | josh | Mac + Apple account |

---

## Blockers

| Blocker | Impact | Resolution |
|---------|--------|------------|
| No MacBook | iOS build | CI validates, Mac verification when home |
| Firestick for smoke test | F10 | Downloader + GitHub Release URL |

---

## Infrastructure

| Service | Status | URL/Notes |
|---------|--------|-----------|
| Budget API | ✅ Running | http://100.112.53.35:8000 |
| CloudStream backend | ❌ Killed | Was on :8001 — wrong architecture |
| GitHub Releases | ✅ Live | https://github.com/citralia/cloudstream/releases |
| Flutter CI | ✅ Green | analyze + test on every push |
| Release workflow | ✅ Fixed | artifact paths, dart-define URL, public release |

---

## Notes

- Credentials: stored in flutter_secure_storage (iOS Keychain / Android Keystore)
- Stream URLs: `http://{server}/live/{user}/{pass}/{stream_id}.m3u8` — constructed by app
- Xtream API: called directly from Flutter, no backend relay
- Onboarding target: first channel playing in < 60 seconds
- Multi-connection: up to 5 profiles, one active at a time
