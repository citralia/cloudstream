# Glossary

> Term definitions for CloudStream. If a term is ambiguous or industry-specific, it belongs here.

---

## A

### Adaptive Bitrate (ABR)
A streaming technique where video quality automatically adjusts based on available bandwidth. HLS and DASH are the dominant ABR protocols. CloudStream uses HLS exclusively. When bandwidth drops, quality drops (e.g., from 1080p to 720p). When bandwidth recovers, quality increases.

### ADR (Architecture Decision Record)
A document that records a significant technical decision, the context that forced it, the decision made, and the consequences. ADRs are immutable once merged — to reverse a decision, a new ADR is created that supersedes it.

### API Gateway
The CloudStream backend service that acts as a unified entry point for the Flutter app. Routes requests to EPG, DVR, or Xtream services. Runs on Cloudflare Workers.

---

## B

### Background Refresh
iOS/Android feature that allows apps to fetch data in the background when the device is idle or on WiFi. Used for EPG updates and sync. Users can control this in OS settings.

### BLoC (Business Logic Component)
A state management pattern in Flutter. Alternative to Riverpod. Uses streams and events. See ADR-003 for why we chose Riverpod over BLoC.

---

## C

### Catch-Up TV
A feature that lets users watch a programme that was broadcast in the past. Implemented via HLS `?start=` parameter or Xtream's built-in catch-up URL. Requires the IPTV provider's server to support it.

### CDN (Content Delivery Network)
A geographically distributed network of servers that caches and serves content close to users. Cloudflare handles CDN for CloudStream's DVR content. Reduces latency and offloads origin server bandwidth.

### CI/CD (Continuous Integration / Continuous Delivery)
The practice of automatically testing and deploying code changes. CloudStream uses GitHub Actions for CI/CD. See `docs/guides/CI_CD.md`.

### Cloud DVR
Digitally recording live TV to cloud storage. Users schedule recordings from the EPG. Recordings are stored in Cloudflare R2 and played back as HLS. Premium/Family tiers only.

### Cloudflare R2
Cloudflare's S3-compatible object storage. Used for storing Cloud DVR recordings. S3-compatible means it uses the same API as AWS S3 but without egress bandwidth charges.

### Cloudflare Stream
Cloudflare's video streaming product. Handles HLS transcoding (converting video to multiple quality levels) and generates HLS manifests for playback. Used for DVR recordings.

### CocoaPods
The package manager for iOS/macOS native dependencies. Flutter iOS apps use CocoaPods to manage native Swift/Kotlin libraries. `pod install` must be run after `flutter pub get`.

---

## D

### DRM (Digital Rights Management)
Technology that protects content from being copied. CloudStream's Premium/Family tiers include Widevine L1 (Android) and FairPlay (iOS/macOS). Free and Standard tiers have no DRM.

### DTV (Digital TV)
The technical standard for transmitting digital television signals. IPTV is the delivery mechanism (internet protocol). DTV is the content encoding.

---

## E

### EPG (Electronic Programme Guide)
The on-screen programme guide showing what's on now, next, and in the coming days. In CloudStream, EPG data comes from the Xtream API or a manual XMLTV URL. The Now/Next view shows the 4-hour window by default.

### ExoPlayer
Android's media playback library. Powers video playback on Android in CloudStream. More configurable than Android's built-in MediaPlayer. Supports HLS, DASH, and custom codecs.

---

## F

### FairPlay
Apple's DRM system for protecting video content. Used on iOS, iPadOS, macOS, and tvOS. Required for streaming protected content from some IPTV providers.

### Firebase Auth
Firebase's authentication service. Handles email/password and Google Sign-In for CloudStream. Issues JWTs that the backend validates.

### Firebase Firestore
Firebase's NoSQL document database. Used in CloudStream for cross-device sync of favourites, watch history, channel order, and subscription state.

### Flutter
Google's cross-platform UI toolkit. CloudStream's iOS, Android, and macOS apps are built with Flutter. See ADR-001.

### Free Tier
CloudStream's free subscription tier. Allows 1 concurrent stream, 20 channels, 24-hour catch-up. No DVR, no cloud sync. Genuinely useful to drive word-of-mouth.

---

## G

### GoRouter
The declarative navigation library for Flutter. CloudStream uses GoRouter for routing between screens. Handles deep linking and URL-based navigation.

---

## H

### HLS (HTTP Live Streaming)
Apple's streaming protocol. The dominant streaming protocol for live TV and VOD. CloudStream uses HLS exclusively. Key advantage: adaptive bitrate, which adjusts quality to bandwidth.

### Hive
A lightweight NoSQL database for Flutter. Used in CloudStream for local caching of channel lists, EPG data, and settings. Works offline.

---

## I

### IPTV (Internet Protocol Television)
Television delivered over the internet, as opposed to traditional satellite, cable, or aerial. CloudStream is an IPTV player — it consumes IPTV streams, it doesn't provide them.

---

## M

### M3U / M3U8
A playlist file format for audio/video streams. M3U8 is the UTF-8 encoded version. CloudStream supports importing M3U playlists as an alternative to Xtream Codes login.

### MRR (Monthly Recurring Revenue)
The total predictable revenue from active subscriptions each month. Key metric for CloudStream's subscription business.

---

## P

### Picture in Picture (PiP)
A feature that lets video continue playing in a small floating window while using other apps. Supported in CloudStream on iOS 14+ and Android 8+.

### P0 / P1 / P2 / P3
Severity levels for bugs and incidents:
- **P0:** Total outage — app completely unusable
- **P1:** Major feature broken — significant user impact
- **P2:** Feature degraded — workaround exists
- **P3:** Minor issue — low user impact

### Provider
In the IPTV context, a "provider" is the company or service that sells access to live TV channels over the internet. In the Flutter context, "Riverpod providers" are state management constructs.

---

## Q

### QR Code Pairing
A CloudStream feature for quickly importing IPTV credentials to a second device. One device exports a QR code containing the connection details. The second device scans it. No re-entry of credentials required.

---

## R

### RevenueCat
A subscription management platform. CloudStream uses RevenueCat to handle App Store IAP, Google Play Billing, and Stripe web payments under a single SDK. See ADR-006.

### Riverpod
Flutter's state management library. CloudStream uses Riverpod 2.x. See ADR-003.

### RTMP (Real-Time Messaging Protocol)
An older streaming protocol. CloudStream does NOT support RTMP — only HLS. RTMP is deprecated in favour of HLS for modern streaming.

---

## S

### S3 (Simple Storage Service)
Amazon's object storage service. Cloudflare R2 is S3-compatible — it uses the same API. DVR recordings are stored in R2, not AWS S3.

### SID (Stream ID)
In the Xtream API, each channel, VOD, and series has a numeric Stream ID. Used to construct stream URLs: `/live/{user}/{pass}/{stream_id}.m3u8`.

### SwiftUI
Apple's declarative UI framework for iOS, iPadOS, macOS, and tvOS. CloudStream's tvOS app is built with SwiftUI. See ADR-008.

### Siri Remote
The remote control for Apple TV. Uses Bluetooth with directional swipes, taps, and a clickable surface. CloudStream's tvOS app supports Siri Remote navigation natively.

---

## T

### Timeshift
A live TV feature that lets users pause and rewind the current programme. In CloudStream, implemented as a 30-minute rolling buffer stored in a 500MB local cache.

### TiviMate
A popular Android IPTV player. CloudStream's primary competitor on Android. Known for deep EPG support and DVR but Android-only. CloudStream targets feature parity + cross-platform + better UX.

### tvOS
Apple's operating system for Apple TV. CloudStream's tvOS app is built natively with SwiftUI (not Flutter) for optimal 10-foot UI and Siri Remote support.

---

## U

### UHF
Universal HDTV / a cross-platform IPTV player. CloudStream's competitor. UHF is cross-platform but has rougher UX and less active development. CloudStream targets better UX, faster development velocity, and deeper feature set.

### UX (User Experience)
The overall feel and usability of the app. CloudStream's design philosophy prioritises UX over feature count — the app should feel invisible during playback.

---

## V

### VOD (Video on Demand)
Content that can be watched at any time, as opposed to live TV. In CloudStream, VOD content comes from the Xtream API (movies, series). Playback is full VCR controls (seek, speed, audio tracks).

### VPN (Virtual Private Network)
A service that encrypts internet traffic and routes it through a server. Some IPTV providers require a VPN to access their streams. CloudStream does not include or require a VPN.

---

## W

### Widevine
Google's DRM system for Android and Chrome. Widevine L1 is the highest security level — hardware-level decryption. Required for streaming protected content. Available on Premium/Family tiers.

### Widget
In Flutter, a widget is the basic building block of the UI. Everything is a widget — buttons, text, layout containers. In iOS/macOS, "widgets" also refer to home screen widgets (Flutter supports these via home_widget package).

---

## X

### XMLTV
An XML format for describing TV listings. Many IPTV providers publish their programme guide as an XMLTV file. CloudStream supports importing XMLTV URLs as an alternative EPG source.

### Xtream Codes
The dominant IPTV backend/cPanel system. Most third-party IPTV services run on Xtream Codes. Provides: user auth, channel lists, VOD catalog, series, and EPG in a standardised API. CloudStream's primary integration target.
