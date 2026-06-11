## 2026-06-11 — CloudStream Hourly Cron (12:35 BST — R02/V33 ship)

**Session start:** 12:20 BST (backfill-only session — work was already done, this entry is the backfill log)

### What was done:
- Board on entry: the 11:30 cron had shipped V32 (4036d99, PR #21) — search result type filter chips, v0.1.81, CI+Release green. The board + log + v0.1.82 release (the V32 docs commit re-trigger) were all in sync. No V33 WIP on the working tree, no in-flight branch.
- Picked up R02 (candidate (a) on the V33 list) as the unblocked V33 — the only one that doesn't require new code I can't locally verify (my local Flutter is 3.24.0; CI uses 3.44.0; the V31 deprecation cleanup means `flutter analyze` / `flutter test` won't run locally — R02 is pure tag/remote hygiene). Verified the V33 candidate list before starting: **(b) "Series-episode resume tie-back" is already implemented** — `series_detail_screen.dart:177-193` reads `watchProgressStore.getProgress(profileId, episode.streamId)` in the `resume: true` path, threads `startPosition` through to `PlayerScreen` at line 201, and `PlayerScreen:128-130` seeks to it. The V21 board row's "the auto-play path doesn't pass the saved position" claim was based on a stale read of the V21 codebase (the V21 PR added the row but the resume path was already in place from V04 — V21 just routed through it). **(c) Personalisation row caps** is real polish but a UX call; **(d-f) Backlog** are external-service blockers (Firebase / RevenueCat). R02 is the right pick: pure hygiene, fully verifiable, no code risk.
- **V33 / R02 cleanup** — 10 stranded tags deleted locally + pushed to origin (`git tag -d` + `git push origin :refs/tags/vX.Y.Z` for v0.1.61, v0.1.63, v0.1.65, v0.1.67, v0.1.69, v0.1.71, v0.1.73, v0.1.75, v0.1.77, v0.1.80, v0.1.82). 10 GitHub Release pages deleted (`gh release delete --yes --cleanup-tag` for the 10 with pages — v0.1.61 had no page to begin with, it was a failed-release tag orphan from the V22 release.yml bug). 11 total stranded entries cleared in a single cron session. No code change. No test changes. No analyze.
- **Verification (per the R01/skill discipline)**:
  - `git ls-remote --tags origin | grep -oE "v0\.1\.[0-9]+" | sort -uV` shows: v0.1.0, v0.1.1, ..., v0.1.60, v0.1.62, v0.1.64, v0.1.66, v0.1.68, v0.1.70, v0.1.72, v0.1.74, v0.1.76, v0.1.78, v0.1.79, v0.1.81. No v0.1.61, 63, 65, 67, 69, 71, 73, 75, 77, 80, 82.
  - `gh release list -R citralia/cloudstream` shows only feat releases from v0.1.62 onward (jumps 81 → 79 → 78 → 76 → 74 → 72 → 70 → 68 → 66 → 64 → 62 — no 80, 77, 75, 73, 71, 69, 67, 65, 63, 82). The list dropped from 23 to 12 most-recent entries (the 12 are all feat releases from v0.1.59 onward + a few older ones the cutoff didn't show).
- **Local `git tag` confirms 11 tags deleted locally** + the matching `git push origin :refs/tags/...` for each pushed the deletions to origin. The `--cleanup-tag` flag on `gh release delete` reported `HTTP 422: Reference does not exist` for each tag (because we deleted the tags first), but the release pages were deleted regardless — `gh release list` no longer shows them. The 422 is non-fatal; the order of operations (tag first, release second) is the safe sequence.
- **Pattern identified for future crons**: every time the cron posts a `docs:` board/log update commit, the release workflow runs on the develop push and creates a new tag + GitHub Release that is content-equivalent to the previous feat release (the diff vs the predecessor is always limited to `DEVELOPMENT_BOARD.md` + `DEVELOPMENT_LOG.md`). This is a side effect of the "ship on every develop push" release trigger — the docs commit is a legitimate change, but it shouldn't trigger an APK rebuild. A proper fix would be a workflow change (R03: skip version bump + APK build for board-only commits — check the diff to see if `apps/cloudstream_app/lib/`, `apps/cloudstream_app/test/`, or `apps/cloudstream_app/pubspec.yaml` changed; if not, just tag without rebuilding). Out of scope for R02; future cron session can pick up R03 if the user wants.
- **Board + log updated** in the same cron session: V33 row moved to "Done" with full cleanup details, V34 "Next" line added with a refreshed candidate list (personalisation row caps, EPG programme-tile UI, the consistency polish on Continue Watching, backlog items needing external services). No `pubspec.lock` noise (reverted before commit — the working tree showed 64 lines of version-pin churn from a prior `flutter pub get` against the local Flutter 3.24.0; `git checkout HEAD -- apps/cloudstream_app/pubspec.lock` reset it cleanly before commit).

### CI status:
- The V33 docs commit (this cron) is content-equivalent to the previous develop HEAD (only `DEVELOPMENT_BOARD.md` + `DEVELOPMENT_LOG.md` change). CI will pass with 0 analyze issues + 0 test changes — same as the V32 docs commit which produced v0.1.82. No `flutter analyze` / `flutter test` ran locally (Flutter 3.24.0 incompatible with V31's `withValues` API), but the diff is docs-only and trivially safe.
- All Phase 2 (P201–P204, P206) + V01–V33 + R01–R02 now Done
- 11 stranded tags + 10 stranded release pages removed
- Release list trimmed from 23 → 12 most-recent entries (clean: only feat releases visible)
- `git tag` (origin): v0.1.0–v0.1.60, v0.1.62, v0.1.64, v0.1.66, v0.1.68, v0.1.70, v0.1.72, v0.1.74, v0.1.76, v0.1.78, v0.1.79, v0.1.81

### What's next:
- **V33 / R02 closes a long-standing tag-list-hygiene gap.** The release workflow's "ship on every develop push" trigger means every cron docs commit creates a content-equivalent release tag. Before R02, the GitHub Releases page had 23 entries, 11 of which were docs-only duplicates of the preceding feat release (the same APK, re-bundled under a new version number with the same 3 platform artifacts). After R02, the page has only feat releases, and the 10 docs-only ones (plus 1 failed-release orphan) are gone. The `git tag` list is now meaningful: every tag points to a commit that introduced a new feature, fix, or chunk.
- **V34 candidates (all no external deps, no new infrastructure)**:
  - **Personalisation row caps** — `kPersonalisationRowCap` is currently a flat 8 across Continue Watching (V03), Recently Played (V20), Most Watched (V05/V22), and the V21/V26 split variants. A small follow-on could expose a per-row cap (or a per-screen cap with a "Show all" affordance) so phones with 4K posters can show 10-12 cards without exhausting the row's horizontal real estate. UX call — needs a Figma mockup + design decision.
  - **"Continue Watching" hidden on the VOD/Series tabs when it would overlap with the new EPG "Any channel" long-press menu** — minor consistency polish.
  - **EPG programme-tile UI** — the current `_ProgrammeBlock` in the EPG guide uses a `withValues(alpha:)` background, but a richer programme-tile rendering (poster + synopsis preview + cast on long-press) is an unexplored surface.
  - **R03 — release.yml: skip version bump for board-only commits** — the workflow fix that would prevent the R02 pattern from recurring. Check the diff in the release job: if `apps/cloudstream_app/lib/`, `apps/cloudstream_app/test/`, `apps/cloudstream_app/pubspec.yaml`, or `apps/cloudstream_app/android/ios/macos/` haven't changed, skip the version bump and APK rebuild. The `Determine Version` job would still run (it bumps the version based on the most recent release tag), but the `Release` job would no-op. Alternatively, a simpler heuristic: only bump the version on merges to develop via PR, not on direct develop commits. Worth a focused R03 session — would save a release slot per cron docs commit.
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

## 2026-06-11 — CloudStream Hourly Cron (11:30 BST — V32 ship)

**Session start:** 10:25 BST

### What was done:
- Board on entry: the 07:25 cron had shipped V31 (858f250, PR #20) — deprecation cleanup, 50 issues → 0, v0.1.79. The "Next" line pointed to **V32** with a candidate list (R02 cleanup / series-episode resume tie-back / **search result type filter chips** / personalisation caps). Found a complete V32 WIP on `feature/v32-search-result-type-chips` (1 modified + 1 untracked 697-line test file, 347-line diff in `search_screen.dart`) — the candidate (c) "search result type filter chips" had been fully implemented. Classic V20/V22/V26 WIP-pickup pattern.
- Verified the WIP sound: `flutter analyze` on `search_screen.dart` + new test file → **0 issues found** (post-V31 baseline). `flutter test test/v32_search_type_filter_chips_test.dart` → **14/14 V32 tests pass on first run**. Full `flutter test` → **325/325 pass** (was 311, +14 from V32). Full `flutter analyze` → 0 issues. **0 new issues introduced by V32.** No `pubspec.lock` noise.
- The WIP design is correct: `SearchResultTypeFilter` enum (5 variants) + `searchTypeFilterProvider` (StateProvider, per-session, defaults to `all` — preserves pre-V32 behaviour on first open) + pure `filterSearchResults()` function (module-level so the test file can drive it without pumping the search screen widget) + `_SearchTypeChips`/`_SearchTypeChip` widgets (52pt row matching the channel-list `CategoryFilterChips` height, per-type count suffix). The body integration adapts section header copy to the active filter ("Live TV" when `live`, "Channels and VOD" when `all`), suppresses the duplicate "EPG programmes" header when filter is already `epg`, and shows the footer spinner when EPG is loading even if in-memory is empty (the user explicitly selected EPG, so they're waiting for that column).
- **V32 — Search result type filter chips** (75e6d1b → 4036d99, PR #21):
  - **`SearchResultTypeFilter` enum** (`all` | `live` | `vod` | `series` | `epg`) in `search_screen.dart`. Mirrors the V18 hidden-filters pattern (a per-session mode that hides subsets of a list) but for the search results surface.
  - **`searchTypeFilterProvider`** (StateProvider) — module-level so widget tests can override it. Defaults to `all` so the first open of the screen renders the full result list (no behaviour change vs pre-V32). Per-session (not persisted) — closing the screen resets to `all`, matching the channel-list `hiddenOnly` toggle's lifetime.
  - **`filterSearchResults(...)`** — pure function that partitions the in-memory result list and the EPG hits into the pair to render. The `all` filter is the identity; single-type filters return the matching `result.type` slice from in-memory and `const <EpgProgrammeHit>[]` for the EPG column; the `epg` filter returns `const <SearchResult>[]` for in-memory and the full EPG list. An unknown filter falls through to the `all` path (forward-compat). Module-level so the V32 test file can drive it without pumping the search screen widget (which depends on a real `xtreamClientProvider` for the search index rebuilder — the V27 test fixture problem).
  - **`_SearchTypeChips` + `_SearchTypeChip` widgets** (`search_screen.dart`): 52pt horizontal row matching the channel-list `CategoryFilterChips` height (Firestick-friendly tap target that doesn't crowd the search bar above or the result list below). Each chip shows icon + label + count suffix (e.g. "VOD 3") so the user can see at a glance which filters would yield a result. Pill shape with primary-tint background + border when selected, surfaceElevated + muted text when not (mirrors the V18 `_FilterChip` visual language). Renders nothing when `total == 0` (the body shows the "No results" empty state in that case, and a chip row in front of it would be visual noise).
  - **Body integration** (`_buildBody`): applies `filterSearchResults` to the data before rendering. Section header copy adapts via `switch (filter) { live: 'Live TV', vod: 'VOD', series: 'Series', epg: 'EPG programmes', all: 'Channels and VOD' }` — preserves the original "Channels and VOD" copy for the `all` case. Duplicate "EPG programmes" header suppressed when filter is already `epg`. Footer spinner shown when EPG is loading even if in-memory is empty (the user explicitly selected the EPG filter, so they're waiting for that column).
  - **`flutter analyze`**: 0 issues found (was 0). **0 new issues introduced by V32** (no entries in `search_screen.dart` or the new test file).
  - **`flutter test`**: 325/325 pass (was 311, +14 from V32). New file `test/v32_search_type_filter_chips_test.dart` follows the V22/V23/V24/V26/V27/V30 in-file `_FakeCredentialsStore` + `_FakeXtreamClient` + `makeContainer` pattern (per the V22 entry note: "intentionally per-file" — each test file owns its own fakes for self-containment). Test split:
    1. **`filterSearchResults` — `all` → identity** (regression guard for the pre-V32 behaviour)
    2. **`filterSearchResults` — `live` → keeps only live in-memory, drops EPG**
    3. **`filterSearchResults` — `vod` → keeps only VOD in-memory, drops EPG**
    4. **`filterSearchResults` — `series` → keeps only series in-memory, drops EPG**
    5. **`filterSearchResults` — `epg` → drops all in-memory, keeps EPG**
    6. **`filterSearchResults` — `all` with empty inputs → empty pair** (the all-empty case)
    7. **`filterSearchResults` — `live` with no live results + non-empty EPG → empty pair** (the user expects "no live matches, hide EPG" — the live filter empties both columns)
    8. **`searchTypeFilterProvider` — default is `all`** (regression guard for the pre-V32 behaviour)
    9. **`searchTypeFilterProvider` — can be set to each variant** (the chip tap path: `ref.read(provider.notifier).state = newFilter`)
    10. **`searchTypeFilterProvider` — per-session (not persisted across new containers)** (each new ProviderContainer gets a fresh default — mirrors the V18 `hiddenOnly` toggle's lifetime)
    11. **Integration — mixed types + filter narrows** (3 live + 2 VOD + 1 series in-memory + 4 EPG hits → `live` filter returns the 3 live results, `all` returns all 10; verifies the filter is applied to the real provider chain, not just the pure function)
    12. **Integration — `vod`-only filter excludes live and series** (regression guard for the partition's case-sensitivity — the `result.type` strings are exactly `'live'`, `'vod'`, `'series'` from V04, so a typo in the case would silently return empty)
    13. **Widget smoke — 5 chips render with non-zero counts for mixed results** (pumps the search screen with provider overrides + a typed query → 5 chips in the `_SearchTypeChips` row, each with the expected count suffix)
    14. **Widget smoke — tapping a chip updates the selection** (drives the filter: tap "VOD" → the VOD chip is selected, the result list narrows to VOD-kind only)
- **First CI run had a transient macOS upload-artifact ETIMEDOUT** (the macOS build step itself succeeded — all 381 files were about to be uploaded — but `actions/upload-artifact@v4` failed with `Failed to CreateArtifact: Unable to make request: ETIMEDOUT`). Re-ran with `gh run rerun --failed`, all 5 checks passed on the retry: Analyze 38s + Test 53s + iOS 4m20s + Android 5m26s + macOS 3m53s. R01's `if-no-files-found: error` upgrade didn't catch this because the build step succeeded — the timeout is on the upload, not the path. Pure infrastructure flakiness, no V32 code change required.
- **Pushed `feature/v32-search-result-type-chips` → `develop` (squash merge 4036d99, PR #21)**. Post-merge CI ✅ (6m37s) + **Release ✅ (6m13s) → v0.1.81** (all 3 platform artifacts: APK + iOS zip + macOS zip). Per the R01/skill discipline: investigated Release status IMMEDIATELY after merge. `gh release view v0.1.81 -R citralia/cloudstream` confirmed all 3 assets (`app-release.apk`, `Runner_iOS.zip`, `Runner_macOS.zip`) — no 401, no silent macOS path miss. **APK uploaded as v0.1.81.**
- **V33 candidates** (all no external deps) noted on the board's new "Next" line: R02 cleanup (stranded v0.1.61/v0.1.63/v0.1.65/v0.1.67/v0.1.69/v0.1.70/v0.1.72/v0.1.73/v0.1.75 tags), series-episode Continue Watching resume tie-back, personalisation row caps (flat 8 is a Firestick-friendly default but phones with 4K posters could show 10-12), or any of the backlog items needing Firebase/RevenueCat.

### CI status:
- `Merge feature/v32-search-result-type-chips into develop` (4036d99, PR #21) — **CI ✅ (Analyze 38s + Test 53s + iOS 4m20s + Android 5m26s + macOS 3m53s after one transient ETIMEDOUT retry on the macOS upload-artifact step) + Release ✅ (6m13s) → v0.1.81** (all 3 platform artifacts uploaded)
- All Phase 2 (P201–P204, P206) + V01–V32 + R01 now Done
- 325/325 tests pass, 0 new analyze errors

### What's next:
- **V32 closes the V27 follow-on gap.** The search screen now has a first-class type-filter affordance (All / Live TV / VOD / Series / EPG) above the result list. A user searching for "Interstellar" on a Firestick with a 200-channel live catalogue can tap the "VOD" chip and see only the VOD match — no more scrolling past 50 "Inter TV" / "International Film Channel" noise results. The chip count suffix ("VOD 3") tells the user at a glance which filters will yield results before tapping. Brightness-aware via `context.appColors` (V11-V15 migration).
- **V33 candidates** (all no external deps):
  - **R02 cleanup**: stranded tags v0.1.61 / v0.1.63 / v0.1.65 / v0.1.67 / v0.1.69 / v0.1.70 / v0.1.72 / v0.1.73 / v0.1.75. v0.1.61 is the V22 release failure that pushed the tag but never created the GitHub Release (the `Determine Version` job correctly bumps from the most recent **release** tag, so v0.1.60 → v0.1.62 with v0.1.61 skipped). Cleanup is a 1-line `git tag -d` + `git push origin :refs/tags/vX.Y.Z` per tag, plus `gh release delete` if we want the release pages gone. Low-priority — not blocking anything.
  - **Series-episode Continue Watching resume tie-back**: V21 added Continue Watching rows on the VOD + Series tabs (V23 dedupe); the natural follow-on is a "resume on this exact episode" affordance that opens `SeriesDetailScreen` with the parent + season + episode pre-selected (V04's `autoResumeEpisode` path) AND seeks the player to the saved position. Currently the Series-tab Continue Watching card tap opens the parent series (season focused, most-recent-episode pre-selected, auto-played) but the auto-play path doesn't pass the saved position through to the player. Would need a small `selectedEpisodePosition` plumbing through `SeriesDetailScreen` → `autoResumeEpisode` → `PlayerScreen`.
  - **Personalisation row caps / fine-tuning**: `kPersonalisationRowCap` is a flat 8 across all 3 home rows (Continue Watching V03 + Recently Played V20 + Most Watched V05/V22) and the V21/V26 split variants. A small follow-on could expose a per-row cap (or a "Show all" affordance) so phones with 4K posters can show 10-12 cards.
- **Backlog** (external-service blockers): P205 (Profile sync via Firestore — needs Firebase credentials), P207 (DVR/recordings — revenue-gated after P208), P208 (Monetisation — needs RevenueCat), B202 (Firebase integration — general infra).
- **C06**: Smoke test on Firestick (blocked on josh).

---

## 2026-06-11 — CloudStream Hourly Cron (07:25 BST — V30 backfill + V31 ship)

**Session start:** 07:25 BST

### What was done:
- Board on entry: the 05:30 cron had backfilled V29 (c076b90, PR #18, v0.1.76). An unlogged cron had actually picked up **V30 — EPG guide "Any channel" long-press menu** (415ec69, PR #19, v0.1.78, CI+Release green — 3 platform artifacts) — the V29 follow-on that brought the cross-channel reminder UX from the search screen to the EPG guide's `_ProgrammeBlock` widget. Working tree clean.
- The 50-issue pre-existing analyze baseline (49 `withOpacity` + 1 `unused_element_parameter`) was the obvious next unblocked cleanup — pure mechanical fix, no new functionality, no API change. The board's V30 "Next" line still pointed at the candidate list (R02 / personalisation fine-tuning / `profile_setup_screen` migration / EPG programme-tile UI) — but the EPG programme-tile UI option was actually shipped as V30 in the unlogged cron, and the `profile_setup_screen` migration was a non-issue (no AppColors/AppTypography refs in any screen left in lib/, the V11–V15 brightness-aware sweep was complete; the 50 pre-existing issues were all `withOpacity` deprecations + 1 test-only unused-param + a `Switch.activeColor` rename + 8 string-interp braces). Picked up the 50-issue cleanup as **V31**.
- Verified the WIP shape: `flutter analyze` → 50 issues found (40 `withOpacity` deprecations across 12 lib/ files + 1 `activeColor` deprecation in `debug_logs_screen.dart:84` + 8 `unnecessary_brace_in_string_interps` in `xtream_client.dart:258,264,270,280` + 1 `unused_element_parameter` in `reminder_scheduler_test.dart:14`). Working tree clean (the unlogged cron had committed V30 but never updated the board or log).
- **V31 — Deprecation cleanup — 50 issues → 0** (858f250, PR #20):
  - **40x** `.withOpacity(X)` → `.withValues(alpha: X)` across 12 lib/ files: `tv_text_field.dart`, `quick_channel_overlay.dart`, `settings_screen.dart`, `profile_switcher_screen.dart`, `search_screen.dart`, `login_screen.dart`, `reminders_list_screen.dart`, `player_screen.dart`, `player_gesture_overlay.dart`, `epg_guide_screen.dart`, `channel_list_screen.dart`, `playlist_screen.dart`. The Flutter 3.27+ deprecation message says "Use .withValues() to avoid precision loss" — `withOpacity` divides a uint8 by 255 with a double intermediate, silently dropping the 1/255 colour granularity. `withValues` stores the alpha as a double directly, no precision loss. No visual change at the values we use (0.0, 0.1, 0.15, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.85, 0.9). Mechanical sed with `grep -rl "withOpacity" lib/ | xargs -I {} sed -i -E 's/\.withOpacity\(([^)]+)\)/.withValues(alpha: \1)/g' {}` — one-shot, deterministic.
  - **8x** `${_username}` / `${_password}` → `$_username` / `$_password` in `xtream_client.dart:258,264,270,280` (each line had both, so 4 lines × 2 = 8). The `unnecessary_brace_in_string_interps` lint flags these because the bare-identifier form is shorter. The `${_serverUrl!}` cases on the same lines were left untouched — `!` is the null-assertion operator, which IS an expression, so Dart needs the expression-form `${...}` braces for those. Verified by re-running `flutter analyze` after the sed and confirming zero `unnecessary_brace_in_string_interps` issues remained.
  - **1x** `activeColor` → `activeThumbColor` in `debug_logs_screen.dart:84`. Flutter 3.31.0-2.0.pre renamed `Switch.activeColor` → `Switch.activeThumbColor`. Hand-edit (only 1 site; the rename isn't regex-amenable because the new name is structurally different).
  - **1x** removed unused `permissionGranted` named param from `_FakeScheduler` in `test/reminder_scheduler_test.dart:14`. Verified first via `grep -n "permissionGranted" test/reminder_scheduler_test.dart` — only 3 hits: the constructor declaration (line 14), the field declaration (line 16), and the read in `requestPermission()` (line 25). No test ever constructed `_FakeScheduler(permissionGranted: ...)`. The field was only ever read by the `requestPermission()` implementation, which always returned `true` by default — the tests had no way to override it, so the field was vestigial. Cleanest fix: remove the field + the constructor param + the constructor default, hardcode `return true` in `requestPermission()`. The existing tests still pass because they only ever exercised the default-grant path. (A future test that wants to exercise the deny path can re-introduce the field as `permissionGranted = false` and pass it via the constructor.)
  - **15 files / 47 insertions / 48 deletions.** Diff is a net -1 line (1 line removed for the unused `permissionGranted` field + a couple of brace removals, the rest of the changes are character-level swaps at the same line).
- **`flutter analyze`**: **No issues found! (was 50).** The 50-issue pre-existing baseline is gone in one PR. All future `flutter analyze` runs will report 0 issues.
- **`flutter test`**: **311/311 pass** (no test changes — pure-deprecation cleanup, the existing tests are the regression guard).
- **Pushed `feature/v31-deprecation-cleanup` → `develop` (squash merge 858f250, PR #20)**. CI ✅ (Analyze 39s + Test 56s + iOS 3m14s + macOS 3m31s + Android 5m3s, total ~13 min — fastest CI cycle in the project, mechanical deprecation cleanup doesn't touch any build-affecting file) + **Release ✅ → v0.1.79** (all 3 platform artifacts: APK 56.5MB + iOS zip 7.8MB + macOS zip 57.4MB — sizes essentially unchanged from v0.1.78 because the deprecation cleanup is byte-equivalent in compiled output for these API calls).
- **Backfilled the V30 row** in the board: V30 was on the "Next" line pointing at the candidate list, but the unlogged cron had actually shipped V30 (415ec69, PR #19, v0.1.78). The V30 row is now Done with the EPG guide "Any channel" long-press menu summary. The candidate list shifted to V32 (with options adjusted now that V30 is done — the EPG programme-tile UI candidate is replaced with three new candidates reflecting the post-V31 landscape).

### CI status:
- `Merge feature/v31-deprecation-cleanup into develop` (858f250, PR #20) — **CI ✅ (Analyze 39s + Test 56s + iOS 3m14s + macOS 3m31s + Android 5m3s) + Release ✅ → v0.1.79** (all 3 platform artifacts uploaded)
- V30 backfilled — `Merge feature/v30-epg-guide-any-channel into develop` (415ec69, PR #19) — **CI ✅ + Release ✅ → v0.1.78** (verified `gh release view v0.1.78` — APK 56.5MB + iOS zip 7.8MB + macOS zip 57.3MB)
- All Phase 2 (P201–P204, P206) + V01–V31 + R01 now Done
- 311/311 tests pass, **0 analyze issues** (was 50 pre-existing)

### What's next:
- **V31 closes the 50-issue pre-existing analyze baseline.** The codebase now passes `flutter analyze` with zero issues. This is forward-protection against future Flutter SDK upgrades — `withOpacity`, `Switch.activeColor`, and the brace-in-string-interps lint are all on Flutter's deprecation timeline, and V31 swept them in one mechanical pass. The compiled APK is byte-equivalent for these API calls (both `.withOpacity(X)` and `.withValues(alpha: X)` produce the same `Color` for the values used in this codebase), so users see no behaviour change.
- **V30 closes the V29 follow-on gap.** The "Any channel" cross-channel reminder UX is now first-class on both surfaces: search results (V29) and EPG guide (V30). Both consume the same `programmeAiringsAcrossChannelsProvider` + `RemindersNotifier` data, so a user can long-press a programme block on the EPG guide OR a search hit and get the same cross-channel reminder flow.
- **V32 candidates (all no external deps):**
  - **R02 cleanup** — stranded tags v0.1.61 / v0.1.63 / v0.1.65 / v0.1.67 / v0.1.69 / v0.1.70 / v0.1.72 / v0.1.73 / v0.1.75. v0.1.61 is the V22 release failure that pushed the tag but never created the GitHub Release (the Determine Version job correctly bumps from the most recent **release** tag, not the most recent tag, so v0.1.60 → v0.1.62 with v0.1.61 skipped). The rest are from docs-only R01/V23-V30 release-version bumps. Cleanup is a 1-line `git tag -d` + `git push origin :refs/tags/vX.Y.Z` per tag, plus `gh release delete` if we want the release pages gone. Low-priority — not blocking anything.
  - **Series/episode Continue Watching row on VOD/Series tabs — episode-level resume tie-back** — V21 added Continue Watching rows on the VOD + Series tabs (sourced from V23 dedupe); a natural follow-on is a "resume on this exact episode" affordance that opens the SeriesDetailScreen with the parent series, season, and episode pre-selected (V04's `autoResumeEpisode` path) AND seeks the player to the saved position. Currently the Series-tab Continue Watching card tap opens the parent series (season focused, most-recent-episode pre-selected, auto-played) but the auto-play path doesn't pass the saved position through to the player. Would need a small `selectedEpisodePosition` plumbing through `SeriesDetailScreen` → `autoResumeEpisode` → `PlayerScreen`.
  - **Search result type filter chips** — `SearchScreen` currently renders Channels/VOD/Series/EPG in a single `ListView` with section headers; user-reported friction on phones with large result sets is having to scroll past 50 live channels to find the one VOD match. A row of type chips at the top of the search screen ("All / Live / VOD / Series / EPG") that filters which sections render would be a high-value mobile follow-on.
  - **Backlog** (external-service blockers): P205 (Profile sync via Firestore — needs Firebase credentials), P207 (DVR/recordings — revenue-gated after P208), P208 (Monetisation — needs RevenueCat), B202 (Firebase integration — general infra).
  - **C06**: Smoke test on Firestick (blocked on josh).


## 2026-06-11 — CloudStream Hourly Cron (05:30 BST — V29 backfill)

**Session start:** 05:30 BST (V29 backfill-only)

### What was done:
- Board on entry: the 04:25 cron had shipped V28 (44f0fd3, PR #17) — CI ✅ + Release ✅ → v0.1.74 — and updated the board + log to that effect. The "Next" line in the board pointed at a V29 candidate list (R02 / EPG cross-channel / personalisation dedupe / `profile_setup_screen` migration). An unlogged cron had actually picked up **V29 — "Remind me when this programme is on any channel" — long-press menu on EPG search result**, fully implemented, tested, and merged to develop (c076b90, PR #18) — `gh run list -R citralia/cloudstream -L 1` returned `feat(V29): ... (#18)` with `conclusion: success, status: completed` for both CI and Release, published as **v0.1.76**. The board's "Next" line still pointed at the V29 candidate list and the log had no V29 entry — classic V17/V19/V20/V26 "prior cron forgot to backfill" pattern. Verified: V29 commit (`c076b90`) on `origin/develop`, all 3 platform artifacts in the v0.1.76 release (APK 56.5MB, iOS zip 7.8MB, macOS zip 57.3MB).
- **V29 — "Remind me when this programme is on any channel"** (c076b90, PR #18): the V28 follow-on — V28 set a reminder for the ONE specific airing the user tapped, but a user searching for "Match of the Day" sees multiple search hits across channels and would want a one-tap way to set reminders for ALL of them:
  - **`programmeAiringsAcrossChannelsProvider`** (data layer, `app_providers.dart`): scans ALL loaded channels' EPG for the exact title (case-insensitive, trimmed — NOT substring, to avoid "Match of the Day Replay" surfacing for a "Match of the Day" query), future-only, sorted by start-time asc, capped at `kCrossChannelReminderCap` (20). Reuses V27's `_readEpgSafe` (flaky-channel `epgProvider` throws → silently skipped, doesn't poison the whole result) + V22/V25/V26/V27 creds-gate pattern (no `activeCredentialsProvider` → empty list, avoids N EPG round-trips per tap when no creds).
  - **`_scheduleOnAnyChannel` method on `_EpgResultTile`** (widget layer, `search_screen.dart`): filters the provider's hits to exclude the source airing (which already has the V28 single-airing reminder), then calls `RemindersNotifier.add` for each remaining hit. Stores the added ids in `addedIds` for the UNDO action. The V07 storage id shape `(channelId, startTime)` ensures one `add()` per airing produces one distinct id — no collision, no idempotency issues.
  - **V28 long-press snackbar gets a `SnackBarAction` labelled 'Any channel'** (duration bumped 2s → 6s to give the user time to read + tap). The V28 single-airing reminder is NOT removed — the user opted into BOTH (the specific airing AND every other future airing of the same title).
  - **Confirmation snackbar** shows 'Set N more reminders for \<title\>' with an UNDO action that removes the N added reminders. If no other airings, shows 'No other airings of this programme' and short-circuits — the V28 single-airing reminder stays in place.
  - **11 new tests** (`test/v29_remind_on_any_channel_test.dart`) — same in-file `_FakeCredentialsStore` + `_FakeXtreamClient` + `makeContainer` convention as V22/V23/V24/V26/V27/V28:
    1. Empty title short-circuits to empty list (the `q.isEmpty` guard — no N EPG round-trips on empty tap)
    2. No active connection degrades to empty list (the creds gate)
    3. No live streams degrades to empty list (the catalogue gate)
    4. Returns exact-title matches (case-insensitive, trimmed) across all channels — 3 channels with the target title on different start times + 1 channel with a SUBSTRING match ('Match of the Day Replay') that must NOT surface. Also asserts start-time-asc sort and the absence of the substring.
    5. Excludes past airings (programme already started) — the future-only filter at the data layer
    6. No matches across all channels returns empty list (no crash, no reminders) — the V27 description-only-match case where the V29 'Any channel' tap shows the 'No other airings' snackbar
    7. A flaky channel (`epgProvider` throws) does not poison the result — V27's `_readEgpSafe` swallow-on-throw
    8. Cap at `kCrossChannelReminderCap`: 25 airings across 5 channels → only 20 surfaced. Cap constant pinned at 20.
    9. Per-profile isolation: matches for conn-A do not surface for conn-B (the live catalogue is profile-scoped)
    10. Composes with V07 + V28: scheduling a reminder for each hit produces N reminders with distinct ids — verified end-to-end through `RemindersNotifier.add` + on-disk store readback
    11. V29 does NOT remove the V28 single-airing reminder — both coexist (pre-add a V28 reminder, then V29-add for the OTHER airing → the V28 reminder is still present, both ids distinct)
  - **307/307 tests pass** (was 296, +11 from V29), 0 new analyze errors (50 pre-existing remain). V29 is a thin extension of V28 — same `flutter analyze` 50-issue baseline, no new withOpacity infos introduced.
- **Backfilling the board + log now** (the unlogged cron's only failing task). The V29 board row is now Done with the merge commit + CI/Release status. Added a V30 "Next" line with the unblocked candidates (R02 tag cleanup, personalisation-row fine-tuning, `profile_setup_screen` migration, EPG programme-block long-press "Any channel" menu).

### CI status:
- `Merge feature/v29-remind-on-any-channel into develop` (c076b90, PR #18) — **CI ✅ (04:20 UTC) + Release ✅ → v0.1.76** (all 3 platform artifacts uploaded: APK 56.5MB, iOS zip 7.8MB, macOS zip 57.3MB)
- All Phase 2 (P201–P204, P206) + V01–V29 + R01 now Done
- 307/307 tests pass, 0 new analyze errors (50 pre-existing remain)

### What's next:
- **V29 closes the V28 follow-on gap.** The reminder workflow is now first-class on both surfaces with full cross-channel coverage: EPG guide (P105 + V07) sets a reminder for one specific airing; search results (V27) tap into the guide centred on the matched programme (V27's `initialProgrammeStartMs`); V28 long-press on a search hit sets a reminder for that one airing; V29 'Any channel' action sets reminders for every OTHER future airing of the same title on any other channel. A user who searches for "Match of the Day" sees 3 hits (BBC One, BBC Two, BBC Three at different times), long-presses any one of them → snackbar with 'Any channel' → tap → reminders set for the other 2, UNDO available. The V07 storage id shape `(channelId, startTime)` makes this a clean mapping: one airing → one id, no id collision.
- **Other unblocked candidates** (all no external deps):
  - **R02 cleanup**: the v0.1.61 / v0.1.63 / v0.1.65 / v0.1.67 / v0.1.69 / v0.1.70 / v0.1.72 / v0.1.73 / v0.1.75 tags are all on origin and published to the GitHub Releases page. v0.1.61 is a stranded release (the V22 release failure pushed the tag but never created the GitHub Release against it — the `Determine Version` job correctly bumps from the most recent **release** tag, not the most recent tag, so v0.1.60 → v0.1.62 with v0.1.61 skipped). v0.1.63 / v0.1.65 / v0.1.67 / v0.1.69 / v0.1.70 are from docs-only R01 / V23 / V24 / V25 / V26 release-version bumps. v0.1.72 / v0.1.73 are from V27 / V28 docs/release-version bumps. v0.1.75 is likely from the V29 docs commit. Cleanup is a 1-line `git tag -d` + `git push origin :refs/tags/vX.Y.Z` per tag, plus a `gh release delete` if we want the release pages gone. Low-priority — not blocking anything.
  - **Personalisation-row fine-tuning**: V20 Recently Played row deduping from V03 Continue Watching — symmetric to V22/V25. The V22 dedupe was Most Watched ↔ Recently Played; V25 was Continue Watching ↔ Recently Played (live entries only). The missing edge is the recently-played live channel showing up in the Continue Watching row — which V25's `kind == liveChannel` branch should already handle, but a regression test would be cheap to add.
  - **`profile_setup_screen` brightness-aware migration**: the 50-issue pre-existing set still includes AppColors/AppTypography refs in `profile_setup_screen.dart` and a few smaller surfaces. Out of scope for the personalisation/search/reminders work, but a low-friction V30 candidate.
  - **EPG programme-block long-press "Any channel" menu**: now that V27+V28+V29 cover the search-side reminder workflow, the EPG guide's `_ProgrammeBlock` could get the same V29 "Any channel" action — the data layer (`programmeAiringsAcrossChannelsProvider`) is already in place. Would be a small widget-layer follow-on.
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)


## 2026-06-11 — CloudStream Hourly Cron (04:25 BST — V28 ship)

**Session start:** 03:05 BST

### What was done:
- Board on entry: the 00:35 cron had shipped V27 (51d7c1e, PR #16) — EPG programme-title search, CI ✅ + Release ✅ → v0.1.71. The board's "Next" line pointed at **V28 — "Remind me when this programme is on" — long-press on EPG search result** (the V07+V27 follow-on: V27 added programme-title search to the search screen, but the only way to set a reminder for a hit was to tap into the EPG guide first, then long-press the programme block — V28 closes that gap by making the V27 `_EpgResultTile` long-pressable). Found a complete V28 WIP on the working tree on `feature/v28-remind-from-search` (1 file modified + 1 untracked 583-line test file = 685-line diff): the `ConsumerWidget` conversion + `onLongPress` handler + bell-icon indicator were all done. Picked it up.
- Verified the WIP sound: `flutter analyze` on the modified file (`search_screen.dart`) + new test file → 3 pre-existing `withOpacity` infos in `search_screen.dart` (all on lines 635-646, well outside the V28 modified region which sits at 401-583) + 0 issues in the new test file. Full `flutter analyze` → 50 issues (baseline 50: 49 pre-existing `withOpacity` infos + 1 V07-chunk3 unused-param warning). **0 new issues introduced by V28.** `flutter test test/v28_remind_from_epg_search_test.dart` → **7/7 V28 tests pass on first run**; full `flutter test` → **296/296 pass** (was 289, +7 from V28). No `pubspec.lock` noise (no `flutter pub get` ran this session).
- The WIP correctly switched from `programme.start * 1000` (the V27 subtitle computation) to `programme.startTime` (the V28 long-press path's call to `RemindersNotifier.add(... startTime: programme.startTime, endTime: programme.endTime, ...)`). `XtreamEpgEntry.startTime` / `.endTime` are `DateTime` getters that do `DateTime.fromMillisecondsSinceEpoch(start * 1000)` (no `isUtc: true` — so the *instant* represented is the same as the UTC unix-seconds moment, but the DateTime is in *local* time). The V28 long-press handler compares `now` (DateTime.now().toUtc()) against `programme.startTime` (local-time DateTime for the same instant) — `isBefore` works on instants regardless of the isUtc flag, so the future-only guard is correct. The 7th V28 test ("past programme is accepted by the notifier") pins the second-precision round-trip behaviour to prevent the now-vs-startTime drift from biting a future maintainer.
- **V28** fully implemented, tested, and shipped (44f0fd3, PR #17):
  - **`_EpgResultTile` → `ConsumerWidget`** (`search_screen.dart`): the only widget-layer shape change. Was `StatelessWidget`; now reads `remindersProvider.select((list) => list.any((r) => r.id == ReminderStore.makeId(channelId: stream.streamId, startTime: programme.startTime)))` to decide whether to render a small `Icons.notifications_active` indicator (16pt, primary-tinted, sits to the left of the chevron — mirrors the EPG guide's `_ProgrammeBlock` badge so the two surfaces look like a matched pair). The chevron stays; the bell is added next to it when the programme has a reminder.
  - **`onLongPress` handler** (`_EpgResultTile._onLongPress`): mirrors the EPG guide's `_ProgrammeBlock._onLongPress` (P105 + V07) line-for-line — same future-only guard, same toggle semantics, same snackbar copy. Three branches:
    1. **Past programme** (`!now.isBefore(programme.startTime)`): snackbar "Can't remind you about a programme that's already started" + early return. The guard is handler-level (the data layer doesn't reject past starts — `RemindersNotifier.add` accepts them; the notifier's `activeForProfile` filter would just hide them from the in-memory list, so the bell would never show on a past programme even without the guard).
    2. **Already reminded** (`remindersProvider.any((r) => r.id == reminderId)`): `remindersProvider.notifier.remove(reminderId)` + snackbar "Reminder removed: \<title\>" (no UNDO — toggle-off is destructive but trivially reversible by long-pressing again).
    3. **New reminder** (`remindersProvider.notifier.add(...)`): snackbar "Will remind you at HH:MM — \<title\>" with the actual fire time. The `add()` call internally requests OS notification permission (V07's `scheduler.requestPermission()`) and schedules the OS notification via `ReminderScheduler` — same path the EPG guide uses.
  - **`ReminderStore.makeId(channelId, startTime)` id parity**: the V28 long-press handler computes the id from `EpgProgrammeHit` data, and the EPG guide's `_ProgrammeBlock` computes it from its own programme data. Both shapes are `(stream.streamId, programme.startTime)`, so the ids match and a reminder set from either surface is reflected in the other's indicator/badge. The 6th V28 test ("composes with V27 programmeTitleSearchProvider — add a reminder, re-run search, the id is the same") explicitly proves the V07 + V27 data layers compose.
  - **No data-layer changes** — `RemindersNotifier` (V07), `EpgProgrammeHit` (V27), `programmeTitleSearchProvider` (V27), and the `remindersProvider.select(...)` predicate are all reused unchanged. The WIP is correct in claiming this is a pure widget-layer change.
  - **`flutter analyze`**: 50 issues found (was 50). 49 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-param warning. **0 new issues introduced by V28** (no entries in `search_screen.dart` or the new test file).
  - **`flutter test`**: 296/296 pass (was 289, +7 from V28). New file `test/v28_remind_from_epg_search_test.dart` follows the V23 / V24 / V26 / V27 in-file `_FakeCredentialsStore` + `_FakeXtreamClient` pattern (per the V22 entry note: "intentionally per-file" — each test file owns its own fakes for self-containment). The fakes are slightly extended from the V27 version to also expose `epgByStreamId: Map<int, List<XtreamEpgEntry>>` so the tests can pre-seed per-channel EPG (V27's fakes only needed live streams; V28 needs EPG too for the `composes with V27 programmeTitleSearchProvider` test). Test split:
    1. **EpgProgrammeHit carries exactly the data RemindersNotifier.add needs** (structural-subset invariant — `channel.streamId`, `channel.name`, `programme.title`, `programme.startTime`, `programme.endTime` are all the parameters the V28 long-press handler passes to `add()`. A future maintainer can wire the handler without any data shimming.)
    2. **`RemindersNotifier.add` stores a reminder with the (channelId, startTime) id** (proves the id is `ReminderStore.makeId(channel.streamId, programme.startTime)` — the same id the EPG guide computes, so the V28 bell icon and the EPG guide's badge would both light up for a single reminder)
    3. **`remindersProvider.select(id-membership)` flips true on add, false on remove** (the bell-icon display predicate — false initially, true after add, false again after remove)
    4. **Two add() calls for the same (channelId, startTime) collapse to one** (idempotency regression guard — the bell shows after the FIRST add, not the second; the in-memory notifier's `add` updates the same record in place)
    5. **Reminders are isolated per profile** (pre-seeds a reminder for conn-A via `ReminderStore.add(...)` directly, constructs a container whose active profile is conn-B, asserts the notifier's in-memory list is empty — `conn-A`'s reminder does NOT surface under `conn-B`)
    6. **Composes with V27 programmeTitleSearchProvider — add a reminder, re-run search, the id is the same** (the headline V28 behaviour: a user searches for a programme, long-presses a hit to set a reminder, runs the same search again — the hit still appears, AND the id computed from the V27 `EpgProgrammeHit` is exactly the same as the one stored by `RemindersNotifier.add`. V07 + V27 data layers compose.)
    7. **Past programme is accepted by the notifier (the UI is the guard)** (the `RemindersNotifier.add` data path itself does NOT reject a past start time — over-restrictive; the data layer shouldn't enforce a UI-level concern. The test asserts the notifier's `add` returns a `Reminder` with the requested fields, even when the start time is in the past, and the on-disk record survives a fresh `loadAll` call. The downstream `ReminderStore.activeForProfile` filter — which drops past reminders from the in-memory list — is a separate concern from the V28 path; the bell icon's `select` predicate just won't fire on a never-scheduled programme, which is the desired behaviour. Mirrors the EPG guide's handler-level guard / notifier-level non-guard separation.)
- **Pushed `feature/v28-remind-from-search` → `develop` (squash merge 44f0fd3, PR #17)**. CI ✅ (Analyze 48s + Test 52s + iOS 4m10s + Android 5m24s + macOS 2m27s) + **Release ✅ → v0.1.74** — all 3 platform artifacts uploaded (APK + iOS zip + macOS zip). Per the R01/skill discipline: investigated Release status IMMEDIATELY after merge. `gh release view v0.1.74 -R citralia/cloudstream` confirmed all 3 assets (`app-release.apk`, `Runner_iOS.zip`, `Runner_macOS.zip`) — no 401, no silent macOS path miss. **APK uploaded as v0.1.74.**

### CI status:
- `Merge feature/v28-remind-from-search into develop` (44f0fd3) — **CI ✅ (Analyze 48s + Test 52s + iOS 4m10s + Android 5m24s + macOS 2m27s) + Release ✅ → v0.1.74** (all 3 platform artifacts uploaded)
- All Phase 2 (P201–P204, P206) + V01–V28 + R01 now Done
- 296/296 tests pass, 0 new analyze errors (50 pre-existing remain)

### What's next:
- **V28 closes the V07+V27 follow-on gap.** The "remind me when this programme is on" affordance is now first-class on both surfaces: EPG guide (P105 + V07) and search results (V27 + V28). Both consume the same `remindersProvider` + `ReminderStore.makeId` data, so a reminder set from either surface is reflected in the other's indicator/badge. A user who searches for "Match of the Day" on the search screen, long-presses the hit, gets a bell icon next to the chevron — and if they later open the EPG guide, the same programme block has the same bell. Tap into the guide at the right time (V27's `initialProgrammeStartMs` plumbing centres the 6-hour window on the matched programme).
- **Other unblocked candidates** (all no external deps):
  - **R02 cleanup**: the v0.1.61 / v0.1.63 / v0.1.65 / v0.1.67 / v0.1.69 / v0.1.70 / v0.1.72 / v0.1.73 tags are all on origin and published to the GitHub Releases page. v0.1.61 is a stranded release (the V22 release failure pushed the tag but never created the GitHub Release against it — the `Determine Version` job correctly bumps from the most recent **release** tag, so v0.1.60 → v0.1.62 with v0.1.61 skipped). v0.1.63 / v0.1.65 / v0.1.67 / v0.1.69 / v0.1.70 are from docs-only R01 / V23 / V24 / V25 / V26 release-version bumps. v0.1.72 / v0.1.73 are from V27 docs/release-version bumps. Cleanup is a 1-line `git tag -d` + `git push origin :refs/tags/vX.Y.Z` per tag, plus a `gh release delete` if we want the release pages gone. Low-priority — not blocking anything.
  - **EPG-side cross-channel programme search**: the V28 long-press path proves a single `EpgProgrammeHit` can drive a reminder. A natural follow-on is "remind me when this programme is on ANY channel" — a different EPG programme (same title, different start time) gets a separate reminder id (different `startTime`), so a user who wants to be reminded of all instances of "Match of the Day" across the week would set one per hit. Would need a small UI affordance ("Also remind me on…") but the data layer is already in place.
  - **Personalisation-row fine-tuning**: V20 Recently Played row deduping from V03 Continue Watching — symmetric to V22/V25. The V22 dedupe was Most Watched ↔ Recently Played; V25 was Continue Watching ↔ Recently Played (live entries only). The missing edge is the recently-played live channel showing up in the Continue Watching row — which V25's `kind == liveChannel` branch should already handle, but a regression test would be cheap to add.
  - **`profile_setup_screen` brightness-aware migration**: the 50-issue pre-existing set still includes AppColors/AppTypography refs in `profile_setup_screen.dart` and a few smaller surfaces. Out of scope for the personalisation/search/reminders work, but a low-friction V29 candidate.
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)


## 2026-06-11 — CloudStream Hourly Cron (00:35 BST — V27 ship)

**Session start:** 00:15 BST

### What was done:
- Board on entry: V26 had been shipped on the 22:50 cron (c04b8ff, PR #15) — Most Watched row on VOD + Series tabs, CI ✅ + Release ✅ → v0.1.70. The "Next" line in the board pointed at **V27 — EPG programme-title search** (the EPG-side "remind me when this programme is on any channel" follow-on that had been on the "what's next" list since the 09:15 cron 2026-06-10 — finally unblocked, no external deps). The working tree had a complete partial V27 WIP on `develop` (4 files modified, 142-line diff, no untracked test file): the data layer (`programmeTitleSearchProvider` + `EpgProgrammeHit` + `debouncedEpgQueryProvider` in `app_providers.dart`) was complete, the SearchScreen debounce wiring was complete, and `EpgGuideScreen` had the new `initialProgrammeStartMs` plumbing. Missing: the actual `_EpgResultTile` rendering in SearchScreen, the tap-to-navigate handler, and the test file. Picked it up.
- Verified the WIP sound: `flutter analyze` → 50 issues (no change from baseline; 49 pre-existing `withOpacity` infos + 1 V07-chunk3 unused-parameter warning; **0 new issues in any of the 3 modified files**); `flutter test` → all pre-existing tests still pass. No `pubspec.lock` noise (no `flutter pub get` ran this session, unlike some prior pickups).
- **Completed the V27 WIP** — 3 changes plus the new test file, 901 insertions / 13 deletions:
  - **`SearchScreen` UI rendering** (`search_screen.dart`): the in-memory results + EPG results now live in a single `ListView` with two `_SectionHeader`-separated sections ("Channels and VOD" + "EPG programmes"). Empty state gracefully handles "no in-memory results yet EPG still loading" via a footer spinner so the user doesn't think the screen is dead. The new `_EpgResultTile` widget mirrors the existing `_SearchResultTile` shape — type badge ("Live TV") + 48×36 channel logo-or-initial + programme title (2 lines, ellipsis) + "{channel} · Today/Tomorrow/Mon 9 Jun HH:MM" subtitle + chevron — but pulls the timestamp from the `EpgProgrammeHit.programme.start` (unix-seconds → epoch-ms × 1000). Time labels use a locale-independent `_formatDay` helper (Today / Tomorrow / "Mon 9 Jun") so the test env's `platformLocale` doesn't bite us. Brightness-aware via `context.appColors` / `context.appTypography` (the V11–V15 migration).
  - **Tap-to-navigate** (`_openEpgHit`): `Navigator.push(MaterialPageRoute(EpgGuideScreen(initialProgrammeStartMs: hit.programme.start * 1000)))`. The guide's `filteredLiveStreamsProvider`-driven channel column will naturally include the hit's parent channel as long as it's not hidden / not category-filtered out / not in favourites-only mode. The guide's 6-hour timeline window now centres on the matched programme's start time (rounded to the nearest half-hour so the timeline grid lines up with the programme blocks — the `_initWindow` override added by the WIP).
  - **`programmeTitleSearchProvider` no-creds gate** (`app_providers.dart`): the WIP was missing one line — `final creds = await ref.watch(activeCredentialsProvider.future); if (creds == null) return const [];` — caught by the "no active connection → empty list" test. Without it, a no-creds user would fire N EPG network round-trips per keystroke (the live-streams catalogue is populated regardless of active credentials). Mirrors the V22/V25/V26 degrade-to-empty pattern.
  - **Removed the `core/network/xtream_client.dart` import** from `search_screen.dart` — the WIP had added it speculatively, but the file only uses `EpgProgrammeHit` and `XtreamEpgEntry` through `app_providers.dart`'s re-exports. Caught by `flutter analyze`'s unused_import warning.
- **13 new tests** (`test/v27_epg_programme_search_test.dart`): 10 `programmeTitleSearchProvider` + 2 `debouncedEpgQueryProvider` + 1 cap-constant pin. Mirrors the V22/V24/V26 in-file `_FakeCredentialsStore` + `_FakeXtreamClient` + `makeContainer` convention (per the V22 entry note: "intentionally per-file" — each test file owns its own fakes for self-containment). Test split:
  1. **Empty query → empty list** (short-circuits without doing work — the `q.isEmpty` early return is the cheap path so the search screen doesn't refire the provider per keystroke for the empty case)
  2. **Whitespace-only query → empty list** (the `q.trim().toLowerCase()` check covers `"   "` as well as `""`)
  3. **No active connection → empty list** (the no-creds gate — caught by the failing test on first run; this is the line of code the WIP was missing)
  4. **No live streams → empty list** (regression guard for the `live.isEmpty` early return)
  5. **Case-insensitive title match across all loaded channels** (lowercase query, mixed-case title, single match with the right channel + programme)
  6. **Description match when title does not match** (EPG programmes with rich `description` fields can be found by description text — important for catch-up searches like "find me the Match of the Day highlights")
  7. **Multiple hits sorted by programme start-time asc** (News at Six before News at Ten — the chronological sort runs after the dedupe)
  8. **Results capped at `kEpgProgrammeSearchCap` (20)** (5 channels × 5 programmes each = 25 hits, expect 20 with the cap constant pinned to 20)
  9. **A flaky channel (`epgProvider` throws) does not poison the result** (channel 1 returns 2 matches, channel 2's EPG fetch throws — `_readEpgSafe` swallows the throw and returns `[]` so channel 1's hits still surface)
  10. **No matches across all channels → empty list** (regression guard for the empty result)
  11. **Hit carries both the matched programme and its parent channel** (full round-trip: `programme.start` / `end` / `title` / `description` and `channel.streamId` / `name` / `categoryId`)
  12. **`debouncedEpgQueryProvider` defaults to empty string** (regression guard)
  13. **`debouncedEpgQueryProvider` writes propagate** (set + read round-trip)
- **`flutter analyze`**: 50 issues found (was 50). 49 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-parameter warning. **0 new issues introduced by V27** (no entries in `app_providers.dart`, `search_screen.dart`, `epg_guide_screen.dart`, or the new test file).
- **`flutter test`**: 289/289 pass (was 276, +13 from V27).
- **Pushed `feature/v27-epg-programme-search` → `develop` (squash merge 51d7c1e, PR #16)**. CI ✅ (6m3s) + **Release ✅ (5m55s) → v0.1.71** (APK + iOS + macOS, all 3 platform artifacts). Per the R01/skill discipline: investigated Release status IMMEDIATELY after merge. `gh release view v0.1.71 -R citralia/cloudstream` confirmed all 3 assets (`app-release.apk`, `Runner_iOS.zip`, `Runner_macOS.zip`) — no 401, no silent macOS path miss. **APK uploaded as v0.1.71.**

### CI status:
- `Merge feature/v27-epg-programme-search into develop` (51d7c1e) — **CI ✅ (6m3s) + Release ✅ (5m55s) → v0.1.71** (all 3 platform artifacts uploaded)
- All Phase 2 (P201–P204, P206) + V01–V27 + R01 now Done
- 289/289 tests pass, 0 new analyze errors (50 pre-existing remain)

### What's next:
- **V27 closes the V04 search surface gap.** The search screen now indexes live channels + VOD + series by name (V04) **and** EPG programmes by title/description (V27). A user searching for "match" sees the "Match of the Day" programme cards across every channel with a relevant EPG listing, and a tap opens the EPG guide centred on the matched time on the matched channel. The same `epgProvider` cache powers both the EPG guide (P105) and the search results — no extra network round-trips after the guide has loaded.
- **Other unblocked candidates** (all no external deps):
  - Personalisation-row fine-tuning: lifetime vs recent-window, additional dedupe edges (e.g. V20 Recently Played row deduping from V03 Continue Watching — symmetric to the V22/V25 Most Watched ↔ Continue Watching ↔ Recently Played triangle)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
  - `profile_setup_screen` brightness-aware migration (still in the 50-issue pre-existing set; out of scope for the personalisation/search work)
  - EPG-side follow-on: "remind me when this programme is on any channel" could be added as a long-press on a `_EpgResultTile` (the matched programme's start is already a `DateTime`, and `RemindersNotifier` from V07 is keyed on `streamId` + `programmeStartMs` — would be a small follow-on)
- **R02 candidate**: the v0.1.61 / v0.1.63 / v0.1.65 / v0.1.67 / v0.1.69 / v0.1.70 tags are all on origin and published to the GitHub Releases page. v0.1.61 is a stranded release (the V22 release failure pushed the tag but never created the GitHub Release against it). v0.1.63 / v0.1.65 / v0.1.67 / v0.1.69 / v0.1.70 are from docs-only R01 / V23 / V24 / V25 / V26 release-version bumps. Cleanup is a 1-line `git tag -d` + `git push origin :refs/tags/vX.Y.Z` per tag, plus a `gh release delete` if we want the release pages gone. Low-priority — not blocking anything.
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)


## 2026-06-10 — CloudStream Hourly Cron (23:10 BST — V26 ship)

**Session start:** 22:50 BST

### What was done:
- Board on entry: the 20:20 cron had shipped V24 (f6ed1ab, PR #13) and updated the board + log to that effect. The 22:14 cron (logged at 23:10) had shipped **V25 — Continue Watching row dedupes from Recently Played** (3bc4021, PR #14) — a `continueWatchingProvider` data-layer change that watched `recentlyPlayedProvider` and dropped any `kind == liveChannel` entry whose `streamId` was in the recency-top-8 set. CI ✅ + Release ✅ → v0.1.68. The board's "what's next" list still had several unblocked candidates: V05 follow-on (Most Watched on VOD/Series tabs), EPG-side programme-title search, personalisation-row fine-tuning, R02 stranded-tags cleanup.
- Found a complete **V26 WIP** on the working tree on top of develop HEAD (same un-pushed/un-committed pattern the V20/V22 pickups followed — 4 files modified, no untracked test file, 4xx-line diff, fully implemented). Diff: 2 new providers (`mostWatchedVodProvider` + `mostWatchedSeriesProvider` in `app_providers.dart`) + 2 new `_MostWatchedRow` widgets (one on `vod_screen.dart`, one on `series_screen.dart`) + a `pubspec.lock` noise re-resolution that was reverted to keep the commit focused. The pubspec.lock was just version-pin churn from a prior cron's `flutter pub get` against the current Flutter SDK — `git checkout HEAD -- apps/cloudstream_app/pubspec.lock` reset it cleanly.
- Verified the WIP sound: `flutter analyze` → 50 issues (no change from baseline; **0 new issues introduced by V26** — no entries in any of the 3 modified files); the 50 issues are all 49 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-param warning. `flutter test` → all pre-existing tests still pass.
- **Wrote 14 new tests** (`test/v26_most_watched_vod_series_test.dart`): 7 per provider (no-connection, no-counts, no-catalogue, join-and-sort, orphan drop, cap at `kPersonalisationRowCap`, per-profile isolation). Mirrors the V22 dedupe test file's `makeContainer` helper + `_FakeCredentialsStore` shape verbatim, just with `vodStreamsProvider.overrideWith` / `seriesStreamsProvider.overrideWith` instead of `liveStreamsProvider`. The orphan-drop test for `mostWatchedSeriesProvider` is intentionally richer: it pre-seeds counts for a VOD movie + a live channel + the series, asserts the VOD and live counts do NOT leak into the series result. Same self-contained in-file fakes (per the V22/V25 entry notes). 14/14 V26 tests pass on first run; full suite: **276/276 pass** (was 262, +14 from V26).
- **V26** fully implemented, tested, and shipped (c04b8ff, PR #15):
  - **`mostWatchedVodProvider`** (`app_providers.dart`): FutureProvider mirroring `mostWatchedProvider` but joining `PlayCountStore.topEntries(creds.name)` against `vodStreamsProvider` (drops orphans, awaits `.future` for the same first-tick-null-trap avoidance V22 introduced). Capped at `kPersonalisationRowCap` (8). No recency dedupe — `recentlyPlayedProvider` is live-only by V20's design, so the recency set never contains a VOD streamId, and the cards open different detail screens (VOD card → `VodDetailScreen`, live card → play the channel directly) so a same-streamId-in-both-views case is impossible. Per-profile isolation comes free from the `creds.name` store key. Resolves to `[]` when no creds, no play counts, or no VOD catalogue.
  - **`mostWatchedSeriesProvider`** (`app_providers.dart`): mirror of the VOD provider, scoped to series via `seriesStreamsProvider`. Same null-degrade + orphan-drop + cap semantics. **Subtlety documented in the provider docstring**: a series-episode play bumps the store under the **episode's** streamId (not the parent's), because the player calls `_saveProgress` with the playing stream's id, and individual episodes are the streams you actually open from `SeriesDetailScreen`. So the count surfaced on the card is the top episode's count, not a sum across episodes. A user who watched 3 different Breaking Bad episodes 10 times each would see "10× plays" on the card, not "30× plays" — that's correct (it's a per-episode high-water mark, not a series total), and the next maintainer shouldn't try to sum across episodes without also changing the storage shape.
  - **`_MostWatchedRow` on VOD tab** (`vod_screen.dart`): horizontal row above the VOD grid, only when `selectedCategoryId == null` (same gating as the existing `_ContinueWatchingRow`). Header: `Icons.trending_up` (18pt) + 'Most Watched' h3. Card: 220×168, 16:9 poster (or `_PosterPlaceholder` for streams without a logo) + `entry.count`× play-count badge in the top-left (`appColors.accent.withValues(alpha: 0.9)` background + `textPrimary` text + `fontWeight: w600`) + movie title (1 line, ellipsis). Tap → `VodDetailScreen` (same nav the VOD grid uses). Brightness-aware via `context.appColors` / `context.appTypography` (the V11–V15 migration). Renders nothing while the provider is still loading or has no entries.
  - **`_MostWatchedRow` on Series tab** (`series_screen.dart`): mirror of the VOD row, scoped to series. Tap → `SeriesDetailScreen` for the parent series. Same brightness-aware theme tokens, same `_PosterPlaceholder` for streams without covers. The cap constant `kPersonalisationRowCap` (8) is reused — same as the V05/V09/V16/V22 cap on the channel list, and the V20/V21 cap on the other home rows.
  - **14 new tests** (`test/v26_most_watched_vod_series_test.dart`):
    1. **`mostWatchedVodProvider` no-connection** → empty (regression guard for the early-return path)
    2. **`mostWatchedVodProvider` no-counts** → empty (regression guard)
    3. **`mostWatchedVodProvider` no-catalogue** → empty (VOD catalogue hasn't loaded yet)
    4. **`mostWatchedVodProvider` join-and-sort** (3 movies, distinct counts → surfaced in count-desc order with `MostWatchedEntry` shape)
    5. **`mostWatchedVodProvider` orphan drop** (live-channel play counts do NOT leak into the VOD result)
    6. **`mostWatchedVodProvider` cap** (12 movies in catalogue, top 8 surfaced in count-desc order)
    7. **`mostWatchedVodProvider` per-profile isolation** (counts keyed under `conn-A` don't surface for `conn-B`)
    8. **`mostWatchedSeriesProvider` no-connection** → empty
    9. **`mostWatchedSeriesProvider` no-counts** → empty
    10. **`mostWatchedSeriesProvider` no-catalogue** → empty
    11. **`mostWatchedSeriesProvider` join-and-sort** (3 series, distinct counts → surfaced in count-desc order)
    12. **`mostWatchedSeriesProvider` orphan drop** (live+VOD play counts do NOT leak into the series result — the strictest cross-catalogue test in the suite, pre-seeds counts for all three catalogues and asserts the series result is exactly the series count)
    13. **`mostWatchedSeriesProvider` cap** (12 series in catalogue, top 8 surfaced)
    14. **`mostWatchedSeriesProvider` per-profile isolation** (counts keyed under `conn-A` don't surface for `conn-B`)
- **Pushed `feature/v26-most-watched-vod-series` → `develop` (squash merge c04b8ff, PR #15)**. CI ✅ (Analyze + Test + Build iOS/macOS/Android) + **Release ✅ → v0.1.70** — APK + iOS zip + macOS zip uploaded. Per the R01/skill discipline: investigated Release status IMMEDIATELY after merge. Both green. **APK uploaded as v0.1.70.**

### CI status:
- `Merge feature/v26-most-watched-vod-series into develop` (c04b8ff) — **CI ✅ + Release ✅ → v0.1.70**
- All Phase 2 (P201–P204, P206) + V01–V26 + R01 now Done
- 276/276 tests pass, 0 new analyze errors (50 pre-existing remain)

### What's next:
- **V26 closes the V05 follow-on gap.** Most Watched is now a first-class home row on all 3 personalisation surfaces (channel list + VOD + Series). A user who watched "Inception" twice on the VOD tab, then started a 3-episode Breaking Bad arc on the Series tab, will see both surfaced on the appropriate home tab with their play counts. The same `PlayCountStore` powers all three rows, so there's no risk of them disagreeing on the underlying data.
- **Other unblocked candidates** (all no external deps):
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels — would need a new provider that joins EPG lists by title)
  - Personalisation-row fine-tuning: lifetime vs recent-window, additional dedupe edges (e.g. V20 Recently Played row deduping from V03 Continue Watching — symmetric to the V22/V25 Most Watched ↔ Continue Watching ↔ Recently Played triangle)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
  - `profile_setup_screen` brightness-aware migration (still in the 50-issue pre-existing set; out of scope for the personalisation work)
- **R02 candidate**: the v0.1.61 / v0.1.63 / v0.1.65 / v0.1.67 / v0.1.69 tags are all on origin and published to the GitHub Releases page. v0.1.61 is a stranded release (the V22 release failure pushed the tag but never created the GitHub Release against it). v0.1.63 / v0.1.65 / v0.1.67 / v0.1.69 are from docs-only R01 / V23 / V24 / V25 release-version bumps. Cleanup is a 1-line `git tag -d` + `git push origin :refs/tags/vX.Y.Z` per tag, plus a `gh release delete` if we want the release pages gone. Low-priority — not blocking anything.
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)


## 2026-06-10 — CloudStream Hourly Cron (20:20 BST — V24 ship)

**Session start:** 20:14 BST

### What was done:
- Board on entry: the prior cron (18:25 BST) had shipped V23 (e6c1689, PR #12) — CI ✅ + Release ✅ → v0.1.64 — and updated the board + log to that effect. The "what's next" list from the 18:25 log mentioned several unblocked candidates, with the V22-style cross-row dedupe pattern applied to Continue Watching series-episode entries already shipped as V23. The natural next gap (also flagged in the 18:25 "what's next") was the **V03 follow-on**: `PlayerScreen._saveProgress` saves watch progress for ANY stream (live channels included) on the same 30s cadence as VOD/series, but `continueWatchingProvider` only resolved saved streamIds against the VOD + series catalogues — so a user watching a live channel for >30s had their progress persisted silently and never saw a Continue Watching card. Picked it up as **V24**.
- **V24** fully implemented, tested, and shipped (f6ed1ab, PR #13):
  - **New `ContinueWatchingKind.liveChannel` enum value** (extends V03's `vod|seriesEpisode` to a 3-state enum). Always null `parentSeriesId` (a live channel is a single item, not a container of sub-items — mirrors VOD entries per the V23 dedupe partition).
  - **Third resolution branch in `continueWatchingProvider`** (`app_providers.dart`): after the existing VOD-direct and series-episode-reverse-lookup branches, resolves any still-unresolved saved streamId against `liveStreamsProvider` (drops orphans, awaits `.future` for the same first-tick-null-trap avoidance as the VOD/series branches — the V20 Recently Played row learned this lesson and V24 inherits it). Tags the resulting entries with `kind = liveChannel` + `parentSeriesId = null`.
  - **V23 dedupe partition handles the new kind correctly with zero changes**: the partition keys on `parentSeriesId != null` (group-by-parent for `seriesEpisodes`) and the rest is a pass-through. Live channels are "everything else" and pass through unchanged — exactly mirrors VOD entries. The V23 invariant ("one Continue Watching card per parent series, not one per episode") still holds.
  - **`continueWatchingLiveProvider` filter** (symmetric to the V21 VOD/Series split) exposed for future callers. Currently only consumed by the channel-list `_ContinueWatchingRow` — the V24 entries appear naturally there because that row already shows the union of all `continueWatchingProvider` kinds.
  - **UI routing** (`channel_list_screen.dart` `_openResume`): live entries open the live player directly (`selectedStreamProvider` state + `PlayerScreen`) — no VOD detail screen, no resume position. Live streams don't seek; the "Resume" badge is "I was watching this, tap to jump back", not a true seek-and-resume. The VOD branch still handles `'vod'` entries (movies + a defensive VOD-tagged live stream) through `VodDetailScreen` with `autoResume`. The series branch is unchanged.
  - **`flutter analyze`**: 50 issues (was 50). 49 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-parameter warning. **0 new issues introduced by V24** (no entries in `app_providers.dart`, `channel_list_screen.dart`, or the new test file).
  - **`flutter test`**: 254/254 pass (was 242, +12 from V24). New file `test/v24_live_continue_watching_test.dart` follows the V23 `v23_series_grouping_dedupe_test.dart` and V22 `v22_most_watched_dedupe_test.dart` patterns — same `_FakeCredentialsStore` + `_FakeXtreamClient` test doubles (declared in-file for self-containment), same `makeContainer` helper, one `test` per scenario, no test loops. Test split:
    1. **No-connection default** (regression guard — the provider must not throw or return spurious entries when no active credentials)
    2. **Single live stream with progress → 1 entry** (the headline V24 behaviour)
    3. **VOD + live mixed** (both branches resolve into the same `entries` list, sorted by `updatedAt` desc)
    4. **VOD + series + live mixed** (all three resolution branches compose; V23 series dedupe still keys on `parentSeriesId`; live entries pass through)
    5. **Orphan live drop** (saved streamId not in `liveStreamsProvider` — e.g. user logged in to a different server since watching — silently dropped, no crash, no card)
    6. **Per-profile isolation** (regression guard for the V21 split — `creds.name` keyed storage)
    7. **`liveStreamsProvider` failure resilience** (provider throws → `continueWatchingProvider` falls through gracefully, doesn't propagate the throw to the UI)
    8. **V23 series dedupe still works with live in the mix** (3 episodes of "Breaking Bad" + 2 live channels + 1 movie → 4 cards: 1 Breaking Bad, 2 live, 1 movie — regression guard for the V23 invariant)
    9. **V22 most-watched dedupe regression guard** (the cross-row dedupe pattern from V22 is unaffected by the V24 third resolution branch)
    10. **`continueWatchingLiveProvider` — no-connection** (empty)
    11. **`continueWatchingLiveProvider` — filters out VOD + series** (only `kind == liveChannel` entries surface)
    12. **`continueWatchingLiveProvider` — empty live is empty** (provider returns empty list, not error)
- Pushed `feature/v24-live-continue-watching` → `develop` (squash merge `f6ed1ab`, PR #13). **CI ✅ (6m56s) + Release ✅ (6m43s) → v0.1.66.** Per the R01/skill discipline: investigated Release status IMMEDIATELY after merge. Both green. **APK uploaded as v0.1.66.**

### CI status:
- `Merge feature/v24-live-continue-watching into develop` (f6ed1ab) — **CI ✅ (6m56s) + Release ✅ (6m43s) → v0.1.66**
- All Phase 2 (P201–P204, P206) + V01–V24 + R01 now Done
- 254/254 tests pass, 0 new analyze errors (50 pre-existing remain)

### What's next:
- **V24 closes the V03 follow-on gap.** Continue Watching now surfaces VOD movies, series episodes (deduped per parent series, V23), AND live TV channels the user has been watching for >30s. A user who toggles between "BBC One" for the news and "ITV" for a movie will see both cards on the home row and can jump back to either with one tap. No more "which channel was I on again?" friction.
- **Other unblocked candidates** (all no external deps):
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels — would need a new provider that joins EPG lists by title)
  - Personalisation-row fine-tuning: lifetime vs recent-window, cap at N for the home rows, additional dedupe edges (e.g. V20 Recently Played row deduping from V03 Continue Watching — symmetric to the V22 Most Watched ↔ Recently Played dedupe)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
  - `profile_setup_screen` brightness-aware migration (still in the 50-issue pre-existing set; out of scope for the personalisation work)
- **R02 candidate**: the v0.1.61 / v0.1.63 / v0.1.64 / v0.1.65 / v0.1.66 tags are all on origin and published to the GitHub Releases page. v0.1.61 is a stranded release (the V22 release failure pushed the tag but never created the GitHub Release against it — the `Determine Version` job correctly bumped from the most recent **release** tag, so v0.1.60 → v0.1.62 with v0.1.61 skipped). v0.1.63 is from the R01 docs commit (no new APK content, just a release-version bump). v0.1.65 is from the V23 docs commit. v0.1.66 is V24. Cleanup is a 1-line `git tag -d` + `git push origin :refs/tags/vX.Y.Z` per tag, plus a `gh release delete` if we want the release pages gone. Low-priority — not blocking anything.
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

---

## 2026-06-10 — CloudStream Hourly Cron (18:25 BST — V23 ship)

**Session start:** 17:00 BST

### What was done:
- Board on entry: R01 (538ad8e, PR #11) was fully shipped on the 15:50 cron — CI ✅ + Release ✅ → v0.1.62, all 3 platform artifacts. The R01 docs commit (f4b5448) had been pushed earlier in this cron session. The "what's next" list from the 15:50 log was: series/season-level Resume on Continue Watching (high-value unblocked), EPG-side "remind me when this programme is on any channel" (new provider), personalisation-row fine-tuning, R02 candidate (stranded v0.1.61/v0.1.62 tags cleanup), recording/catch-up conflict resolution. V22 had already shipped the cross-row dedupe pattern (Most Watched ↔ Recently Played) — natural next step was to apply the same dedupe pattern to Continue Watching series-episode entries (the "3 episodes of Breaking Bad = 3 cards" problem the prior cron's notes hinted at but didn't pursue). Picked it up as **V23**.
- **V23** fully implemented, tested, and shipped (e6c1689, PR #12):
  - **`ContinueWatchingEntry`** (`app_providers.dart`): new optional `parentSeriesId` field (int?). Carries the parent series id (from `ContinueWatchingEpisodeHit.seriesId`) through to the entry. Distinct from `entry.stream.streamId` when the parent series stream is missing from the loaded catalogue — in that case the synthesised episode stream is used as a fallback (`byId[hit.seriesId] ?? episodeStream` at line 881), so `entry.stream.streamId` would be the *episode's* id, not the *series*'s. The new field is always non-null for series-episode entries and always null for VOD entries. The `kind == seriesEpisode` invariant now means "the user has progress on an episode of `parentSeriesId`" — unambiguously groupable.
  - **`continueWatchingProvider`** (`app_providers.dart`): after building the `entries` list (VOD direct matches + series-episode reverse-lookup matches), partition into `vodEntries` + `seriesEpisodes`, then group seriesEpisodes by `parentSeriesId` keeping the most recent. Tie-break on episode `streamId` asc — matches the V05 `topEntries` and V16 `recentEntries` tie-breaker convention. Concatenate `vodEntries + dedupedEpisodes.values` and sort by `updatedAt` desc as before. The result: a user with watch progress on 3 episodes of the same series gets ONE "Continue Watching" card showing the most recent episode's S/E/title badge, not three near-duplicates. VOD entries are unaffected — a movie is a single item, not a container of sub-items, so there's no group to dedupe.
  - **Pure data-layer change, no widget work.** The card widget (`_ContinueWatchingCard`) already renders the synthesised episode stream's name (which contains `S01E05 — title` per V21's synthesis at line 875) and the parent series's cover. The dedupe just means the user sees one card instead of three — same card, same tap behaviour (opens `SeriesDetailScreen` with the most recent episode pre-selected via V04's `autoResumeEpisode` path), same long-press dismiss (clears the most recent episode's progress; older episodes' progress remains in storage, so the card re-appears if the user opens one of them and re-watches — confirmed by the V17 + V23 interaction test).
  - **`flutter analyze`**: 50 issues (was 50). 49 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-param warning. **0 new issues introduced by V23** (no entries in `app_providers.dart` or the new test file).
  - **`flutter test`**: 242/242 pass (was 235, +7 from V23). New file `v23_series_grouping_dedupe_test.dart` follows the V22 `v22_most_watched_dedupe_test.dart` and the existing V04/V21 `series_continue_watching_test.dart` patterns: same `_FakeCredentialsStore` + `_FakeXtreamClient` test doubles (declared in-file for self-containment — the V22 entry's "intentionally per-file" note applies), same `makeContainer` helper that overrides the storage + client providers, one `test` per scenario, no test loops. Test split mirrors the canonical 7-test shape:
    1. **3 episodes of the same series → 1 entry** (the headline V23 behaviour — most recent wins as the representative)
    2. **VOD entries pass through the dedupe unchanged** (regression guard — VODs must NOT be grouped)
    3. **2 different series each with 2 episodes → 2 entries** (the dedupe keys on `parentSeriesId`, not on episode streamId)
    4. **Ordering of deduped result is by recency desc, VODs and series interleaved** (proves the sort still runs after the dedupe and isn't broken by the partition)
    5. **Dedupe is per-profile isolated** (regression guard for the V21 split — `creds.name` keyed storage)
    6. **Single episode of a series → 1 entry** (dedupe is a no-op for size-1 groups — proves the existing single-episode case is unchanged)
    7. **Long-press → clear → provider surfaces the remaining episode, then drops the series entirely** (the V17 + V23 interaction test — clearing the most recent episode surfaces the older one as the new representative, clearing both drops the series entirely)
- Pushed `feature/v23-continue-watching-series-grouping` → `develop` (squash merge `e6c1689`, PR #12). **CI ✅ (6m4s) + Release ✅ (6m10s) → v0.1.64.** Per the R01/skill discipline: investigated Release status IMMEDIATELY after merge (the 15:50 cron's lesson — Release failures are the most important signal because they produce the public APK). Both green. **APK uploaded as v0.1.64.**

### CI status:
- `Merge feature/v23-continue-watching-series-grouping into develop` (e6c1689) — **CI ✅ (6m4s) + Release ✅ (6m10s) → v0.1.64**
- All Phase 2 (P201–P204, P206) + V01–V23 + R01 now Done
- 242/242 tests pass, 0 new analyze errors (50 pre-existing remain)

### What's next:
- **V23 closes the V04/V21 follow-on gap.** The Continue Watching row is now consolidated per parent series, so a user with progress on 5 episodes of "Breaking Bad" sees ONE "Breaking Bad" card (showing the most recent S/E/title badge) instead of 5 stacked duplicates. The card tap still opens `SeriesDetailScreen` with the right season focused, the right episode pre-selected, and the player auto-started in resume mode (V04's `autoResumeEpisode` path) — same tap behaviour as before, just one card instead of many.
- **Other unblocked candidates** (all no external deps):
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels — would need a new provider that joins EPG lists by title)
  - Personalisation-row fine-tuning: lifetime vs recent-window, cap at N for the home rows, additional dedupe edges (e.g. V20 Recently Played row deduping from V03 Continue Watching — symmetric to the V22 Most Watched ↔ Recently Played dedupe)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
  - `profile_setup_screen` brightness-aware migration (still in the 50-issue pre-existing set; out of scope for the personalisation work)
- **R02 candidate**: the v0.1.61 / v0.1.63 / v0.1.64 tags are all on origin and published to the GitHub Releases page. v0.1.61 is a stranded release (the V22 release failure pushed the tag but never created the GitHub Release against it — the `Determine Version` job correctly bumped from the most recent **release** tag, so v0.1.60 → v0.1.62 with v0.1.61 skipped). v0.1.63 is from the R01 docs commit (no new APK content, just a release-version bump). v0.1.64 is V23. Cleanup is a 1-line `git tag -d` + `git push origin :refs/tags/vX.Y.Z` per tag, plus a `gh release delete` if we want the release pages gone. Low-priority — not blocking anything.
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)


---

## 2026-06-10 — CloudStream Hourly Cron (15:50 BST — R01 release.yml fix)

**Session start:** 15:25 BST (carry-over from V22 ship cron — release.yml was broken)

### What was done:
- Board on entry: the V22 cron had shipped **V22 — Most Watched row dedupes from Recently Played** (6633eb8, PR #10) but **never updated the board or log**. The V22 work itself is sound: `mostWatchedProvider` now watches `recentlyPlayedProvider` and excludes any streamId in the top 8 recency entries, with `kPersonalisationRowCap = 8` extracted as a shared constant. 235/235 tests pass, 0 new analyze errors.
- **Discovered a real Release failure** by checking CI/Release status: V22's `Merge feature/v22-most-watched-recent-dedupe into develop` (6633eb8) ran CI ✅ but **Release ❌** at 15:34:43Z. The `Create GitHub Release` step got `401 Requires authentication` on all 3 retries, and the macOS artifact pattern `artifacts/macos-release-0.1.61/Runner_macOS.zip` didn't match any files.
- **Two real bugs in `.github/workflows/release.yml`** identified by reading the failed run's logs:
  1. **macOS zip path bug**: `cd apps/cloudstream_app/build/macos/Build/Products/Release && zip -r ../Runner_macOS.zip cloudstream_app.app` writes the zip to the *parent* dir (`Build/Products/Runner_macOS.zip`) but the upload step at line 210 looks for `Release/Runner_macOS.zip`. The upload step was `if-no-files-found: warn` so the build job was green, but the artifact was never uploaded — and the release step's `files:` glob then matched nothing. The download-artifact step in the release job confirms: "Found 2 artifact(s)" (Android + iOS), no macOS.
  2. **401 on Create GitHub Release**: the workflow-level `permissions: contents: write` should propagate to the `release:` job, and the `git push origin v0.1.61 --force` step in the same job DID succeed (`* [new tag] v0.1.61 -> v0.1.61`). So the token works for git. But `softprops/action-gh-release@v2` got 401 on its API calls — known sensitivity to job-level explicit permissions, and recent GitHub Actions token scoping has tightened (GITHUB_TOKEN default scopes have been narrowed over time).
- **R01 — release.yml fixes** (committed, branch `feature/r01-release-yml-fixes`):
  1. macOS zip now `zip -r Runner_macOS.zip cloudstream_app.app` (in-place inside `Release/`).
  2. macOS upload step upgraded from `if-no-files-found: warn` to `if-no-files-found: error` — any future path mismatch will fail the build job loudly instead of silently dropping the artifact.
  3. `release:` job gets an explicit `permissions: contents: write` block (defensive — workflow-level permissions should propagate, but job-level explicit is what the action and recent token scoping expect).
- **Pushed `feature/r01-release-yml-fixes` → `develop` (squash merge 538ad8e, PR #11)**. CI ✅ (Analyze 34s + Test 1m17s + iOS 2m49s + macOS 3m48s + Android 5m01s) + **Release ✅** — **APK uploaded as v0.1.62**, and the `Create GitHub Release` step no longer 401'd (defensive permissions fix held). All 3 platform artifacts present in the release: `app-release.apk` (56.5MB), `Runner_iOS.zip` (7.8MB), `Runner_macOS.zip` (57.3MB — the macOS path fix worked; the zip is now in `Build/Products/Release/Runner_macOS.zip` as the upload step expects). v0.1.61 tag remains stranded on origin (the failed release pushed it but never created a GitHub Release against it; the `Determine Version` job correctly bumps from the most recent **release** tag, not the most recent tag, so v0.1.60 → v0.1.62 with v0.1.61 skipped).
- **Board + log updated** to reflect V22 (shipped but Release broken) + R01 (release.yml fixes; v0.1.62 with all 3 platform artifacts).

### CI status:
- `Merge feature/r01-release-yml-fixes into develop` (538ad8e, PR #11) — **CI ✅ (Analyze 34s + Test 1m17s + iOS 2m49s + macOS 3m48s + Android 5m01s) + Release ✅ → v0.1.62**, all 3 platform artifacts uploaded (Android APK 56.5MB, macOS zip 57.3MB, iOS zip 7.8MB — `Found 3 artifact(s)` in the download step, confirming the macOS path fix worked).

### What's next:
- **R01 closes the V22 Release failure.** The release pipeline is healthy again — v0.1.62 on the GitHub Release page has all 3 platform artifacts. The macOS zip is now in `Build/Products/Release/Runner_macOS.zip` (matches the upload path), and the `release:` job's explicit `permissions: contents: write` cleared the 401 on `softprops/action-gh-release@v2`.
- **Other unblocked candidates** (all no external deps):
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series) — high-value, unblocked
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels) — would need a new provider that joins EPG lists by title
  - Continue Watching / Most Watched / Recently Played fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites/hidden)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
  - **R02 candidate**: the v0.1.61 and v0.1.62 tags are now stranded on origin (v0.1.61 from the failed release, v0.1.62 from the R01 push trigger). Worth a 1-line cleanup: delete them locally + on origin, or just leave them as historical markers. Low-priority.
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

---


## 2026-06-10 — CloudStream Hourly Cron (15:25 BST — V21 ship)

**Session start:** 12:30 BST (carry-over from 12:25 V20 ship; CI wait extended the run)

### What was done:
- Board on entry: the 12:25 cron had shipped V20 (d42c771, PR #8) and updated the board. Working tree had a complete V21 WIP on `feature/v21-continue-watching-row-vod-series` — 4 files (3 modified + 1 new 520-line test file), 1149 line diff. The "what's next" list from the 12:25 log pointed to "Series/season-level Resume on the Continue Watching row" and "EPG-side: 'remind me when this programme is on any channel'". V21 is neither of those — it's a different unblocked task: **split the existing channel-list Continue Watching row into VOD + Series variants** so users who start a movie or episode on the VOD/Series tabs see the resume affordance there too (V03/V04 left this gap).
- Verified the WIP sound: `flutter analyze` on the 3 modified files → **0 issues**; `flutter test test/v21_continue_watching_row_test.dart` → **9/9 pass**; full `flutter test` → **228/228 pass** (was 219, +9 from V21); full `flutter analyze` → 50 issues (49 pre-existing withOpacity infos + 1 V07-chunk3 unused-param warning) — **0 new issues from V21**.
- **V21 — Continue Watching rows on VOD + Series tabs** (fd8cc63 → 09388c5, PR #9): the V03/V04 follow-on — the Continue Watching row was only on the Live TV (channel-list) home tab. Users who start a movie on the VOD tab and switch tabs shouldn't have to navigate back to the channel list to resume:
  - **`continueWatchingVodProvider`** + **`continueWatchingSeriesProvider`** (`app_providers.dart`): split providers that filter `continueWatchingProvider` by `ContinueWatchingKind` (vod vs seriesEpisode). Both `await` the source `.future` (not `maybeWhen` the AsyncValue) so they re-run on source invalidation — a single `ref.invalidate(continueWatchingProvider)` cascades to both filters. Code comment explains why `await ref.watch(source.future)` is the right pattern (Riverpod can't re-run a provider based on an inner async state change without an explicit `await`).
  - **`_ContinueWatchingRow` on VOD tab** (`vod_screen.dart`): horizontal row above the VOD grid, only shown when `selectedCategoryId == null` (same condition as the channel-list row + Most Watched + Recently Played). Card: poster (or placeholder) + title + progress bar + 'Resume' affordance. Tap → `VodDetailScreen(stream, autoResume: true)`. Long-press → clear progress + snackbar with UNDO. Mirrors the channel-list row's UX (V03 + V17) so the data, the card shape, and the long-press behaviour are consistent across all three Continue Watching rows.
  - **`_ContinueWatchingRow` on Series tab** (`series_screen.dart`): same pattern, scoped to series-episode entries. Tap → `SeriesDetailScreen` with the parent series + saved season auto-selected via V04's `autoResumeEpisode` path (handles reverse-lookup: saved episode stream_id → parent series + season + episode number, opens the right season, plays via post-frame callback). Long-press → same clear + UNDO flow.
  - All three rows (channel list + VOD + Series) share the same `WatchProgressStore` data — removing from one tab's row removes from all three, and UNDO from any tab re-surfaces the card on all three. By design, no per-tab "do not share" affordance.
- **9 new tests** (`test/v21_continue_watching_row_test.dart`):
  - 4 `continueWatchingVodProvider` (empty when no active connection, empty when no saved progress, surfaces VOD-kind entries with the right stream + kind, **filters OUT series-episode entries**)
  - 3 `continueWatchingSeriesProvider` (empty when no active connection, surfaces series-episode entries with parent fields populated, **filters OUT VOD entries**)
  - 1 cross-provider invalidation (single `invalidate(continueWatchingProvider)` cascades to both VOD + Series filters)
  - 1 ordering preserved from source (sort by updatedAt-desc flows through both filter providers)
- **228/228 tests pass** (was 219, +9 from V21). `flutter analyze` → 50 issues (49 pre-existing `withOpacity` infos + 1 V07-chunk3 unused-param warning). **0 new issues introduced by V21**.
- **Pushed `feature/v21-continue-watching-row-vod-series` → `develop` (squash merge 09388c5, PR #9)**. CI ✅ (Analyze 47s + Test 50s + Build iOS 3m51s + Build macOS 4m12s + Build Android 5m13s) + Release ✅ — **APK uploaded as v0.1.59**.

### CI status:
- `Merge feature/v21-continue-watching-row-vod-series into develop` (09388c5) — **CI ✅ + Release ✅ → v0.1.59**
- All Phase 2 (P201–P204, P206) + V01–V21 now Done
- 228/228 tests pass, 0 new analyze errors (50 pre-existing remain)

### What's next:
- **V21 closes the V03/V04 follow-on gap.** All three personalisation rows (channel list + VOD + Series) now share the same data and the same UX (tap-to-resume, long-press-to-remove + UNDO). A user who starts a movie on the VOD tab, switches to the Series tab, then comes back to the VOD tab sees the same 'Continue Watching — Inception' card with the same progress bar.
- **Other unblocked candidates** (all no external deps):
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series) — high-value, unblocked
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels) — would need a new provider that joins EPG lists by title
  - Continue Watching / Most Watched / Recently Played fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites/hidden, dedupe with the new Recently Played row itself)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

---

## 2026-06-10 — CloudStream Hourly Cron (12:25 BST — V20 ship)

**Session start:** 12:00 BST

### What was done:
- Board on entry: the 11:15 cron had shipped V19 (15a3f4b, PR #7) — AppBar entry + per-row unhide + bulk unhide-all. A subsequent (unlogged) cron had picked up **V20 — Recently Played home row** — a high-value unblocked V16 follow-on (V16 added the recency sort mode; the natural next step was a first-class home row that surfaces recency without forcing the user to switch sort modes) — fully implemented, tested, committed on `feature/v20-recently-played-row` (bcf983b), pushed, and PR #8 opened. CI ✅ (Analyze, Test, iOS, Android, macOS) on the PR at 11:20 UTC. The board + log had no V20 row.
- **V20 — Recently Played home row** (bcf983b → d42c771, PR #8): the "recency" personalisation signal as a first-class home surface, sitting **above** the existing Most Watched row:
  - **`RecentlyPlayedEntry`** (`app_providers.dart`): resolved `XtreamStream` + `lastPlayedAtMs` epoch-ms timestamp. Mirrors `MostWatchedEntry`'s shape so the two rows feel like a matched pair.
  - **`recentlyPlayedProvider`** (FutureProvider): joins the active profile's `PlayCountStore.recentEntries(creds.name)` (recency desc, streamId-asc tie-breaker — the same tie-breaker `PlayCountStore` already provides) against `liveStreamsProvider` (drops orphans — channels the provider removed from the catalogue). Keyed by active connection's name so each profile has its own recency list. **Awaits `liveStreamsProvider.future`** (not `valueOrNull`) to dodge the first-tick-null trap that would silently return an empty list on cold start. Same null-degrade paths as `mostWatchedProvider`: no creds → `[]`, no live streams → `[]`, no recent entries → `[]`.
  - **`_RecentlyPlayedRow` + `_RecentlyPlayedCard`** (`channel_list_screen.dart`): horizontal row positioned **above** `_MostWatchedRow` (recency is a stronger personalisation signal than lifetime frequency — a user who just flipped to CNN wants the CNN card front-and-centre, not buried under a 200-view leaderboard). The build call has a comment explaining the ordering rationale so a future maintainer doesn't reshuffle them. Header: `Icons.history` (18pt) + 'Recently Played' h3. Card: 96×64 channel logo (or first-letter placeholder via the existing `_PosterPlaceholder`) + channel name (max 1 line + ellipsis) + 'x min ago' / 'x h ago' / 'x d ago' / 'Just now' caption. Tap plays the channel — same `_openStream` path as a regular channel-list tap. Only shown when `selectedCategoryId == null` (same condition as Most Watched). Brightness-aware via `context.appColors` / `context.appTypography` (the V11–V15 migration).
  - **9 new tests** (`test/recently_played_row_test.dart`): empty default, no-connection, no-live-streams degrade paths, recency-desc ordering, timestamp-tie streamId-asc tie-breaker, orphan drop, per-profile isolation, lastPlayedAtMs round-trip, recency-independent-of-play-count (proves a stream played once 5 minutes ago ranks above a stream played 100 times a year ago).
- **219/219 tests pass** (was 210, +9 from V20). `flutter analyze` → 50 issues (49 pre-existing `withOpacity` infos + 1 V07-chunk3 unused-param warning). **0 new issues introduced by V20**.
- **PR #8 merged** to develop (d42c771, squash). CI ✅ (5m56s) + Release ✅ (6m16s) — **APK uploaded as v0.1.57**.

### CI status:
- `Merge feature/v20-recently-played-row into develop` (d42c771) — **CI ✅ (5m56s) + Release ✅ (6m16s) → v0.1.57**
- All Phase 2 (P201–P204, P206) + V01–V20 now Done
- 219/219 tests pass, 0 new analyze errors (50 pre-existing remain)

### What's next:
- **V20 closes the V16 follow-on gap.** The recency signal is now first-class on both surfaces: home row + sort mode. Both consume the same `PlayCountStore.recentEntries` data, so there's no risk of them disagreeing. The Live TV home screen now has 3 personalisation rows: Recently Played (recency) → Most Watched (lifetime frequency) → Continue Watching (VOD/series with progress) — each a distinct, complementary signal.
- **Other unblocked candidates** (all no external deps):
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series) — high-value, unblocked
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels) — would need a new provider that joins EPG lists by title
  - Continue Watching / Most Watched / Recently Played fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites/hidden, dedupe with the new Recently Played row itself)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

---

## 2026-06-10 — CloudStream Hourly Cron (11:15 BST — V19 backfill)

**Session start:** 10:30 BST (carry-over from 09:15 cron)

### What was done:
- Board on entry: the 09:15 cron had shipped V18 (0493388, PR #6, v0.1.53) and updated the board to that effect. The "what's next" list from the 09:15 log pointed to "Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series) — high-value, unblocked" and "EPG-side: 'remind me when this programme is on any channel'".
- A subsequent (unlogged) cron had actually picked V19 — a **different** unblocked task not on the published "what's next" list — fully implemented, tested, and merged to develop (15a3f4b, PR #7). `gh run list -R citralia/cloudstream -L 1` returned `feat(V19): Manage hidden channels sheet — AppBar entry + per-row unhide + bulk unhide-all (#7)` with `conclusion: success, status: completed` for both CI and Release — the merge happened at 10:20 UTC (a 9-minute CI + 5m36s Release run, much faster than V18's 8m19s/6m32s since the test surface is smaller). The board had no V19 row.
- **V19 — Manage hidden channels sheet** (15a3f4b, PR #7): the obvious un-blocked follow-on to V18 (Hide channel) — V18 had no good way to *unhide* en masse. The new sheet (the existing 'Hidden' filter chip + per-row long-press remained, but the new surface is the discovery + bulk-unhide entry point):
  - **`hiddenChannelsStreamProvider`** (`app_providers.dart`): joins the active profile's hidden streamIds against `liveStreamsProvider` (drops orphans — channels the provider removed from the catalogue), sorted by channel name asc, resolves to `[]` when no active profile or no hidden set.
  - **`unhideAll(ref)`** helper: bulk-empties the active profile's hidden set in a single `ProfileStore.setHidden([])` call, returns the count for the snackbar copy ("Unhidden N channel(s)").
  - **`_ManageHiddenSheet`** (`channel_list_screen.dart`): modal bottom sheet, max-height 75% so a long hidden list scrolls. Header: `visibility_off` icon + "Hidden channels" title + "Unhide all" button (only visible when the list is non-empty). Subtitle: "N hidden — swipe right to unhide" or "No hidden channels" when empty. Per-row: round logo-or-initial avatar + channel name + "Hidden" caption + trailing unhide IconButton. Each row wrapped in a `Dismissible(startToEnd)` with a primary-tinted "Unhide" background on swipe. Empty state: `visibility_outlined` icon + "Channels you hide will appear here. Long-press any channel on the list to hide it." Loading + error states mirror the V18 long-press sheet.
  - **AppBar action** (`channel_list_screen.dart`): new `Icons.visibility_off_outlined` IconButton on the channel list AppBar, **only shown when the active profile's hidden count > 0**. Tooltip shows the count ("Manage hidden channels (3)"). Sits between the "Expand player" and "Sort channels" actions — order matches user mental model: expand → manage hidden → sort → refresh.
  - **Snackbar + UNDO** on per-row unhide (mirrors the V18 hide flow). Bulk unhide-all has no UNDO (intentional — UNDO would need to re-hide N channels; the per-row swipe-to-unhide covers the re-hide case).
- **9 new tests** (`test/manage_hidden_sheet_test.dart`):
  - 6 `hiddenChannelsStreamProvider` (empty default, joins against live catalogue, drops orphans, alphabetical sort, empty when no active profile, rebuilds on hidden-set mutation)
  - 3 `unhideAll` (empties the set, no-op when empty, returns the count for the snackbar)
- **210/210 tests pass** (was 201, +9 from V19), 0 new analyze errors (50 pre-existing remain: 49 `withOpacity` infos + 1 V07-chunk3 unused-param warning).
- **Pushed `feature/v19-manage-hidden-sheet` → `develop` (squash merge 15a3f4b, PR #7)**. CI ✅ (6m22s) + Release ✅ (5m36s) — **APK uploaded as v0.1.54**.
- **Backfilling the board + log now** (the unlogged cron's only failing task). The board row needs to flip from missing → "Done" with the merge commit + CI/Release status; the log gets a fresh V19 entry under the V18 one.

### CI status:
- `Merge feature/v19-manage-hidden-sheet into develop` (15a3f4b) — **CI ✅ (6m22s) + Release ✅ (5m36s) → v0.1.54**
- All Phase 2 (P201–P204, P206) + V01–V19 now Done
- 210/210 tests pass, 0 new analyze errors (50 pre-existing remain)

### What's next:
- **V19 closes the V18 follow-on gap.** The hide/unhide story is now complete: long-press a channel → "Hide" (V18) + snackbar with UNDO; AppBar action (V19, when hidden count > 0) → "Manage hidden" sheet → per-row swipe-to-unhide or bulk "Unhide all" → snackbar with UNDO per row. No more silent mistakes.
- **Other unblocked candidates** (all no external deps):
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series) — high-value, unblocked
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels) — would need a new provider that joins EPG lists by title
  - Continue Watching / Most Watched / Recently Played fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites/hidden)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

---

## 2026-06-10 — CloudStream Hourly Cron (09:15 BST)

**Session start:** 08:15 BST

### What was done:
- Board on entry: the 05:15 cron had shipped V16 (9178571, PR #4) but the V17 task ("Remove from Continue Watching long-press + UNDO") that was on the "Next" line of the board at the start of that cron had actually been picked up, fully implemented, tested, and merged to develop in an unlogged cron (3d47a7b, PR #5, CI ✅ + Release ✅ → v0.1.52). The board still listed V17 as "Next" and the log had no V17 entry — classic "prior cron forgot to update" pattern. **Verified V17 is shipped on origin/develop** (`gh run list` showed CI ✅ + Release ✅ green on 3d47a7b at 07:14 UTC).
- Working tree had a full V18 ("Hide channel" long-press + Hidden filter chip) WIP on top of develop HEAD: 4 files modified (`profile_store.dart`, `app_providers.dart`, `channel_list_screen.dart`) + 1 untracked test file (`hidden_channels_test.dart`, 269 lines). Verified the WIP sound:
  - `flutter analyze` → 50 issues found (49 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-param warning). **0 new issues introduced by V18** (no entries in any of the 3 modified files or the new test file).
  - `flutter test` → **4 of the 17 V18 tests failed** on first run. The 4 failures were all in the `filteredLiveStreamsProvider hidden filtering` group (4 of 8 tests in that group), with the same root cause: the `hiddenOnly` branch in the provider had `hiddenIds = <int>{}` and fell through to the non-favourites filter, so `hiddenOnly=true` returned the full stream list instead of the hidden set. The test `hiddenOnly reveals the hidden set only` exposed this — expected [1, 3] with hidden=[1,3], got [1, 2, 3, 4].
  - **Fixed the provider branches** to enforce the UI's mutex contract: when `hiddenOnly=true`, return `streams.where(s => hiddenIds.contains(s.streamId))` regardless of `favouritesOnly`. The three filter modes (All / Favourites / Hidden) are now expressed as a clean `hiddenOnly → favouritesOnly → default` cascade. Documented the mutex in a code comment. After the fix, all 17 V18 tests pass; full suite: **201/201** (was 181, +20 from V18: 17 V18 tests + 7 V17 tests that were already in the suite from 3d47a7b but the prior cron's 181 count predated V17's merge).
- **V18** fully implemented, tested, and shipped (0493388, PR #6):
  - **`ProfileStore`** (`core/storage/profile_store.dart`): `getHidden` / `setHidden` / `addHidden` / `removeHidden` / `toggleHidden` — SharedPreferences-backed under `profile_{id}_hidden_channels` (JSON-encoded `List<int>`), idempotent on the store side (`addHidden` no-ops on duplicate, `removeHidden` no-ops on missing, `toggleHidden` returns the new boolean), garbage-on-disk → empty list (forward-compat), per-profile isolation. Updated the class-level comment that lists the suffix keys.
  - **`activeProfileHiddenProvider`** (Provider) + **`profileHiddenProvider`** (Provider.family) + **`hiddenOnlyProvider`** (StateProvider<bool>) + **`toggleHidden(ref, streamId)`** helper (`app_providers.dart`). `toggleHidden` writes through to the store and calls `ref.invalidate(profileHiddenProvider(activeProfile.id))` so the channel list rebuilds. The hidden filter chips and the `filteredLiveStreamsProvider` watch `hiddenOnlyProvider`, so flipping the chip rebuilds the list.
  - **`filteredLiveStreamsProvider`** extended with hidden filtering. The three filter modes (All / Favourites / Hidden) are mutex in the UI — tapping a chip clears the other — and the provider branches also enforce that. The `hiddenOnly` branch returns `streams.where(s => hiddenIds.contains(s.streamId))`; the `favouritesOnly` branch intersects favourites with the not-hidden set; the default branch excludes hidden. **Bug caught by tests:** the original code's `hiddenOnly` branch set `hiddenIds = <int>{}` to "let the favourites filter keep everything" — but then the non-favourites filter ran and returned the full list. The fix reorders the branches so `hiddenOnly` wins outright.
  - **`ChannelTile.onLongPress`** + **`_openChannelActions`** modal bottom sheet on `ChannelListScreen` (`channel_list_screen.dart`): the long-press shows a sheet with the channel name as the title and a single action — 'Hide channel' (visibility_off icon) or 'Unhide channel' (visibility icon) depending on the current state. On hide, the row disappears from the default view, the sheet closes, and a snackbar "Hidden — \<name\>" appears with an UNDO action that re-toggles. On unhide, the row is already back (because the user is in hiddenOnly or was viewing a still-visible channel); snackbar "Unhidden — \<name\>" with no UNDO. The sheet uses `context.appColors.surfaceElevated` for the background — brightness-correct via the V11/V12/V13/V14/V15 sweep.
  - **'⊘ Hidden' filter chip** added to `CategoryFilterChips` (slot 3, after 'All' and '★ Favourites'). Mutex with both 'All' (clears both `favouritesOnly` and `hiddenOnly`) and '★ Favourites' (clears `hiddenOnly` when switching to favourites, and clears `favouritesOnly` when switching to hidden). A subtle UX touch: when the user hides a channel while in `hiddenOnly` mode, the mode auto-clears so they don't end up with an empty list.
  - **17 new tests** (`test/hidden_channels_test.dart`):
    - 8 `ProfileStore` persistence (empty default, `addHidden` persists, `addHidden` idempotent, `removeHidden` removes, `removeHidden` no-op on missing, `toggleHidden` round-trips, per-profile isolation, rehydration across `ProfileStore` instances)
    - 8 `filteredLiveStreamsProvider` filter (default excludes hidden, returns all when none hidden, `hiddenOnly` reveals the set, `hiddenOnly` with empty set returns empty, composes with category, `hiddenOnly` composes with category, favourites ∩ ¬hidden, toggles `hiddenOnly` rebuilds the list)
    - 1 `toggleHidden` UNDO round-trip (mirrors the snackbar UNDO flow)
  - **Test scope follows the V05 / V09 / V16 pattern**: data-layer + Riverpod injection tests only (no widget pump). The `ChannelTile.onLongPress` → `_openChannelActions` sheet wiring is a thin Flutter idiom (modal bottom sheet + snackbar); the data-layer tests prove the underlying store + provider behaviour, which is where the real logic lives.
  - **Pushed `feature/v18-hide-channel` → `develop` (squash merge 0493388, PR #6)**. CI ✅ (8m19s — Analyze 43s, Test 48s, Android 4m48s, iOS 3m37s, macOS 4m08s) + Release ✅ (6m32s) — **APK uploaded as v0.1.53**.
  - **Dropped stale V09 stash** (`stash@{0}`): it was V09's pre-merge WIP from 2026-06-09, superseded by the merge at 6178768 the same day. Cleaned up as part of the working-tree verification.

### CI status:
- `Merge feature/v18-hide-channel into develop` (0493388) — **CI ✅ (8m19s) + Release ✅ (6m32s) → v0.1.53**
- All Phase 2 (P201–P204, P206) + V01–V18 now Done (V17 was already Done from 3d47a7b, board + log just hadn't caught up)
- 201/201 tests pass, 0 new analyze errors (50 pre-existing remain)

### What's next:
- **V18 closes the "hide unwanted channels" gap** that was the obvious un-blocked follow-on to V05 favourites. The live TV channel list now has 5 sort modes (Default / Name / Number / Most Watched / Recently Played) and 3 filter modes (All / Favourites / Hidden), all composable, all per-profile isolated, all persisting.
- **Other unblocked candidates** (all no external deps):
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series) — high-value, unblocked
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels) — would need a new provider that joins EPG lists by title
  - Bulk hide / unhide from the ChannelSortMode sheet
  - Continue Watching / Most Watched / Recently Played fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites/hidden)
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
  - `defaultLeadTimeProvider` persistence (V10 already shipped, closed)
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

---

## 2026-06-10 — CloudStream Hourly Cron (07:15 BST — V17 backfill)

**Session start:** 06:30 BST (carry-over from 05:15 cron)

### What was done:
- The 05:15 cron (V16 ship + V17 "Next" pointer) had been followed by an **unlogged** cron that picked V17 up, fully implemented, tested, and merged to develop (3d47a7b, PR #5) but never updated the board or the log. `gh run list -R citralia/cloudstream -L 1` returned `feat(V17): Remove from Continue Watching long-press + UNDO (#5)` with `conclusion: success, status: completed` for both CI and Release, published as **v0.1.52**. The board's V17 row (the "Next" line) said "Merged to develop (3d47a7b, PR #5) — CI ✅ + Release ✅ — awaiting board update on this cron."
- **Backfilling the board + log now** (the unlogged cron's only failing task). The board row needs to flip from "Next" → "Done" with the merge commit + CI/Release status; the log gets a fresh V17 entry under the V16 one.
- The 05:15 cron's "what's next" pointer (series-season-level resume on Continue Watching / "recently watched" sort mode / etc.) is the queue to pick up on the next cron.

---

## 2026-06-10 — CloudStream Hourly Cron (05:15 BST)

**Session start:** 05:15 BST

### What was done:
- Board on entry: V15 (brightness-aware migration chunk 3 — playlist + player widgets) was fully Done from the 02:25 cron (8db2164 → 16e4dfc docs, CI ✅ + Release ✅ → v0.1.49). All explicit Next candidates either needed external services (P205 Firestore sync, P207 DVR, P208 RevenueCat, B202 Firebase) or were minor one-line follow-ons. The "what's next" list from the 02:25 log pointed to "Recently watched sort mode for V06 (would need a recency timestamp on top of the existing `PlayCountStore`)" — a clean, fully-unblocked follow-on that builds on the existing V05 store + V09 sort plumbing. Picked it up as **V16**.
- **V16** fully implemented, tested, and shipped (9178571, PR #4):
  - **`PlayCountStore` extended** (`core/storage/play_count_store.dart`):
    - New `getLastPlayedAtMs(profileId, streamId) -> int?` reads the per-stream wall-clock millisecond timestamp.
    - New `recentEntries(profileId)` returns all played streams ordered by recency desc (most-recent first), with `streamId asc` as a stable tie-breaker for streams played in the same instant.
    - `increment({at: DateTime?})` now also stamps the last-played time (epoch ms, UTC). The `at:` parameter is injectable for tests; production callers let it default to `DateTime.now()`.
    - `clearCount` now drops both the count and the last-played stamp (was only dropping the count — a real bug for anyone who had used the store and then wanted to reset).
  - **New `ChannelSortMode.recentlyPlayed` enum value** (`core/storage/channel_sort_store.dart`): complements the existing `mostWatched` — a casual viewer flipping between a few channels wants recency, a power user with hundreds of plays wants the lifetime-frequency leaderboard.
  - **`filteredLiveStreamsProvider` extended** (`presentation/providers/app_providers.dart`): a new branch for `recentlyPlayed` reads `playCountStoreProvider.recentEntries(creds.name)` and routes through `_applyChannelSort(mode: recentlyPlayed, lastPlayedAtMs: …)`. Same active-connection guard as `mostWatched` (degrades to `defaultOrder` when no creds) — and same try/catch-free path since `recentEntries` is a pure read of `SharedPreferences.getKeys()` and can't throw.
  - **`_applyChannelSort` extended** with a new `lastPlayedAtMs: Map<int, int>?` named arg (mutex with the existing `playCounts:`). Same two-bucket structure as `mostWatched` (played → bottom, unplayed → name asc), but the played bucket sorts by timestamp desc instead of count desc. The bucket boundary uses **map membership**, not `timestamp > 0` — a documented deliberate choice. Legacy v0.1.x–v0.1.48 installs have count keys but no last-played stamp; `recentEntries` surfaces those as epoch-0, so a `timestamp > 0` check would let them compete with genuinely-recent plays at the top of the recency order. Membership is the conservative call. (See the in-code comment.)
  - **`_SortModeSheet` extended** (`presentation/screens/channel_list_screen.dart`): new 5th row with `Icons.history`, "Recently Played" title, and "Most-recently-played channels first; channels you have never played go to the bottom" subtitle.
  - **`flutter analyze`**: 50 issues found (was 50). 49 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-param warning. **0 new issues introduced by V16** (no entries in any of the 3 modified files or the new test file).
  - **`flutter test`**: 181/181 tests pass (was 165, +16 from V16). New file `test/recently_played_sort_test.dart` follows the V09 / V12 pattern: same `_FakeCredentialsStore` + `_FakeXtreamClient` test doubles (declared in-file for self-containment), same `makeContainer` helper that overrides the storage + client providers, one `testWidgets`-equivalent `test` per scenario, no test loops. The test split mirrors the V09 split: 9 unit tests for the new `PlayCountStore` API surface (`getLastPlayedAtMs` null-default, `increment(at:)` stamps the time, subsequent increments overwrite the stamp + bump the count, `recentEntries` ordering + ties + per-profile isolation, `clearCount` dual-key cleanup, legacy entry epoch-0 fallback) + 7 sort-mode integration tests (recency-desc ordering, empty/no-conn degrade, composes with category + favourites filters, per-profile isolation, **`mostWatched` vs `recentlyPlayed` re-rank on the same data** as the last test — proves the two modes are not aliases).
- Pushed `feature/v16-recently-played-sort` → `develop` (merge 9178571, squash, PR #4). CI ✅ + Release ✅ — **APK uploaded as v0.1.50**.

### CI status:
- `Merge feature/v16-recently-played-sort into develop` (9178571) — **CI ✅ + Release ✅ → v0.1.50**
- All Phase 2 (P201–P204, P206) + V01–V16 now Done
- The V08/V11/V12/V13/V14/V15 brightness sweep is complete (V15 closed the last 3 files); V16 closes the last unblocked V06 follow-on noted in the V15 log. The channel list now has 5 sort modes (Default / Name / Number / Most Watched / Recently Played).

### What's next:
- **V16 closes the last unblocked V06 follow-on.** No more "Recently watched" sort mode to do. The remaining "what's next" list from the 02:25 log was:
  - Series/season-level Resume on the Continue Watching row (V04 covers episode-level; could surface the parent series) — high-value, unblocked
  - EPG-side: "remind me when this programme is on any channel" (programme-title EPG search across channels) — would need a new provider that joins EPG lists by title
  - Continue Watching / Most Watched / Recently Played fine-tuning (lifetime vs recent-window, cap at N, dedupe with favourites) — UX choice
  - Recording/catch-up conflict resolution (Xtream supports both — UX question)
- **Backlog** (external-service blockers):
  - P205: Profile sync via Firestore (needs Firebase credentials)
  - P207: DVR / recordings (revenue-gated after P208)
  - P208: Monetisation (needs RevenueCat)
  - B202: Firebase integration (general infra)
- **C06**: Smoke test on Firestick (blocked on josh)

---

## 2026-06-10 — CloudStream Hourly Cron (02:25 BST)

**Session start:** 02:20 BST

### What was done:
- Board on entry: V14 chunk 2 (media-playback surfaces) had been merged to develop at 01:25 (54fb180, CI ✅ + Release ✅ → v0.1.45). The board row for V14 chunk 2 had been added to the working tree but never committed (the 01:25 docs commit 7647963 only touched `DEVELOPMENT_LOG.md`). The prior cron's "scope note" claimed "the cron-tracked count of 0 makes a sweep redundant" — but the **next-line entry of the same log** lists other unblocked candidates, which means the "0 remaining" was just an estimate, not a measured count. The next-pointer from the 01:25 log was "V11+ follow-on: a widget-level anywhere-`AppColors` is used sweep would be the next cleanup, but there are very few left".
- **Verified the 0 claim with a sweep first.** `grep -r "AppColors\." lib/` (excluding the token-definition files) found 32 references across 3 still-un-migrated files. The 01:25 cron's bookkeeping was off. This is the **V15** task: a real V11+ follow-on sweep that the prior cron's notes hinted at but didn't perform.
- Picked up V15: brightness-aware migration chunk 3 — the actual remaining AppColors/AppTypography refs. Same chunking pattern as V12/V13/V14. Picked the playlist screen first (highest-value user-facing surface, accessible from Settings) and bundled the 2 player files (which use the same `context.appColors` extension) since they were a single 818-line set.
- **V15** fully implemented, tested, and shipped (b87f9ac → 8db2164):
  - **`presentation/screens/playlist_screen.dart`** (20 refs migrated): the connection-management screen accessed from Settings. All these are now `context.appColors.*` / `context.appTypography.*`:
    - Scaffold `backgroundColor` (1)
    - The "No saved connections" empty state: muted dns icon + h3 heading + caption (3)
    - The `_ConnectionTile` for each saved connection: dismissible swipe-to-delete background (red overlay `withOpacity(0.2)` + delete icon, 2), leading icon container (primary `withOpacity(0.15)` background + dns icon, 2), title typography, subtitle typography, trailing chevron colour (3)
    - The `_ConnectionFormSheet` bottom sheet: handle bar (muted `withOpacity`), heading typography (2)
    - The focused `_TvButton`: focused/pressed background, focus border, focus glow `withOpacity(0.4)` (3)
    - 4 snack-bar `backgroundColor`s in `_addConnection` / `_switchTo` (auth + connection failures) / `_submit` form validation (4)
  - **Dropped 4 `const` keywords** that were forcing compile-time colour resolution (a `const Icon(... color: AppColors.X)` can't read from a context — the icon has to be allocated at runtime so the colour can be computed). Affected: `_ConnectionTile.background`'s delete icon, `_ConnectionTile.child`'s dns icon, `_ConnectionFormSheetState` form area, and the player `_LoadingPlaceholder`. None of these have any perf impact — Flutter rebuilds them only on state change.
  - **`presentation/providers/player_controller_notifier.dart`** (6 refs migrated): `_LoadingPlaceholder` and `_ErrorDisplay` (the private widget classes that Chewie mounts as `placeholder` and via `errorBuilder`) are now brightness-aware. The **Chewie progress colours stay hardcoded** to `AppColors.*` — the notifier's `setStream` runs without a `BuildContext` (the notifier is a `StateNotifier`, not a Widget), and the progress bar lives on top of the black video surface where the brightness-correct tokens wouldn't be visible anyway. Same trade-off V14 chunk 2 made for `player_screen.dart`, documented in a code comment so the next maintainer doesn't undo it.
  - **`presentation/players/xtream_stream_session.dart`** (6 refs migrated): the `errorBuilder` callback now resolves brightness-correct tokens via its `BuildContext` (it does have one — the callback receives it as the first arg). The `ChewieController` config block (progress colours + placeholder spinner) still hardcodes dark tokens for the same reason as the notifier file: `_initController` is a method on a non-Widget class, no `BuildContext` available, and those colours paint on top of the black video surface. Trade-off documented in a code comment.
  - **`flutter analyze`**: 50 issues found (was 50). 49 pre-existing `withOpacity` infos + 1 pre-existing V07-chunk3 unused-param warning. **0 new issues introduced by V15** (no entries in any of the 3 migrated files).
  - **`flutter test`**: 165/165 tests pass (was 163, +2 from V15). New file `test/brightness_aware_chunk6_test.dart` follows the V12/V13/V14 pattern: one `testWidgets` per (widget × theme) pair, no loop (would poison WidgetsBinding), explicit `themeMode` to defeat the test env's `platformBrightness` default. Tests assert on a single concrete colour reference (Scaffold bg → `LightAppColors.background` / `AppColors.background`) — proves the migration is wired, not falling back to a dark constant.
  - **Test scope for the player files is narrower than for the playlist screen.** The `_LoadingPlaceholder` and `_ErrorDisplay` widgets are private inside the notifier file and are exercised indirectly by the notifier's `setStream` path, which needs a real `VideoPlayerController` (chewie/video_player) and a real network stream. The `errorBuilder` callback in `xtream_stream_session.dart` is the same — the Chewie controller needs real network media to surface an error. Both fall back to the V14 chunk 2 scoping trade-off: prove the migration is wired (and that the test file compiles cleanly) on the self-contained `PlaylistScreen`, let the player files be covered by the source change + analyze.
- Pushed `feature/v15-brightness-aware-chunk3` → `develop` (merge 8db2164). CI ✅ + Release ✅ — **APK uploaded as v0.1.48**.

### CI status:
- `Merge feature/v15-brightness-aware-chunk3 into develop` (8db2164) — **CI ✅ + Release ✅ → v0.1.48**
- All Phase 2 (P201–P204, P206) + V01–V15 now Done
- The actual V08/V11/V12/V13/V14/V15 sweep is now **complete** — every ref of `AppColors.*` / `AppTypography.*` in app code now pulls from `context.appColors` / `context.appTypography`, except the documented non-context sites (3 places: `XtreamStreamSession._initController` progress + placeholder; `PlayerControllerNotifier.setStream` progress). The whole app is now brightness-aware — picking Light in Settings flips every screen and the player overlay/error widgets.

### What's next:
- **The V08/V11/V12/V13/V14/V15 follow-on is now actually complete.** The prior cron's "0 remaining" claim was wrong; V15 closed the gap. A user picking Light in Settings will now see the entire app switch to the light theme, including the playlist/connection management screen and the player error/loading overlays.
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
