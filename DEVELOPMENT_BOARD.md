# CloudStream — Development Board

> Last updated: 2026-06-01T20:00:00+01:00

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
| B01 | SPEC.md architecture update | In Progress | agent | |
| B02 | FastAPI project scaffold | Next | agent | |
| B03 | Xtream auth router + models | Next | agent | |
| B04 | Channel list router | Next | agent | |
| B05 | EPG aggregator router | Next | agent | |
| B06 | Stream proxy endpoint | Next | agent | |
| B07 | Dockerise + deploy script | Next | agent | |
| B08 | VPS deployment + smoke test | Blocked | josh | needs VPS access |

### Flutter — Android App (Phase 0)

| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| F01 | Flutter project clean structure | Next | agent | |
| F02 | Design tokens + theme | Next | agent | |
| F03 | Xtream data models | Next | agent | |
| F04 | Xtream API client | Next | agent | |
| F05 | Login screen | Next | agent | |
| F06 | Channel list screen | Next | agent | |
| F07 | Video player integration | Next | agent | |
| F08 | EPG overlay (now/next) | Next | agent | |
| F09 | Android build smoke test | Blocked | josh | needs Android Studio |
| F10 | CI verify debug APK | Blocked | josh | CI runs on merge |

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
| P102 | Category filtering | Backlog | | |
| P103 | Quick channel switcher overlay | Backlog | | |
| P104 | PiP support | Backlog | | |
| P105 | Gesture controls | Backlog | | |

---

## Blockers

| Blocker | Impact | Resolution |
|---------|--------|------------|
| No Xtream test server | B03-B07 | Use test fixtures, real server on deploy |
| No VPS access | B08 | Deploy when josh home |
| No MacBook | iOS build | CI validates, Mac verification later |
| No Firebase credentials | F05-F08 | Env vars on deploy |

---

## Notes

- Backend: FastAPI + SQLite for session cache
- Frontend: Flutter with Clean Architecture (data/domain/presentation)
- All commits must include board update
- PR required for all merges to develop
