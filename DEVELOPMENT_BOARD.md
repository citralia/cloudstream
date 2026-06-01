# CloudStream — Development Board

> Last updated: 2026-06-01T20:45:00+01:00

## Legend
| Status | Meaning |
|--------|---------|
| **Next** | Queued, next to pick up |
| **In Progress** | Active work, owned |
| **In Review** | Code written, testing/verification |
| **Done** | Merged, verified, shipped |
| **Blocked** | Waiting on external dependency |

---

## Phase 0 — Foundation

### Backend — FastAPI Proxy

| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| B01 | SPEC.md architecture update | Done | agent | Backend proxy architecture locked |
| B02 | FastAPI project scaffold | Done | agent | Docker + uvicorn + SQLite |
| B03 | Xtream auth router + models | Done | agent | Login/logout/me + Bearer token |
| B04 | Channel list router | Done | agent | /api/channels with category filter |
| B05 | EPG aggregator router | Done | agent | XMLTV parse + SQLite cache |
| B06 | Stream proxy endpoint | Done | agent | /api/stream/{id} redirects to Xtream |
| B07 | Docker compose + deploy script | Next | agent | deploy.sh ready, docker-compose added |
| B08 | VPS deployment + smoke test | Blocked | josh | needs home access to VPS |

### Flutter — Android App (Phase 0)

| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| F01 | Flutter project clean structure | Done | agent | Clean Architecture dirs, pubspec with deps |
| F02 | Design tokens + app theme | Done | agent | AppTheme dark, AppColors, AppTypography, AppSpacing |
| F03 | Xtream data models | Done | agent | Channel, Programme, Category, User entities + DTOs |
| F04 | Xtream API client | Done | agent | Dio ApiClient + CloudStreamRemoteDataSource |
| F05 | Login screen | Done | agent | Form validation, Xtream auth flow |
| F06 | Channel list screen | Done | agent | Grouped by category, channel tiles with logos |
| F07 | Video player (Chewie/HLS) | Done | agent | PlayerScreen with Chewie, EPG now/next overlay |
| F08 | Category filtering | Next | agent | Category chips, filtered channel list |
| F09 | Settings screen | Next | agent | Server URL edit, logout, about |
| F10 | Android build smoke test | Blocked | josh | Side-load on Firestick |

### iOS (deferred — full build on Mac)

| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| I01 | Flutter iOS target config | Done | agent | scaffolded |
| I02 | Native iOS signing + provisioning | Next | josh | Mac only |
| I03 | TestFlight deployment | Blocked | josh | Mac + Apple account |

---

## Phase 1 — Core Player (queued)

| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| P101 | Channel switching < 1s | Backlog | | |
| P102 | Quick channel switcher overlay | Backlog | | |
| P103 | PiP support | Backlog | | |
| P104 | Gesture controls | Backlog | | |
| P105 | Full EPG guide screen | Backlog | | |

---

## Blockers

| Blocker | Impact | Resolution |
|---------|--------|------------|
| No VPS access | B08 | Deploy when josh home |
| No MacBook | iOS build | CI validates, Mac verification later |
| No Firebase credentials | F10 | Env vars on deploy |

---

## Notes

- Backend: FastAPI + SQLite for session cache
- Frontend: Flutter with Clean Architecture (data/domain/presentation)
- All commits must include board update
- PR required for all merges to develop
- Xtream server: Josh has one — point backend at deploy
- Cron: dev cron fires hourly at :05, advances next task
