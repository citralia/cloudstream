# ADR-001: Flutter for Mobile/Desktop vs Native Development

**Status:** Accepted
**Date:** 2026-05-22
**Deciders:** Engineering team

---

## Context

CloudStream targets four platforms: iOS, Android, macOS, and tvOS. We needed to choose between:

- **Option A:** Native development per platform (Swift/SwiftUI for Apple, Kotlin for Android)
- **Option B:** Cross-platform framework (Flutter, React Native, or Kotlin Multiplatform)
- **Option C:** Hybrid approach — Flutter for iOS/Android/macOS, native for tvOS

A fully native approach (Option A) would give maximum platform-specific performance and native UI fidelity, but would require maintaining four separate codebases. With a solo or small team, this is unsustainable.

React Native was evaluated but has slower UI performance for video-intensive apps, limited access to low-level media APIs, and a less mature ecosystem for IPTV use cases.

Kotlin Multiplatform (KMP) is promising but the tooling and ecosystem for a video player is less mature than Flutter, and the Flutter video_player + chewie stack is battle-tested for IPTV use cases.

---

## Decision

**Option C — Hybrid Flutter + Native tvOS:**

- **Flutter** for iOS, Android, and macOS
- **Native SwiftUI + AVKit** for tvOS

Rationale: tvOS has distinct UX requirements (10-foot UI, Siri Remote, focus-based navigation) that don't map well to Flutter's widget model. The tvOS app will share business logic via the `cloudstream_core` and `cloudstream_data` packages, but the UI layer is native.

Flutter's优势 for iOS/Android/macOS:
- Single codebase for three platforms
- `video_player` + `chewie` provide a production-tested HLS player
- Excellent state management with Riverpod
- Fast iteration with hot reload
- GoRouter for declarative navigation
- Mature ecosystem for Firebase integration

---

## Consequences

**Better:**
- Single Flutter codebase covers 3 of 4 platforms, dramatically reducing maintenance burden
- Hot reload enables fast iteration on iOS, Android, and macOS simultaneously
- Shared design system (`cloudstream_ui` package) ensures consistency across Flutter platforms
- Shared business logic packages mean backend API changes only need to be updated once

**Worse:**
- tvOS requires separate SwiftUI codebase (double the UI maintenance for that platform)
- Flutter adds a runtime layer — slightly higher memory usage than native
- Some platform-specific APIs (e.g., AVKit features) require platform channels, adding complexity
- Flutter's iOS performance, while good, is not identical to native Swift

**Neutral:**
- Must maintain discipline to keep platform-specific code out of shared packages
- tvOS app will lag slightly behind Flutter app in features during Phase 5

---

## Alternatives Considered

### Option A — Fully Native

Rejected because: maintaining four native codebases (iOS Swift, Android Kotlin, macOS Swift, tvOS Swift) is unsustainable for a small team. Each platform would need its own CI pipeline, its own bug fix cycles, and its own App Store release cadence.

### Option B — React Native

Rejected because: React Native's bridge architecture introduces latency in video playback scenarios. The video_player ecosystem is less mature. Flutter's rendering engine (Skia →Impeller) is better suited to the custom UI components an IPTV app requires (channel grids, EPG overlays).

### Option B — Flutter for tvOS Too

Considered and partially adopted. Flutter does support tvOS, but the UX is not native — Siri Remote gestures, focus traversal, and the 10-foot UI paradigm are better served by SwiftUI. This may be revisited if Flutter's tvOS support matures.
