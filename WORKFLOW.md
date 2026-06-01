# CloudStream — Development Workflow

## Core principle: anything committed is verified.

---

## 1. Picking up work

1. Read `DEVELOPMENT_BOARD.md` — check **Next** column
2. Check `DEVELOPMENT_LOG.md` — most recent entry for context
3. Move item: **Next → In Progress** (edit board, commit message: `board: move X to in progress`)
4. Write the code
5. Commit: descriptive message referencing task ID (e.g. `backend: B03 Xtream auth router`)
6. Update board: **In Progress → In Review** or **Done**
7. Push to `develop`
8. Update `DEVELOPMENT_LOG.md` — what was done, any blockers found, next action
9. Commit log update separately

---

## 2. Commit hygiene

- **Meaningful messages** — not "fix" or "update"
- **Prefix by area:** `backend:`, `flutter:`, `ci:`, `docs:`, `board:`
- **Reference task ID** in first line when applicable
- **One logical change per commit** — squash if needed before PR
- **Always update board + log** after a session

---

## 3. Branch strategy

| Branch | Purpose | Protection |
|--------|---------|------------|
| `main` | Production, releases only | PR + CI green required |
| `develop` | Integration branch | PR + CI green required |
| `feature/*` | Per-task work | Squash-merge to develop |
| `hotfix/*` | Emergency fixes | Fast-track PR to main |

---

## 4. Pull request process

1. Create PR from `feature/X` → `develop`
2. CI must be green (all 5 jobs)
3. Self-review the diff
4. Merge (squash merge recommended)
5. Delete feature branch
6. Update board: move task to **Done**

---

## 5. CI gates

Every PR to `develop` requires:

| Job | Pass condition |
|-----|---------------|
| Analyze | `flutter analyze --no-fatal-infos --no-fatal-warnings` — 0 errors |
| Test | `flutter test --no-pub` — all pass |
| Build iOS | `flutter build ios --simulator --no-codesign` — exit 0 |
| Build Android | `flutter build apk --debug` — exit 0 |
| Build macOS | `flutter build macos` — exit 0 |

---

## 6. Cron job — hourly development tracker

**Cron ID:** `cloudstream-dev-cron`
**Schedule:** Hourly, at :05 past (e.g. 09:05, 10:05)
**Timezone:** Europe/London (UK)

**What it does:**
1. Reads `DEVELOPMENT_BOARD.md` and `DEVELOPMENT_LOG.md`
2. Reads last cron run from `DEVELOPMENT_LOG.md`
3. Checks GitHub CI status for develop branch
4. Picks up any task in **Next** column not yet started
5. Works on it (max 45 min per hour — leaves time for CI to run)
6. Commits code + updates board + appends to log
7. Delivers brief digest to Discord home channel

**Immutability:** Cron output is a log entry. No deleting history.

---

## 7. Definition of done

A task is **Done** when:
- [ ] Code is on `develop` branch
- [ ] CI is green
- [ ] Board updated
- [ ] Log entry written
- [ ] Josh has been notified (Discord)

---

## 8. Release process

1. PR: `develop` → `main`
2. CI must be green on `develop`
3. Update `CHANGELOG.md`
4. Merge to `main` — triggers Release workflow automatically
5. Release workflow: bumps version, builds all platforms, creates GitHub draft release
6. Josh reviews release notes, publishes when ready

---
