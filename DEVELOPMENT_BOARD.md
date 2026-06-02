# CloudStream — Development Board

> Last updated: 2026-06-02T06:25:00+01:00

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
| F02 | Design tokens + app theme | Done | agent | AppTheme dark, AppColors, AppTypography, AppSpacing |
| F03 | Xtream data models | Done | agent | Channel, Programme, Category, User entities + DTOs |
| F04 | Xtream API client | Done | agent | Dio ApiClient + CloudStreamRemoteDataSource |
| F05 | Login screen | Done | agent | Form validation, Xtream auth flow |
| F06 | Channel list screen | Done | agent | Grouped by category, channel tiles with logos |
| F07 | Video player (Chewie/HLS) | Done | agent | PlayerScreen with Chewie, EPG now/next overlay |
| F08 | Category filtering | Done | agent | Category chips, filtered channel list |
| F09 | Settings screen | Done | agent | Server URL display, logout with confirm, about section |
| F10 | Android build smoke test | Blocked | josh | Side-load on Firestick |

> **Note F04-F08:** Client currently points to backend proxy. Must be updated to call Xtream API directly.

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
| P201 | VOD list + browse | In Progress | agent | Xtream get_vod_categories + get_vod_streams |
| B202 | Firebase integration | Backlog | Analytics, crashlytics, app distribution |

---

## Phase 1 — Core Player (queued)

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
