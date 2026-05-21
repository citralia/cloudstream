# CloudStream — Product Specification

> **Status:** Pre-Development
> **Last Updated:** 2026-05-22
> **Owner:** CloudStream Ltd

---

## 1. Concept

CloudStream is the IPTV player that people *switch to* and never switch away from.

Most IPTV apps are built around the provider's needs — the server connection, the channel list, the category browser. CloudStream is built around the viewer's needs: what do I want to watch, how do I find it fast, and can I pick up where I left off on any screen?

TiviMate wins on depth but is Android-only and feels like software from 2018. UHF wins on cross-platform ambition but ships with rough UX and no polish. CloudStream's goal is to be the player that makes people who switch from cable feel like they've finally arrived.

**Tagline:** *Your TV. Everywhere.*

---

## 2. User Research — Where Competitors Fail

### TiviMate's failures
- **Onboarding** — server URL + login + EPG import is 8+ steps. New users drop off.
- **Home screen** — category tabs + channel grid is a file browser, not a TV interface.
- **EPG** — full 7-day grid is an information architecture failure. Nobody plans TV that far ahead.
- **Player** — works, but lacks gesture controls, PiP is buried, no quick-switcher.
- **No iOS, no macOS, no tvOS** — dealbreaker for Apple households.

### UHF's failures
- **Visual design** — functional but flat. No sense of hierarchy or craft.
- **Performance** — channel switching is slow, memory usage is high.
- **No catch-up TV** — basic timeshift only.
- **Search** — global search exists but returns results slowly and without ranking.
- **Onboarding** — slightly better than TiviMate but still provider-centric.
- **iOS exists but is a port, not a native app.**

### What users actually say (synthesised from IPTV community feedback)
- *"I just want to open it and watch what I was watching yesterday"*
- *"The guide is useless — I only care what's on right now"*
- *"I can't figure out how to add my service"*
- *"Why does switching channels take 5 seconds?"*
- *"I want to start a film on my phone and finish it on my TV"*

---

## 3. Design Principles

### Principle 1 — The App Should Disappear
The user opens CloudStream to watch TV, not to use an app. Every screen that isn't the player should earn its existence. If a screen isn't necessary for the current task, it should be one tap away or hidden.

### Principle 2 — Anticipate, Don't Ask
Don't make the user configure things. If they have one IPTV service, connect it automatically. If they only watch News and Sports, surface those. Default to the last-watched channel. Show catch-up when it's available without being asked.

### Principle 3 — Speed Is the Main Feature
Channel switching < 1 second. Stream starts in < 1.5 seconds. Every tap has a response in < 100ms. Slowness feels like a bug and erodes trust.

### Principle 4 — Offline-First Mental Model
The app should work when the network hiccups. Cache EPG data locally. Cache channel logos. Cache recently watched. The user shouldn't notice when their internet stutters.

### Principle 5 — Subtle, Not Simple
"Simple" apps feel feature-starved. CloudStream is deep — but depth is surfaced progressively. The power features (DVR, multi-profile, stream quality) are discoverable without cluttering the main experience.

---

## 4. User Personas

### Primary — The Practical Viewer
**Name:** Marcus, 34, works in finance. Watches live news in the morning and sports in the evening.
- Has 1 IPTV subscription (Xtream server)
- Uses iPhone, iPad, and Apple TV
- Wants to open the app → watch immediately
- Frustrated by slow channel switching and bad EPG
- Will pay for a smooth experience

**CloudStream interaction:** Opens app → last channel playing. Swipe up → quick channel switcher (last 5). Long-press channel → add to favourites. Tap guide → see what's on now/next, not a 7-day grid.

### Secondary — The Household
**Name:** The Okonkwo family (Nigerian diaspora, 2 adults + 2 kids)
- Multiple IPTV subscriptions (home country channels + UK channels)
- Uses Android tablet for kids, iPhone for parents
- Wants separate kids profile with parental locks
- Frustrated by needing to re-enter login for each service
- Willing to pay for family tier

**CloudStream interaction:** One-tap profile switch. PIN for kids profile. Multiple server connections saved. Family shares subscription across devices.

### Tertiary — The Power User
**Name:** Dan, 28, software engineer. Watches tech YouTube + IPTV for sports.
- Has 3+ IPTV services (reseller + personal + VPN server)
- Uses desktop (Linux), Android, and ChromeCast
- Wants to manage multiple playlists, custom channel sort, DVR
- Frustrated by import/export friction

**CloudStream interaction:** M3U import via URL or file. Custom channel reorder. Cloud DVR for series recording. Advanced playback settings (codec info, stream URL copy).

---

## 5. Core User Flows

### Flow 1 — First Launch (Under 60 seconds)

```
[1] Splash — 1 second
    ↓
[2] "Add your IPTV service" (no account needed to start)
    Choose:
    A) Enter server details (Xtream Codes)
       - Server URL → Username → Password
       - Auto-detect categories + channel list
    B) Scan QR code (from another CloudStream device)
    C) Enter M3U URL or upload file
    ↓
[3] Done. Home screen.
    - Auto-plays last channel
    - Channels grouped by Most Watched (learned over time)
    - If EPG available: now/next shown below channel tiles
```

**Why this matters:** TiviMate takes 3-5 minutes to set up. CloudStream takes 60 seconds. The faster someone reaches a playing channel, the more likely they are to stay.

### Flow 2 — Daily Watch

```
[1] Open app
    - Auto-plays last channel (or last-watched from last session)
    - Home shows: Resume row + Most Watched channels + Continue Watching (VOD)
    ↓
[2] Quick channel switch (swipe up from player OR tap channel number)
    - Last 5 channels, instant switch
    ↓
[3] Browse guide (tap guide icon)
    - Now/Next view: 4-hour window, all channels
    - Tap programme → info + catch-up + record
    ↓
[4] Switch to VOD
    - Bottom nav: Live TV | Guide | VOD | Settings
    - Recently Added + Continue Watching always visible at top
```

### Flow 3 — Catch-Up TV

```
[1] On a programme in the guide, badge shows "Available"
    ↓
[2] Tap programme → Programme info card
    - Shows: title, description, start/end, progress
    - Big button: "Watch from start" (catch-up)
    - Or: "Resume" if partially watched
    ↓
[3] Player enters catch-up mode
    - Scrubber shows how far back you can seek
    - "48 hours available" indicator
```

### Flow 4 — Profile Switch

```
[1] Tap avatar (top-left of home screen)
    ↓
[2] Profile picker slides up
    - 6 profile avatars (user-created)
    - Quick switch in < 2 seconds
    - Parental lock on kid profiles (4-digit PIN)
    ↓
[3] Full switch including:
    - Favourites
    - Watch history
    - Parental restrictions
    - Custom channel sort
```

### Flow 5 — Subscription Upgrade

```
[1] Settings → Subscription (or banner after 3 days)
    ↓
[2] Tier comparison (3 tiers, clear feature matrix)
    ↓
[3] Platform payment sheet (RevenueCat / Google Play / Stripe)
    ↓
[4] Unlocked instantly. No restart. No friction.
```

---

## 6. Information Architecture

### Screen Hierarchy

```
├── Player (fullscreen)
│   ├── Video (always fullscreen)
│   ├── Controls overlay (auto-hide after 3s)
│   ├── Quick channel switcher (swipe up)
│   ├── Programme info (tap once)
│   ├── Playback controls (tap once)
│   └── Audio/Subtitle/Speed (tap once → long-press)
│
├── Home (bottom nav)
│   ├── Resume row (last channel + continue watching)
│   ├── Most Watched channels (auto-sorted by watch frequency)
│   ├── Favourites
│   ├── Continue Watching (VOD + catch-up)
│   └── Categories (horizontal scroll)
│
├── Guide (bottom nav)
│   ├── Now/Next view (4-hour window, scrollable)
│   ├── Full day view (tap → expand to 24h)
│   ├── Search within guide
│   └── Filter by category
│
├── VOD (bottom nav)
│   ├── Search
│   ├── Continue Watching
│   ├── Recently Added
│   └── Categories grid
│
├── Settings (bottom nav)
│   ├── Profile + subscription
│   ├── Connections (servers, playlists)
│   ├── Playback quality
│   ├── Parental controls
│   ├── Notifications
│   └── About + support
│
└── Onboarding (pre-auth)
    ├── Add service (Xtream / M3U / QR)
    ├── EPG setup (auto or manual XMLTV)
    └── Create profile
```

---

## 7. Feature Specification

### 7.1 Connection Management

#### Xtream Codes API (primary)
- Server URL + username + password login
- Auto-fetches: categories, channels, VOD, series, EPG (if server provides)
- Secure credential storage: iOS Keychain / Android Keystore
- Connection status indicator on home screen
- Multiple server connections (up to 5 per profile)

#### M3U / M3U8 Import
- URL import (paste or scan QR code from another device)
- File import via Files app
- Background refresh (configurable: never / daily / on launch)

#### QR Code Pairing
- One device exports connection config as QR code
- Other device scans → imports without re-entering credentials
- Used for quick setup on second+ devices

#### Portal MAC Login
- Some IPTV services use MAC address authentication
- Supported alongside username/password auth

---

### 7.2 Live TV

#### Channel Grid
- Default sort: Most Watched (learned from watch history)
- Manual reorder: drag-and-drop (Favourites only)
- Category filter tabs: Entertainment, Sports, News, Kids, Movies, Music, + custom
- Channel tile: logo + name + now/next (1 line)

#### Playback
- HLS adaptive bitrate (auto quality selection)
- Hardware decode: AVPlayer (iOS/macOS/tvOS), ExoPlayer (Android)
- Codec support: H.264, H.265/HEVC, VP9, AV1
- Target channel switch: < 1 second
- Sub-1.5s cold stream start

#### Quick Channel Switcher
- Triggered by swipe up from player OR long-press channel number
- Shows: last 5 channels, most-watched shortcuts
- One tap = instant switch (< 500ms)

#### Volume Normalisation
- Toggle: reduces volume spikes between channels
- Stored per profile

#### Favourites
- Long-press channel → add/remove favourite
- Dedicated favourites row on home screen
- Synced via Firestore across all devices

---

### 7.3 TV Guide (EPG)

#### Now/Next View (default)
- 4-hour visible window, scrollable forward
- All channels as rows
- Current programme highlighted
- If programme has catch-up: badge + "Watch from start" button

#### Expanded View (tap to expand)
- Full 24-hour view per channel
- Programme blocks sized proportionally to duration

#### 7-Day View (explicit tap)
- Available on-demand (loads data for visible window only)
- Virtualised list — only renders visible rows

#### Programme Info Card (tap programme)
- Title, description, start/end time, category
- Thumbnail from Xtream API where available
- Watch from start (catch-up) / Record / Add reminder

#### EPG Sources
1. Xtream API native (auto-fetched on login)
2. Manual XMLTV URL (user enters URL)
3. XMLTV file import (upload)
4. CloudStream EPG backend (Phase 2) — fetches + caches from multiple sources

#### EPG Refresh
- Configurable: On launch / Every 6h / Every 12h / Manual only
- Stored locally (7-day lookback) + synced to Firestore for multi-device

---

### 7.4 Catch-Up TV

#### Availability
- Based on stream capability + server-provided start-over URLs
- Badge on programme: "Available" or "48h" / "7 days"

#### Playback
- Play from start: seek to programme start time from EPG data
- HLS `?start=` parameter or Xtream catch-up URL
- Resume: if partially watched, offer "Continue from X:XX"

#### Timeshift Buffer
- 30-minute rolling buffer on live TV
- Pause → buffer → resume from buffer
- Buffer stored in 500MB rolling cache on device

---

### 7.5 Video on Demand

#### Content Browser
- Categories grid (poster tiles)
- Search: debounced, 300ms, searches title + description
- Recently Added row
- Continue Watching row (shows all partially-watched VOD + series)

#### Series Navigation
- Series → Season → Episode
- Auto-detect next episode (if auto-play enabled)

#### Playback
- Full playback controls: play/pause, seek, skip ±10s/30s, speed 0.5x–2.0x
- Audio track selection (where stream provides multiple)
- Subtitle selection (TV and VOD)
- Resume position saved per episode

#### Casting
- Chromecast sender: cast button in player
- Video + audio routed to Chromecast
- App shows "Now casting" with programme info

---

### 7.6 Cloud DVR (Premium/Family)

#### Recording from EPG
- Tap record on any programme
- Series link: record all new episodes automatically
- Conflict detection: warn if overlapping

#### Storage
- Cloudflare R2 (S3-compatible) per user
- Tier-based limits: 50GB / 200GB / 500GB
- Recordings auto-expire when tier expires

#### Recording Playback
- HLS manifest from R2
- Full VOD playback controls
- Appears in "Saved" section alongside Continue Watching

#### Notifications
- Push notification when recording starts
- Push when new episode of subscribed series is recorded
- In-app notification centre

---

### 7.7 Authentication + Profiles

#### Auth
- Email + password (Firebase Auth)
- Google Sign-In (iOS + Android + web)
- Biometric: Face ID / Touch ID / fingerprint (device-level)

#### Profiles
- Up to 6 per account
- Per-profile: favourites, watch history, parental controls, custom sort
- Fast switch: < 2 seconds, no full logout

#### Cross-Device Sync (Firestore)
- Favourites
- Watch history + resume positions
- Custom channel sort
- Settings / preferences
- Active profile on last close → restored on next open

---

### 7.8 Parental Controls

- PIN: 4-digit, set per profile
- Locked channels: blur + PIN prompt
- Locked categories: entire VOD categories
- Profile lock: PIN required to access profile
- Content ratings: block by rating level (from stream metadata)

---

### 7.9 Subscription + Billing

#### Tiers

| | Free | Standard | Premium | Family |
|---|---|---|---|---|
| **Price** | £0 | £7.99/mo | £12.99/mo | £19.99/mo |
| **Streams** | 1 | 3 | 5 | 10 |
| **Catch-up** | 24h | 7 days | 14 days | Unlimited |
| **DVR storage** | — | 50GB | 200GB | 500GB |
| **Profiles** | 1 | 3 | 6 | 6 + kids mode |
| **DRM** | — | Widevine L1 | Widevine L1 + FairPlay | Full |
| **Annual price** | — | £79.90 | £129.90 | £199.90 |

#### Payments
- iOS/macOS/tvOS: RevenueCat (App Store IAP)
- Android: Google Play Billing
- Web: Stripe Checkout
- Unified subscription state via Firestore

---

## 8. Technical Architecture

### Frontend

```
cloudstream/
├── apps/
│   ├── cloudstream_app/        # Flutter (iOS, Android, macOS)
│   └── cloudstream_tvos/       # Native SwiftUI (tvOS)
├── packages/
│   ├── cloudstream_core/       # Shared business logic
│   ├── cloudstream_data/       # Repositories, data sources
│   ├── cloudstream_domain/     # Entities, use cases
│   ├── cloudstream_ui/         # Shared UI components, design system
│   └── cloudstream_api/        # API client, DTOs
├── backend/
│   ├── epg-service/            # EPG aggregation (FastAPI)
│   ├── dvr-service/            # DVR scheduling (FastAPI)
│   └── api-gateway/            # FastAPI unified gateway
└── infra/
    ├── terraform/              # Cloud infrastructure
    └── docker/                 # Containerisation
```

### Backend Services

| Service | Technology | Responsibility |
|---------|-----------|----------------|
| Auth + sync DB | Firebase Auth + Firestore | Identity, profile sync |
| EPG pipeline | FastAPI + Python | XMLTV fetch → parse → store → distribute |
| DVR service | FastAPI + Python | Recording schedules, R2/S3 storage |
| CDN | Cloudflare Stream | Stream proxying, caching |
| Subscriptions | RevenueCat + Google Play + Stripe | Unified billing |

### Key API Contracts

#### Xtream Integration
```
POST /api/portal/login
  Body: { server, username, password }
  Response: { token, user_info, categories, streams }

GET /api/portal/live
GET /api/portal/vod
GET /api/portal/series
  Auth: Bearer token
```

#### EPG
```
GET /api/epg/{user_id}
  Response: { channels: [...], programmes: [...] }
POST /api/epg/refresh
```

#### DVR
```
GET  /api/dvr/{user_id}/recordings
POST /api/dvr/{user_id}/schedule
DELETE /api/dvr/{user_id}/schedule/{id}
GET  /api/dvr/{user_id}/recordings/{id}/manifest
```

---

## 9. Success Metrics

| Metric | Month 3 Target | Month 6 Target | Month 12 Target |
|--------|--------------|----------------|-----------------|
| Total downloads | 25,000 | 100,000 | 500,000 |
| MAU | 8,000 | 25,000 | 100,000 |
| Paying subscribers | 800 | 2,000 | 10,000 |
| MRR | £6,000 | £15,000 | £80,000 |
| App Store rating | 4.5+ | 4.7+ | 4.7+ |
| D7 retention | 28% | 32% | 35% |
| D30 retention | 12% | 15% | 18% |
| Channel switch time | < 1.2s | < 1.0s | < 0.8s |
| Crash-free sessions | > 99.5% | > 99.8% | > 99.9% |
| P0 bugs at launch | 0 | 0 | 0 |

---

## 10. Competitive Positioning

| | CloudStream | TiviMate | UHF | IPTV Smarters |
|---|---|---|---|---|
| **iOS** | ✅ Flutter | ❌ | ⚠️ Port | ⚠️ Port |
| **Android** | ✅ Flutter | ✅ | ✅ | ✅ |
| **macOS** | ✅ Flutter | ❌ | ⚠️ | ❌ |
| **tvOS** | ✅ Native | ❌ | ❌ | ❌ |
| **Windows** | ✅ Flutter | ❌ | ❌ | ❌ |
| **EPG quality** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| **Catch-up TV** | ✅ | ✅ | ⚠️ Basic | ⚠️ Basic |
| **Cloud DVR** | ✅ | ❌ | ❌ | ❌ |
| **Profile sync** | ✅ Firestore | ❌ | ⚠️ | ❌ |
| **Onboarding speed** | < 60s | > 3 min | ~2 min | ~2 min |
| **Subscription tiers** | ✅ | ❌ | ❌ | ⚠️ |
| **UI polish** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |

---

*This spec is a living document. Updated as product learning accumulates.*
