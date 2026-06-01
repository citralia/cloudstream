# CloudStream — Development Log

> Reverse chronological. Most recent entries at top.

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
- [x] Repaired CI workflows (FLUTTER_VERSION 4.0.0→3.44.0, cd paths, artifact paths)
- [x] Scaffolded Flutter project at apps/cloudstream_app/
- [x] Set up ops infrastructure (board, log, workflow)
- [x] Backend FastAPI complete (B02-B06):
  - Xtream async client with full auth
  - /api/auth/* (login/logout/me)
  - /api/channels/* (list, get by id, category filter)
  - /api/categories/* (live/vod/series)
  - /api/epg/* (XMLTV parse, SQLite cache, refresh)
  - /api/stream/* (redirect to Xtream m3u8, manifest endpoint)
  - Docker + docker-compose ready
  - README with full API docs

### What's next:
- B07: Deploy script (write + test when VPS access available)
- Flutter: design tokens → Xtream client → login → channel list → player
- VPS deployment when josh gets home access

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
