# CloudStream — Development Board

> Last updated: 2026-06-10T15:25:00+01:00

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
| V14 | Brightness-aware migration chunk 1 — VOD/series browsing | **Done** | agent | Migrates the 4 uniform VOD/series browsing surfaces to `context.appColors` / `context.appTypography` (same pattern as V11/V12/V13): `vod_screen.dart` (category chips + VOD grid), `series_screen.dart` (category chips + series grid), `vod_detail_screen.dart` (cover, metadata, synopsis, watch buttons), `series_detail_screen.dart` (cover, metadata, season chips, episode list). 8 new tests in `brightness_aware_chunk4_test.dart` (4 screens × 2 themes), one `testWidgets` per pair to avoid the loop-poisoning WidgetsBinding gotcha that bit V12. 159/159 tests pass (was 151), 0 new analyze errors. **Merged to develop (6f87792) — CI ✅ + Release ✅ pending.** |
| V14 | Brightness-aware migration chunk 2 — media-playback surfaces | **Done** | agent | Migrates the 4 remaining un-migrated media/playback surfaces to `context.appColors` / `context.appTypography`: `quick_channel_overlay.dart` (QuickChannelOverlay + ChannelNumberBar, 11 refs), `player_gesture_overlay.dart` (1 ref), `player_screen.dart` (Chewie progress colours, loading + error states, top-bar typography — keeps `Colors.white` on the video overlay; captures theme tokens pre-await in `_initializePlayer` to avoid `use_build_context_synchronously` on the Chewie `errorBuilder` closure, 14 refs), `epg_guide_screen.dart` (Scaffold bg, channel label cells, programme blocks, now-line, error/empty states — `_TimeRulerPainter` now takes `lineColor` / `textColor` / `halfLineColor` via constructor so the CustomPainter can pull brightness-correct tokens, 27 refs). 4 new tests in `brightness_aware_chunk5_test.dart` (QuickChannelOverlay stream-name text × 2 themes + ChannelNumberBar GO button bg × 2 themes — both migrated widgets are self-contained). PlayerGestureOverlay needs a real VideoPlayerController and PlayerScreen wraps Chewie with a native video surface — both don't pump cleanly in a unit test. EpgGuideScreen needs overrides for filteredLiveStreamsProvider + recentChannelsProvider + playerControllerProvider; the source migration + 0 new analyze issues covers it, same scoping trade-off V13 made. 163/163 tests pass (was 159, +4 from V14 chunk 2), 0 new analyze errors (still 50 pre-existing: 49 withOpacity infos + 1 V07-chunk3 unused-param warning). **Merged to develop (54fb180) — CI ✅ + Release ✅ → v0.1.45.** |
| V15 | Brightness-aware migration chunk 3 — playlist + player widgets | **Done** | agent | Closes the V14 "should be 0 remaining AppColors refs" claim — the prior cron's bookkeeping was off; the actual sweep found 32 refs across 3 still-un-migrated files. **`presentation/screens/playlist_screen.dart`** (20 refs): the connection-management screen accessed from Settings — the "No saved connections" empty state, the connection tiles (icon container + leading icon + title + subtitle + trailing chevron), the `Dismissible` swipe-to-delete background (red overlay + delete icon), the add-connection bottom sheet (handle bar + heading + button focus state), the focused `_TvButton` (background + border + glow), and all four snack-bar colours (switched / auth-failed / connection-failed / form-validation) are now brightness-correct. **`presentation/providers/player_controller_notifier.dart`** (6 refs): `_LoadingPlaceholder` and `_ErrorDisplay` widgets (the Chewie placeholder and error overlay) are now brightness-aware. The Chewie progress colours stay hardcoded to `AppColors.*` because the notifier's `setStream` runs without a `BuildContext` (the notifier is a `StateNotifier`, not a Widget); the progress bar lives on top of the black video surface, so the brightness-correct tokens wouldn't be visible anyway — same trade-off V14 chunk 2 made for `player_screen.dart`, documented in a code comment. **`presentation/players/xtream_stream_session.dart`** (6 refs): the `errorBuilder` callback now resolves brightness-correct tokens via its `BuildContext`. The `ChewieController` config block (progress colours + placeholder spinner) still hardcodes dark tokens for the same reason as the notifier file: `_initController` is a method on a non-Widget class, no `BuildContext` available, and those colours paint on top of the black video surface. 2 new tests in `brightness_aware_chunk6_test.dart` (PlaylistScreen dark/light bg), 165 total. 0 new analyze errors (still 50 pre-existing). **Merged to develop (8db2164) — CI ✅ + Release ✅ → v0.1.49.** |
| V16 | Recently Played channel sort mode | **Done** | agent | 5th sort option for the live TV channel list. Reuses `PlayCountStore` (V05) extended with a per-stream `lastPlayedAtMs` stamp (epoch ms) now written on every `increment` (called from `PlayerScreen._saveProgress` every 30s + dispose). New `ChannelSortMode.recentlyPlayed` reads the timestamp via the new `PlayCountStore.recentEntries(profileId)` (ordered by recency desc, ties broken by streamId asc). `_applyChannelSort` extended with a `lastPlayedAtMs:` named arg (mutex with the existing `playCounts:`). Unplayed streams pushed to the bottom and sorted by name asc; legacy v0.1.x–v0.1.48 entries (count but no last-played stamp) surface as epoch-0 via `recentEntries`. `_SortModeSheet` gets a 5th row (`Icons.history` + "Recently Played"). Degrades to default order when no active connection. Composes with category + favourites-only filters and per-profile isolation. 16 new tests (`recently_played_sort_test.dart` — 9 `PlayCountStore` unit tests + 7 sort-mode integration tests including a `mostWatched` vs `recentlyPlayed` re-rank on the same data). 181/181 pass (was 165), 0 new analyze errors (50 pre-existing). **Merged to develop (9178571, PR #4) — CI ✅ + Release ✅ → v0.1.50.** |
| V17 | Remove from Continue Watching long-press + UNDO | **Done** | agent | Long-press a Continue Watching card on home → action sheet → "Remove from Continue Watching" → row disappears + snackbar "Removed from Continue Watching" + UNDO action that re-adds the entry. 7 new tests in `remove_from_continue_watching_test.dart` (clear + invalidate, undo restores, multi-undo idempotent, missing-progress no-op). **Merged to develop (3d47a7b, PR #5) — CI ✅ + Release ✅ → v0.1.52.** |
| V18 | Hide channel long-press + Hidden filter chip | **Done** | agent | Mirrors the V05 favourites pattern for hiding unwanted channels from the live TV channel list, per profile. **`ProfileStore`** extended with `getHidden` / `setHidden` / `addHidden` / `removeHidden` / `toggleHidden` (SharedPreferences-backed, key `profile_{id}_hidden_channels`, JSON-encoded `List<int>`, idempotent, per-profile isolation). **`activeProfileHiddenProvider`** (Provider) + **`profileHiddenProvider`** (Provider.family) + **`hiddenOnlyProvider`** (StateProvider<bool>) + **`toggleHidden(ref, streamId)`** helper. `filteredLiveStreamsProvider` extended with hidden-channel filtering: default view excludes hidden, `hiddenOnly` reveals the hidden set only, `favouritesOnly` excludes hidden favourites. **UI**: `ChannelTile.onLongPress` → `_openChannelActions` modal bottom sheet with 'Hide channel' / 'Unhide channel' (visibility icon), snackbar "Hidden — \<name\>" + UNDO on hide, "Unhidden — \<name\>" (no UNDO) on unhide, new '⊘ Hidden' filter chip in `CategoryFilterChips`. The three filter modes (All / Favourites / Hidden) are mutex in the UI; the provider branches also enforce that — `hiddenOnly` wins over `favouritesOnly`. **17 new tests** (`hidden_channels_test.dart`): 8 `ProfileStore` persistence (empty default, round-trips, idempotency, per-profile isolation, rehydration) + 8 `filteredLiveStreamsProvider` filter (default excludes hidden, hiddenOnly reveals the set, empty hidden set, composes with category, composes with favourites, toggles) + 1 `toggleHidden` UNDO round-trip. 201/201 pass (was 181), 0 new analyze errors (50 pre-existing remain). **Merged to develop (0493388, PR #6) — CI ✅ (8m19s) + Release ✅ (6m32s) → v0.1.53.** |
| V19 | Manage hidden channels sheet — AppBar entry + per-row unhide + bulk unhide-all | **Done** | agent | Closes the V18 follow-on gap: until V19, the only way to unhide a channel was to flip to the 'Hidden' filter and long-press one row at a time — no bulk-unhide, no obvious discovery entry point. **`hiddenChannelsStreamProvider`** (`app_providers.dart`): joins active profile's hidden IDs against `liveStreamsProvider` (drops orphans, alphabetical, empty when no active profile). **`unhideAll(ref)`** helper: bulk-empty hidden set, returns count for snackbar copy. **`_ManageHiddenSheet`** (`channel_list_screen.dart`): modal bottom sheet, max-height 75%, visibility_off icon + title + 'Unhide all' button (only when non-empty), per-row logo-or-initial + name + 'Hidden' caption + trailing unhide IconButton, each row a `Dismissible(startToEnd)` with primary-tinted 'Unhide' background. **AppBar action**: new `Icons.visibility_off_outlined` IconButton (only when hidden count > 0) sits between Expand player and Sort channels — tooltip shows the count. Snackbar + UNDO on per-row unhide (mirrors V18 hide flow). **9 new tests** (`manage_hidden_sheet_test.dart`): hiddenChannelsStreamProvider (empty default, joins, drops orphans, alphabetical, empty no-profile, rebuilds on mutation) + unhideAll (empties, no-op empty, returns count). 210/210 pass (was 201, +9 from V19), 0 new analyze errors (50 pre-existing remain). **Merged to develop (15a3f4b, PR #7) — CI ✅ (6m22s) + Release ✅ (5m36s) → v0.1.54.** |
| V20 | Recently Played home row — discoverable recency on Live TV | **Done** | agent | Closes the V16 follow-on gap: V16 added the 'Recently Played' channel-list **sort mode** (recency-desc), but the recency ranking was only discoverable by switching sort modes. V20 surfaces it as a first-class **home row** above the Most Watched row. **`RecentlyPlayedEntry`** (`app_providers.dart`): resolved `XtreamStream` + `lastPlayedAtMs` epoch-ms timestamp. Mirrors `MostWatchedEntry`'s shape. **`recentlyPlayedProvider`** (FutureProvider): joins the active profile's `PlayCountStore.recentEntries(creds.name)` (recency desc, streamId-asc tie-breaker) against `liveStreamsProvider` (drops orphans), keyed by active connection's name for per-profile isolation. Awaits `liveStreamsProvider.future` (not `valueOrNull`) to avoid the first-tick-null trap. **`_RecentlyPlayedRow` + `_RecentlyPlayedCard`** (`channel_list_screen.dart`): horizontal row positioned **above** `_MostWatchedRow` (recency is a stronger personalisation signal than lifetime frequency). Card: 96×64 channel logo (or first-letter placeholder) + name + 'x min ago' / 'x h ago' / 'x d ago' / 'Just now' caption. Tap plays the channel. Hidden when the provider has no entries. Only shown when `selectedCategoryId == null` (same as Most Watched). Brightness-aware via `context.appColors` / `context.appTypography`. **9 new tests** (`recently_played_row_test.dart`): empty default, no-connection, no-live-streams degrade paths, recency-desc ordering, timestamp-tie streamId-asc tie-breaker, orphan drop, per-profile isolation, lastPlayedAtMs round-trip, recency-independent-of-play-count. 219/219 pass (was 210, +9 from V20), 0 new analyze errors (50 pre-existing remain). **Merged to develop (d42c771, PR #8) — CI ✅ (5m56s) + Release ✅ (6m16s) → v0.1.57.** |
| V21 | Continue Watching rows on VOD and Series tabs (split from channel-list) | **Done** | agent | Closes the V03/V04 follow-on gap: the Continue Watching row was only on the Live TV (channel-list) home tab. Users who start a movie or series episode on the VOD/Series tabs and switch tabs expect a 'resume' affordance there too. **`continueWatchingVodProvider`** + **`continueWatchingSeriesProvider`** (`app_providers.dart`): split providers that filter `continueWatchingProvider` by entry kind (`ContinueWatchingKind.vod` vs `ContinueWatchingKind.seriesEpisode`). Both `await` the source `.future` so a single `ref.invalidate(continueWatchingProvider)` cascades to both filters. **`_ContinueWatchingRow` on VOD tab** (`vod_screen.dart`): horizontal row above the VOD grid, only when `selectedCategoryId == null`. Card: poster (or placeholder) + title + progress bar + 'Resume' affordance. Tap → `VodDetailScreen(stream, autoResume: true)`. Long-press → clear progress + snackbar with UNDO. **`_ContinueWatchingRow` on Series tab** (`series_screen.dart`): same pattern, scoped to series-episode entries. Tap → `SeriesDetailScreen` with the parent series + saved season auto-selected (V04's `autoResumeEpisode` path). All three rows (channel list + VOD + Series) share the same `WatchProgressStore` data — UNDO from any tab re-surfaces the card on all three. **9 new tests** (`v21_continue_watching_row_test.dart`): 4 VOD provider (no connection, no progress, surfaces VOD-kind, filters OUT series-episode) + 3 Series provider (no connection, surfaces series-episode with parent fields, filters OUT VOD) + 1 cross-provider invalidation cascade + 1 ordering preserved. 228/228 pass (was 219, +9 from V21), 0 new analyze errors. **Merged to develop (09388c5, PR #9) — CI ✅ + Release ✅ → v0.1.59.** |
|| V22 | Most Watched row dedupes from Recently Played | **Done** | agent | Closes the V05↔V20 follow-on gap: a user with 10 plays on CNN saw CNN in BOTH the Recently Played row (V20) and the Most Watched row (V05). Recency is the 'fresher' personalisation signal — a user who just played CNN 30s ago wants CNN in Recently Played, not duplicated into Most Watched. **`mostWatchedProvider`** now watches `recentlyPlayedProvider` and excludes any streamId in the top `kPersonalisationRowCap` (8) recency entries — `await` both `.future`s so the dedupe is deterministic. **`kPersonalisationRowCap` constant** (8) shared across the three home rows (Continue Watching V03, Recently Played V20, Most Watched V05) — extracted from the row widgets' hardcoded `_maxCards`. 7 new tests in `v22_most_watched_dedupe_test.dart` (empty recency, single overlap, full coverage of recency-top-8, cap honoured at 8, excluded stream keeps its count, no-connection, empty live-streams). 4 existing tests updated (3 in `most_watched_test.dart` get `recentlyPlayedProvider.overrideWith([])` to test the count-only path; 1 in `recently_played_row_test.dart` updated to reflect the V22 hide-when-also-recent behaviour). 235/235 pass (was 228, +7), 0 new analyze errors. **Merged to develop (6633eb8, PR #10) — CI ✅ but Release ❌ (v0.1.61 tag pushed but `softprops/action-gh-release@v2` got 401 + macOS artifact upload silently failed; see R01).** |
|| R01 | release.yml: macOS zip path + job-level permissions | **Done** | agent | Fixes the V22 Release failure (`Create GitHub Release` step got 401 + `Pattern 'artifacts/macos-release-…/Runner_macOS.zip' does not match any files`). Two real bugs in the macOS build job: (a) `cd …/Release && zip -r ../Runner_macOS.zip cloudstream_app.app` wrote the zip to the *parent* dir (`Build/Products/Runner_macOS.zip`) but the upload step looked for `Release/Runner_macOS.zip` — silent miss because the upload was `if-no-files-found: warn`, not `error`; (b) the `Create GitHub Release` step got 401s on every retry — the workflow-level `permissions: contents: write` should propagate, but the action is sensitive to job-level explicit permissions, and recent GitHub Actions token scoping has tightened. **Fixes**: macOS zip now `zip -r Runner_macOS.zip cloudstream_app.app` (in-place inside `Release/`); upload step upgraded to `if-no-files-found: error` so any future path mismatch is loud; `release:` job gets an explicit `permissions: contents: write` block. **Merged to develop (538ad8e, PR #11) — CI ✅ + Release ✅ → v0.1.62** (all 3 platform artifacts: APK 56.5MB + iOS zip 7.8MB + macOS zip 57.3MB). |

---

> Last updated: 2026-06-10T15:50:00+01:00

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
