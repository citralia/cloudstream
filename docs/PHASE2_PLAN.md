# CloudStream — Phase 2+ Project Specification
> **Source:** PolyGnosis v3 adversarial consensus (2026-06-03)
> **Solvers:** IPTV Streaming Architect, Flutter Cross-Platform Engineer, Product Strategy Lead
> **Status:** Authoritative baseline — read in full before writing any Phase 2 code

---

## Summary

**Winning sequence:** Provider abstraction → VOD → Multi-profile local → Search → Profile sync → Catch-up → DVR (deferred) → Monetisation → Cast

This is NOT alphabetical. The logic: Provider abstraction (P201) makes Xtream a v1 instance of a v4 system — without it, every later feature couples to Xtream directly and Phase 4 multi-provider is a rewrite. VOD is the highest revenue surface and reuses the Phase 1 player. Multi-profile starts local (P203) before syncing (P205) — you can't test "is this mirrored?" if "this" doesn't exist locally first. Catch-up and DVR are seek-into-existing-stream on one StreamSession, not new transport layers.

---

## Phase 2 Feature Table

| ID | Feature | Hours | Definition of Done |
|----|---------|-------|-------------------|
| P201 | Provider abstraction | 40h | `Provider` interface with `has_vod, has_catchup, has_epg, has_recording` flags. Xtream + M3U stubs both pass contract tests. |
| P202 | VOD library + player reuse | 60h | VOD categories, posters, resume, watch-progress in Firestore per profile. Resume from 47:12 plays identically on Firestick, iOS, tvOS. |
| P203 | Multi-profile local | 24h | Profile switcher, per-profile favourites, no sync yet. 4 profiles coexist on one device with isolated state. |
| P204 | Search | 30h | In-memory index over live channels + VOD. "barca" returns La Liga + Barcelona VOD in <300ms on Firestick. |
| P205 | Profile sync via Firestore | 40h | Mirror favourites, watch-progress, profile metadata. Functions encrypt provider creds server-side. iPhone → Apple TV reflects favourites within 5s. |
| P206 | Catch-up TV | 50h | Xtream catch-up HLS, seek to EPG start. EPG tap → seek-into-stream on all three platforms. Never a black screen — graceful fallback to live. |
| P207 | DVR / recordings | 70h | Cloudflare R2 only if catch-up window insufficient. Revenue-gated: P208 ships before P207. |
| P208 | Monetisation | 30h | RevenueCat subscriptions, paywall on multi-profile + sync + catch-up. |
| P209 | Cast + multi-screen | 50h | AirPlay + Cast + picture-in-picture orchestration. |

**Phase 2 total: ~400h AI + 60h Josh review**

---

## Three Architectural Decisions to Lock Now

### 1. Provider Interface with Capability Flags
Without this, Phase 4 multi-provider (Xtream → M3U → Stalker) is a rewrite of every feature. P201 ships before any new feature consumer.

```
abstract class IPTVSource {
  bool get hasVOD;
  bool get hasCatchup;
  bool get hasEPG;
  bool get hasRecording;
  Future<List<Channel>> getChannels();
  Future<String> getStreamUrl(int streamId, {DateTime? start, Duration? duration});
}
```

### 2. EPG in Local SQLite; Firestore Holds Profile/Sync State Only
Firestore is not built for EPG cardinality (1,000 channels × 168 hours × 2 programme writes/hour = 336,000 writes/day per user). EPG goes to local SQLite. Firestore holds: favourites, watch-progress, profile metadata, settings.

### 3. One StreamSession for Live / Catch-up / DVR
One player abstraction handles all three as seek positions. Prevents three divergent transport layers. Refactor P105 player to `StreamSession` in P201.

---

## Testing Strategy (6 Surfaces)

| Surface | What | How |
|---------|------|-----|
| Unit | Repository logic, merge algorithms, EPG parser, provider capability flags | `dart test`, `mocktail` |
| Widget | Individual screens (channel grid, EPG, player controls, profile switcher) | `flutter test` widget tests |
| Integration | Multi-step flows (onboarding → watch, EPG → catch-up) | Firebase Local Emulator + fake Xtream server |
| E2E | Full user journeys | Maestro (Flutter) or manual on physical devices |
| Stream playback | Startup time, channel switch latency, codec support, buffer health | Custom harness with synthetic HLS fixtures (Big Buck Bunny loop) |
| Platform-specific | Firestick remote, Apple TV Siri remote, PiP, background audio, tvOS focus navigation | Manual on physical devices only |

**Device matrix (solo founder budget):** Firestick 4K Max + iPhone + Apple TV 4K. Everything else best-effort.

---

## Release Cycle

```
Feature branch → PR to develop → CI (analyze + test + builds)
                                    ↓
                           Merge to main
                                    ↓
                    CI: tag + Firebase App Distribution
                           (Android internal)
                                    ↓
                    CI: TestFlight upload (iOS/macOS)
                           (Josh uploads from MacBook)
                                    ↓
                    Google Play internal testing
                                    ↓
                    Firestick APK: GitHub Release + Downloader URL
```

**APK distribution:** GitHub Release URL → Downloader app on Firestick (no Play Store needed)

**App Store submission:** First review = 3-5 business days. Updates = 24-48h.

---

## KPIs (Instrumented from Day 1)

| KPI | Event | Target |
|-----|-------|--------|
| DAU/MAU | `app_session_start` | MAU growth |
| Channel switch p50/p95 | `switch_latency_ms = t_first_frame - t_tap` | p50 < 1s, p95 < 2s |
| Session length | `app_session_end` | Baseline, then grow |
| Crash-free % | Crashlytics daily | > 99.5% |
| Catch-up usage | `catchup_play` | Track adoption |
| Search-to-play | `search_impression` → `play` funnel | Baseline, then improve |
| Preflight probe | `preflight_probe` | Error distribution tracking |
| Auth recovery | `auth_recovery_attempt/outcome` | Credential expiry tracking |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| App Store IPTV rejection | Medium | Critical | Declare as "IPTV player" (4.7), no playlist bundling, no content aggregation |
| Play Store IPTV policy | High | Critical | Firestick uses GitHub + Downloader distribution, not Play Store |
| Xtream rate limits | High | Medium | Local cache + jittered refresh intervals |
| Firestick codec/HEVC licensing | Low | High | H.264 baseline only, no HEVC in v1 |
| Profile cred leak via Firestore | Medium | High | Server-side encryption in Functions, never store raw creds client-side |

---

## Top 3 Differentiators vs TiviMate / UHF

1. **True cross-platform parity including tvOS** — TiviMate is Android-only; UHF is rough on Apple TV. CloudStream has a native SwiftUI tvOS app in the plan.
2. **Provider abstraction** — Xtream → M3U → Stalker without rewrite. TiviMate is locked to its provider model; UHF has no abstraction layer.
3. **Offline-first catch-up with Firestore-mirrored EPG** — TiviMate is online-only; UHF catch-up is broken. CloudStream caches EPG locally and mirrors it cross-device.

---

## What NOT to do

- Do NOT add Supabase, PocketBase, or any custom backend in Phase 2. Firebase Auth + Firestore + Functions covers everything through Phase 3.
- Do NOT build catch-up or DVR before the Provider abstraction (P201). They would couple to Xtream directly.
- Do NOT add HEVC/AC3 support in Phase 2. H.264 + AAC baseline only.
- Do NOT test on more than 3 physical devices (solo founder budget). Emulators for everything else.
- Do NOT add multi-screen ABR in Phase 2. Single ABR stream per player session.

---

## 48-Hour Immediate Action Plan

**Hour 0–2 (Josh):**
- read_file this spec end-to-end
- Confirm Apple Developer Program enrollment is active
- Sign off Phase 2 order (comment in ADR-005 or here)

**Hour 2–6 (Agent):**
- Open PR #1: refactor player widget → `CloudStreamPlayer` interface (P201 foundation)
- Add PII redaction module (`lib/diagnostics/pii_redaction.dart`) + unit test
- Add Crashlytics + analytics events with locked taxonomy

**Hour 6–10 (Agent):**
- Open PR #2: add `sqflite`, ship EPG schema with migration test (P201/P202 foundation)
- Wire existing 7-day EPG cache to SQLite

**Hour 10–14 (Josh, physical devices):**
- Manual regression: Firestick 4K Max + Apple TV 4K + iPhone
- Verify P101–P105 still work
- Verify Crashlytics receives deliberate crash
- Verify analytics debug stream has no provider host

**Hour 14–24 (Agent):**
- Capture 1,000-channel synthetic EPG fixture
- Run 24h soak harness on CI

**Hour 24–36 (Josh):**
- Go/no-go on P206 (catch-up) as first user-visible feature
- Confirm App Store Connect reachable

**Hour 36–48 (Agent):**
- Open PR #3: P206 catch-up UI + seek
- Draft provider compatibility matrix doc

---

## Reference: Key Design Decisions from Phase 1 (LOCKED)

- ADR-004: Pure Dart Xtream client, no native code, App → Xtream direct
- Flutter 3.44 for CI, Flutter 3.24 Groovy for local MacBook
- Riverpod for state management
- H.264 / ExoPlayer (Android) / AVPlayer (iOS/macOS/tvOS)
- `chewie` + `video_player` as player base
- Dark theme: `#0A0A0F` background, `#6C5CE7` primary, `#00D9FF` accent
- Bottom nav: Live TV | Guide | VOD | Settings
- No backend for IPTV operations
