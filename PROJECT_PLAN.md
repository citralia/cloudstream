# CloudStream — Project Plan

> **Status:** Pre-Development
> **Phase 0 Start:** 2026-05-22

---

## Phase Summary

| Phase | Name | Duration | Goal |
|-------|------|----------|------|
| **0** | Foundation | Weeks 1–4 | Repo, CI/CD, design system, auth, Xtream connection |
| **1** | Core Player | Weeks 5–10 | Live TV, playback, channel switching, EPG |
| **2** | Content + Profiles | Weeks 11–16 | VOD, catch-up, profiles, Firestore sync |
| **3** | Monetisation | Weeks 17–20 | Subscription tiers, RevenueCat, Stripe |
| **4** | Cloud DVR | Weeks 21–26 | DVR service, R2 storage, recording playback |
| **5** | tvOS + Polish | Weeks 27–32 | Native tvOS, performance optimisation, App Store |
| **6** | Growth | Weeks 33–36 | Analytics, push notifications, referral system |

---

## Phase 0 — Foundation (Weeks 1–4)

**Goal:** Empty shell → a buildable app with CI/CD, design system, and working Xtream auth. No playback yet.

### 0.1 — Repository + CI/CD

**Due:** Week 1

- [ ] **Repo structure** — `citralia/cloudstream` on GitHub
- [ ] **Branch strategy:**
  - `main` — protected, requires 1 PR approval + all CI green
  - `develop` — integration branch, auto-merged via PR from feature branches
  - `feature/*` — individual feature branches, squash-merged to develop
  - `hotfix/*` — emergency fixes, fast-tracked to main
- [ ] **CI pipeline** (GitHub Actions):
  - On PR to `develop`: `flutter analyze`, `flutter test`, `dart test`
  - On PR to `main`: full build (iOS simulator, Android APK, macOS .app)
  - On merge to `main`: tag release + deploy to Firebase App Distribution (Android) / TestFlight (iOS)
  - On merge to `main`: bump version tag (`major.minor.patch`)
- [ ] **Definition of Done for CI:**
  - `flutter analyze` returns 0 errors (warnings are allowed, must be acknowledged)
  - All unit/widget tests pass
  - iOS build succeeds (`flutter build ios --simulator --no-codesign`)
  - Android build succeeds (`flutter build apk --debug`)
  - macOS build succeeds (`flutter build macos`)

### 0.2 — Design System

**Due:** Week 2

- [ ] **Tokens** — Colour, typography, spacing, elevation (Figma tokens → `lib/theme/`)
- [ ] **Colour palette:**
  - Background: `#0A0A0F` (near-black)
  - Surface: `#14141F`
  - Surface elevated: `#1E1E2E`
  - Primary: `#6C5CE7` (vibrant purple)
  - Accent: `#00D9FF` (cyan)
  - Error: `#FF4D6A`
  - Success: `#00E676`
  - Text primary: `#FFFFFF`
  - Text secondary: `#8A8A9A`
  - Text muted: `#4A4A5A`
- [ ] **Typography scale:**
  - Display: 48px, weight 700
  - H1: 32px, weight 700
  - H2: 24px, weight 600
  - H3: 18px, weight 600
  - Body: 16px, weight 400
  - Caption: 14px, weight 400
  - Micro: 12px, weight 500
- [ ] **Spacing:** 4px base unit (4, 8, 12, 16, 24, 32, 48, 64)
- [ ] **Component library** (Flutter):
  - `CSButton` — primary, secondary, ghost, destructive variants
  - `CSTextField` — text input with validation states
  - `CSChannelTile` — channel logo + name + now/next, small/medium/large sizes
  - `CSProgrammeCard` — programme info with catch-up badge
  - `CSBottomNav` — 4 items with active indicator
  - `CSPageScaffold` — consistent page shell with safe areas
  - `CSOverlay` — modal overlays with backdrop blur
- [ ] **Icons:** Phosphor Icons (Flutter package: `phosphor_flutter`)
- [ ] **Fonts:** Inter (variable font, Google Fonts)

### 0.3 — Navigation + App Shell

**Due:** Week 2

- [ ] **Navigation:** GoRouter with shell route for bottom nav
- [ ] **Bottom nav items:** Live TV, Guide, VOD, Settings
- [ ] **Player:** Opens as full-screen route, not overlaid on nav
- [ ] **App lifecycle:** restore last active profile + channel on cold start
- [ ] **Deep linking:** `cloudstream://` scheme, universal links for sharing

### 0.4 — Authentication

**Due:** Week 3

- [ ] **Firebase project setup** (Josh provides credentials)
  - Firebase Auth: email/password + Google sign-in
  - Firestore: profiles collection
  - App Distribution: test builds
- [ ] **Auth UI:**
  - Sign in / Sign up screen (email + password)
  - Google sign-in button
  - Biometric prompt on supported devices
- [ ] **Profile creation** post-sign-up: name + avatar selection (6 preset avatars)
- [ ] **Session management:** token refresh, offline sign-out, multi-device detection

### 0.5 — Xtream Connection + Data Layer

**Due:** Week 4

- [ ] **Xtream API client** (pure Dart, no native code):
  - Login: `POST /player_api.php?username=X&password=Y&action=login`
  - Live categories: `GET /player_api.php?action=get_live_categories`
  - Live streams: `GET /player_api.php?action=get_live_streams&category_id=N`
  - VOD + series endpoints
  - Stream URL: `GET /live/{username}/{password}/{stream_id}.m3u8`
  - Error handling: invalid credentials, server down, network timeout
- [ ] **Data models:**
  - `XtreamServer` — URL, credentials, name
  - `XtreamCategory` — id, name, type
  - `XtreamChannel` — id, name, logo, category_id, stream_url
  - `XtreamVod` / `XtreamSeries`
- [ ] **Repository pattern:**
  - `ConnectionRepository` — CRUD for server connections
  - `ChannelRepository` — channel list + category filtering
  - `VodRepository` — VOD + series
- [ ] **Local caching:** Hive for channel list + categories (offline access)
- [ ] **Connection status:** indicator in home screen header

### 0.6 — Onboarding Flow

**Due:** Week 4

- [ ] **Step 1:** Welcome screen + "Get started"
- [ ] **Step 2:** Add connection
  - A: Xtream Codes (URL + username + password)
  - B: M3U URL (paste + validate)
  - C: Scan QR code
- [ ] **Step 3:** Auto-fetch channels (loading state with channel count)
- [ ] **Step 4:** Done → home screen (auto-playing last channel if any)
- [ ] **Total time target: < 60 seconds for Xtream setup**

---

## Phase 1 — Core Player (Weeks 5–10)

**Goal:** A fully functional IPTV player that feels faster than any competitor. This is where trust is earned or lost.

### 1.1 — Video Playback

**Due:** Week 6

- [ ] **Player:** `video_player` + `chewie` as base, custom controller
- [ ] **HLS adaptive bitrate:** auto quality selection
- [ ] **Hardware decode:** AVPlayer (iOS/macOS), ExoPlayer (Android)
- [ ] **Codecs:** H.264 (required), H.265/HEVC (if device supports), VP9 (if available)
- [ ] **Cold start:** < 1.5s from channel tap to first frame
- [ ] **Audio:** AAC, AC3, MP3 pass-through where supported
- [ ] **Subtitles:** DVB subtitles (from stream), external SRT via `subtitles` package

### 1.2 — Player Controls Overlay

**Due:** Week 7

- [ ] **Auto-hide:** controls fade after 3s of no interaction
- [ ] **Gesture controls:**
  - Tap: show/hide controls
  - Double-tap left/right: skip ±10s
  - Swipe left/right on seek bar: scrub
  - Swipe up from bottom: volume
  - Pinch: toggle aspect ratio (fit / fill / 16:9)
- [ ] **Controls layout:**
  - Top: back button, programme title, live badge / VOD progress
  - Centre: play/pause, skip back/forward
  - Bottom: seek bar, current time / duration, quality selector, audio, subtitles, PiP
- [ ] **Live indicator:** pulsing red dot for live content, seek bar shows live position

### 1.3 — Channel Switching

**Due:** Week 7

- [ ] **Target: < 1 second** from tap to new channel
- [ ] **Pre-warm:** keep last 3 stream connections alive (ExoPlayer HTTP pool)
- [ ] **Quick switcher overlay:**
  - Long-press channel number OR swipe up from player
  - Last 5 channels + most-watched shortcuts
  - One-tap switch with < 500ms response
- [ ] **Channel number input:** tap channel number → numeric pad → direct channel switch

### 1.4 — EPG Integration

**Due:** Week 8

- [ ] **Data source:** Xtream API EPG + manual XMLTV URL fallback
- [ ] **Now/Next view (default):**
  - 4-hour visible window, virtualised list
  - Current programme highlighted
  - Catch-up badge if available
- [ ] **Programme info card (tap):**
  - Title, description, time, channel
  - "Watch from start" (if catch-up available)
  - "Record" (if DVR enabled)
  - "Set reminder"
- [ ] **Category filtering** in guide
- [ ] **EPG refresh:** configurable interval, background fetch

### 1.5 — Favourites + Channel Management

**Due:** Week 9

- [ ] **Long-press channel → toggle favourite**
- [ ] **Favourites row on home screen**
- [ ] **Manual channel reorder** (Favourites section only, drag-and-drop)
- [ ] **Category tabs:** Entertainment, Sports, News, Kids, Movies, Music + custom
- [ ] **Hidden channels:** mark channels as hidden (excluded from guide + grid)

### 1.6 — Playback Settings

**Due:** Week 10

- [ ] **Default quality:** Auto / 1080p / 720p / 480p / 360p
- [ ] **Volume normalisation:** toggle (on by default for voice-heavy content)
- [ ] **Preferred audio language** (for multi-language streams)
- [ ] **Preferred subtitle language**
- [ ] **Subtitles:** toggle on/off, size (small/medium/large)
- [ ] **Startup channel:** last watched / specific channel / none
- [ ] **PiP:** picture-in-picture on iOS 14+ / Android 8+

---

## Phase 2 — Content + Profiles (Weeks 11–16)

**Goal:** VOD, catch-up TV, multi-profile, and seamless cross-device sync.

### 2.1 — VOD Playback

**Due:** Week 12

- [ ] **VOD list** from Xtream API (category browse + recently added)
- [ ] **Series navigation:** series → season → episode
- [ ] **VOD player:** same player as live TV but with full seek + VOD-specific controls
- [ ] **Resume:** auto-save position every 10s, prompt on return
- [ ] **Auto-play next episode** (toggle in settings)
- [ ] **Skip intro / skip outro** (configurable: auto-detect or manual mark)

### 2.2 — Catch-Up TV

**Due:** Week 13

- [ ] **Detect availability:** from Xtream catch-up URLs (`/live/{user}/{pass}/{id}.m3u8?start={timestamp}`)
- [ ] **Catch-up badge on EPG** with time range ("48h", "7 days")
- [ ] **Play from start:** seek to programme start time
- [ ] **Resume within catch-up:** if partially watched, offer "Continue from X:XX"
- [ ] **Timeshift buffer:** 30-min rolling buffer for live TV (pause + resume within buffer)

### 2.3 — Multi-Profile System

**Due:** Week 14

- [ ] **Up to 6 profiles** per account
- [ ] **Profile switcher:** avatar tap → slide-up panel
- [ ] **Per-profile:**
  - Favourites
  - Watch history
  - Custom channel sort
  - Parental controls
  - Watchlist
- [ ] **Fast switch:** < 2s, no full logout
- [ ] **Profile creation:** name + avatar (6 presets)

### 2.4 — Firestore Sync

**Due:** Week 15

- [ ] **Sync scope:**
  - Favourites
  - Watch history + resume positions
  - Custom channel sort
  - Playback settings (per-profile)
  - Last active profile (for session restore)
- [ ] **Conflict resolution:** last-write-wins with timestamp
- [ ] **Offline support:** write to local Hive, sync on reconnect
- [ ] **Initial sync on login:** pull down Firestore state, merge with local

### 2.5 — Parental Controls

**Due:** Week 16

- [ ] **Profile-level PIN:** 4-digit, device-stored (iOS Keychain / Android Keystore)
- [ ] **Locked channels:** blur + PIN prompt
- [ ] **Locked categories:** entire VOD categories
- [ ] **Profile lock:** PIN required to switch to protected profile
- [ ] **Content rating filter:** block by stream rating metadata (where available)

---

## Phase 3 — Monetisation (Weeks 17–20)

**Goal:** Subscriptions live. RevenueCat + Stripe + Google Play. Free tier driving organic growth.

### 3.1 — RevenueCat Integration

**Due:** Week 17

- [ ] **RevenueCat SDK** (Flutter: `purchases_flutter`)
- [ ] **Products defined:**
  - Free (default, no IAP)
  - Standard Monthly / Annual
  - Premium Monthly / Annual
  - Family Monthly / Annual
- [ ] **Entitlements:** `standard`, `premium`, `family`
- [ ] **RevenueCat ↔ Firestore:** write subscription tier to Firestore on purchase
- [ ] **Restore purchases:** button in Settings → Subscription

### 3.2 — Payment Flows

**Due:** Week 18

- [ ] **iOS/macOS/tvOS:** App Store IAP via RevenueCat
- [ ] **Android:** Google Play Billing via RevenueCat
- [ ] **Web:** Stripe Checkout (monthly recurring)
- [ ] **Subscription banner:** shown in app when free tier limits reached
- [ ] **Paywall UI:**
  - Feature matrix (3 tiers)
  - Monthly / Annual toggle (annual = 2 months free)
  - Secure payment sheet

### 3.3 — Subscription Enforcement

**Due:** Week 19

- [ ] **Stream limits by tier:** 1 / 3 / 5 / 10 concurrent
- [ ] **Catch-up duration by tier:** 24h / 7d / 14d / unlimited
- [ ] **DVR by tier:** disabled / 50GB / 200GB / 500GB
- [ ] **Profile count by tier:** 1 / 3 / 6 / 6 + kids mode
- [ ] **DRM by tier:** none / Widevine L1 / Widevine L1 + FairPlay
- [ ] **Grace period:** 3 days to restore after expired subscription

### 3.4 — Billing Portal

**Due:** Week 20

- [ ] **Manage subscription:** upgrade / downgrade / cancel
- [ ] **Billing history:** list of charges
- [ ] **Update payment method**
- [ ] **Cancellation flow:** survey (required), retain offer

---

## Phase 4 — Cloud DVR (Weeks 21–26)

**Goal:** Users can record live TV and watch recordings from any device.

### 4.1 — DVR Backend Service

**Due:** Week 22

- [ ] **FastAPI service** (`backend/dvr-service/`)
- [ ] **Endpoints:**
  - `POST /schedule` — schedule a recording
  - `GET /schedule/{user_id}` — list scheduled recordings
  - `DELETE /schedule/{id}` — cancel recording
  - `GET /recordings/{user_id}` — list completed recordings
  - `GET /recordings/{id}/manifest` — HLS manifest for playback
- [ ] **S3 storage:** Cloudflare R2 (S3-compatible)
- [ ] **Recording worker:** FFmpeg process per recording, triggered by schedule

### 4.2 — Recording from EPG

**Due:** Week 23

- [ ] **"Record" button** on programme info card
- [ ] **Series link:** "Record all episodes" option for series
- [ ] **Conflict detection:** warn if overlapping with existing recording
- [ ] **Notification on start:** push when recording begins
- [ ] **Notification on complete:** push when recording is ready

### 4.3 — Recording Playback

**Due:** Week 24

- [ ] **Recordings appear in "Saved" section** (alongside Continue Watching)
- [ ] **HLS playback** from R2 storage
- [ ] **Full VOD controls** (seek, speed, audio, subtitles)
- [ ] **Delete recording:** with confirmation
- [ ] **Auto-expiry:** recordings deleted when tier downgrades below storage limit

---

## Phase 5 — tvOS + Polish (Weeks 27–32)

**Goal:** Native tvOS app. App Store launch. Performance locked at < 1s channel switch.

### 5.1 — Native tvOS App

**Due:** Week 28

- [ ] **SwiftUI app** in `apps/cloudstream_tvos/`
- [ ] **Same UX** adapted for 10-foot UI (focus-based navigation)
- [ ] **AVKit** for video playback (native, no Flutter)
- [ ] **Siri Remote** support: swipe gestures, play/pause, skip
- [ ] **Channel grid:** scrollable, focusable tiles
- [ ] **EPG:** full 7-day guide with focus navigation
- [ ] **tvOS Siri + search:** voice search for channels and VOD

### 5.2 — Performance Validation

**Due:** Week 30

- [ ] **Channel switch time:** locked at < 1s (measure + instrument)
- [ ] **Memory ceiling:** < 200MB during live TV playback
- [ ] **Cold start:** < 3s from tap to first frame
- [ ] **Crash-free sessions:** > 99.5% target
- [ ] **Battery:** background audio mode, no excess CPU drain

### 5.3 — App Store Submission

**Due:** Week 32

- [ ] **iOS App Store** listing (App Store Connect)
- [ ] **tvOS App Store** listing
- [ ] **macOS App Store** listing
- [ ] **Google Play** listing (Android APK)
- [ ] **Screenshots** for all store listings (device-specific)
- [ ] **Privacy policy** (GDPR-compliant)
- [ ] **Age rating:** 4+ (all platforms)

---

## Phase 6 — Growth (Weeks 33–36)

**Goal:** Retention loops, analytics, referral system. Turning free users into paying subscribers.

### 6.1 — Analytics

**Due:** Week 34

- [ ] **Firebase Analytics** — all key events
- [ ] **Key metrics tracked:**
  - Channel switch time (per session)
  - Stream start failures (with error code)
  - Onboarding drop-off points
  - Subscription paywall views → conversions
  - D7 / D30 retention by cohort
  - EPG engagement (sessions with guide open)
  - Catch-up usage
  - DVR activation rate
- [ ] **Crash reporting:** Firebase Crashlytics

### 6.2 — Push Notifications

**Due:** Week 35

- [ ] **FCM** (Firebase Cloud Messaging) for Android
- [ ] **APNs** for iOS/macOS/tvOS
- [ ] **Notifications:**
  - Recording started / completed
  - New episode recorded (series link)
  - Subscription expiring (3 days before)
  - App update available

### 6.3 — Referral System

**Due:** Week 36

- [ ] **Referral link:** unique per user, shareable
- [ ] **Reward:** 1 month free Standard tier for referrer when referee upgrades
- [ ] **Tracking:** referral code stored in Firestore + RevenueCat
- [ ] **Share UI:** native share sheet with deep link

---

## Definition of Done

Every feature PR must meet ALL of the following before merge:

1. **Code review** — at least 1 approval from a team member (or self-review checklist for solo)
2. **CI green** — `flutter analyze` (0 errors), all tests pass, builds succeed
3. **Functional test** — tested on target platform (iOS/Android/macOS/tvOS)
4. **Regression test** — existing features in the same area still work
5. **Edge cases handled** — loading states, empty states, error states, network failure
6. **No P0 bugs** — crashes, data loss, or security issues are zero-tolerance
7. **Documentation** — new API endpoints documented, new data models documented
8. **Telemetry added** — analytics event fired for new user interaction

---

## GitHub Conventions

### Commit Messages

```
type(scope): description

Types: feat | fix | refactor | test | docs | chore | ci
Scopes: player | epg | auth | dvr | sub | onboarding | etc.
```

**Examples:**
```
feat(player): add quick channel switcher overlay
fix(epg): handle missing programme data gracefully
ci: add tvOS build to GitHub Actions matrix
docs(auth): document token refresh flow
```

### Branch Names

```
feature/auth-xtress-login
feature/epg-xmltv-fallback
feature/player-gesture-controls
fix/channel-switch-time
chore/update-flutter-dependencies
hotfix/crash-on-app-terminate
```

### PR Conventions

- **Title:** imperative mood ("Add quick channel switcher" not "Added" or "Adding")
- **Description:** what, why, and how. Link to related issue.
- **Screenshots/recordings** for UI changes
- **Breaking changes** noted explicitly

---

## Tech Stack Summary

| Layer | Technology |
|-------|-----------|
| Frontend (mobile/desktop) | Flutter 4.x (Dart 3.x) |
| Frontend (tvOS) | SwiftUI + AVKit |
| State management | Riverpod 2.x |
| Navigation | GoRouter |
| Video player | video_player + chewie (Flutter); AVPlayer (native tvOS) |
| Auth | Firebase Auth |
| Database | Firestore + Hive (local) |
| Backend | FastAPI (Python 3.12) |
| DVR storage | Cloudflare R2 (S3-compatible) |
| Payments | RevenueCat + Google Play + Stripe |
| CI/CD | GitHub Actions |
| Analytics | Firebase Analytics + Crashlytics |
| Push notifications | FCM + APNs |
| Hosting | Cloudflare Workers (API) + Cloudflare R2 (DVR) |
