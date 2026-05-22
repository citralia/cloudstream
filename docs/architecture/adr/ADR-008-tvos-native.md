# ADR-008: Native SwiftUI for tvOS (Not Flutter)

**Status:** Accepted
**Date:** 2026-05-22
**Deciders:** Engineering team

---

## Context

We chose Flutter for iOS, Android, and macOS (see ADR-001). Flutter technically supports tvOS. We needed to decide whether the tvOS app should also be built with Flutter, or as a native SwiftUI application.

The tvOS UX paradigm is fundamentally different from mobile/desktop:
- **10-foot UI:** Users view from ~10 feet away, not 1 foot
- **Siri Remote:** No touch gestures — directional pad, swipe, click
- **Focus-based navigation:** Focus moves between elements, doesn't follow touch
- **System chrome:** Apple TV has specific UI conventions (top shelf, parallax icons, etc.)
- **AVKit:** Native video playback APIs are more capable than Flutter's video_player on tvOS

---

## Decision

**Native SwiftUI + AVKit for tvOS** (`apps/cloudstream_tvos/`)

The tvOS app:
- Shares business logic via the `cloudstream_api` HTTP client (not Dart imports)
- Has its own native UI layer written in SwiftUI
- Uses AVKit for video playback (full featured, Apple-native)
- Has a completely separate UI code path from the Flutter app

```
tvOS app architecture:
  SwiftUI Views
        ↓
  CloudStreamTVOSKit (Swift) ← HTTP → CloudStream Backend API
        ↓
  AVKit (native player)
```

**Why not Flutter for tvOS:**
- Flutter's tvOS support exists but is a second-class citizen
- Siri Remote gesture handling in Flutter is inconsistent
- Focus traversal doesn't match Apple's HIG (Human Interface Guidelines)
- AVKit features (audio session management, Picture in Picture, HDR) require platform channels in Flutter
- Flutter's tvOS rendering via Metal is less optimised than AVKit's direct GPU access

---

## Consequences

**Better:**
- Native Apple TV UX that matches Apple's own app conventions
- Best possible video playback quality (AVKit + AVPlayer, hardware-accelerated)
- Siri Remote handled natively by SwiftUI — no custom gesture workarounds
- Top Shelf integration (Apple TV home screen widget) is native-only
- tvOS-specific features (Continue Watching, SharePlay) easier to implement natively

**Worse:**
- Two separate UI codebases for Apple platforms (Flutter iOS app + SwiftUI tvOS app)
- Must maintain feature parity manually between the two
- Requires Xcode for tvOS development (Flutter doesn't need it, but we already need it for iOS signing anyway)
- Additional CI job for tvOS builds (xcodebuild)

**Neutral:**
- Business logic is NOT duplicated — the tvOS app uses the CloudStream backend API, which is shared
- Backend changes benefit both apps simultaneously
- Phase 5 (tvOS) is scheduled separately — tvOS app development lags Flutter by ~5 months

---

## Alternatives Considered

### Flutter tvOS

Considered and rejected because: the 10-foot UI paradigm and Siri Remote require native implementation to feel right. Community feedback on Flutter tvOS apps consistently mentions rough Siri Remote support. Apple's HIG for tvOS is specific enough that a native implementation is worth the added maintenance cost.

### React Native for tvOS

Flutter was already chosen for mobile — introducing React Native for one platform would add another language and toolchain to maintain. Rejected.

### No tvOS App

Rejected by product requirement — tvOS is explicitly a target platform. "No tvOS" is not an acceptable answer.
