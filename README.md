# CloudStream

> Premium cross-platform IPTV player — iOS, Android, macOS, tvOS.

CloudStream is the IPTV player built for people who expect quality. Fast channel switching, intelligent EPG, catch-up TV, cloud DVR, and seamless multi-device sync.

**Status:** Pre-Development · [Product Spec](SPEC.md) · [Project Plan](PROJECT_PLAN.md)

---

## Platform Support

| Platform | Status |
|----------|--------|
| iOS | Phase 0 — Not started |
| Android | Phase 0 — Not started |
| macOS | Phase 0 — Not started |
| tvOS | Phase 5 — Not started |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile/Desktop | Flutter 4.x |
| tvOS | SwiftUI + AVKit |
| State management | Riverpod 2.x |
| Navigation | GoRouter |
| Auth | Firebase Auth |
| Sync | Firestore |
| Backend | FastAPI (Python 3.12) |
| Payments | RevenueCat + Stripe |

## Getting Started

```bash
git clone git@github.com:citralia/cloudstream.git
cd cloudstream
flutter pub get
flutter run
```

> Firebase credentials required. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Branch Strategy

```
main ← protected, releases only
  └── develop ← integration branch
        └── feature/* ← squash-merged
        └── fix/*
        └── chore/*
        └── hotfix/*
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for full conventions.

## License

Proprietary — CloudStream Ltd. All rights reserved.
