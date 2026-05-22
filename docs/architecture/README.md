# CloudStream — Architecture Overview

> **Status:** Pre-Development
> **Last Updated:** 2026-05-22

---

## System Context

CloudStream has four layers:

```
┌─────────────────────────────────────────────────────────┐
│                    Client Applications                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │ iOS/     │  │ Android  │  │  macOS   │  │  tvOS  │  │
│  │ Flutter  │  │ Flutter  │  │ Flutter  │  │SwiftUI │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───┬────┘  │
│       └──────────────┴──────────────┴─────────────┘      │
│                         │                                │
│                    GoRouter / AVPKit                     │
└─────────────────────────┼───────────────────────────────┘
                          │ HTTPS
┌─────────────────────────┼───────────────────────────────┐
│                   CloudStream Backend                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  EPG Service  │  │  DVR Service │  │ API Gateway  │  │
│  │  (FastAPI)    │  │  (FastAPI)    │  │  (FastAPI)   │  │
│  └───────┬──────┘  └───────┬──────┘  └──────┬───────┘  │
│          │                  │                   │          │
│  ┌───────┴──────────────────┴──────────────────┴───────┐  │
│  │              Cloudflare CDN + R2 Storage             │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────┼───────────────────────────────┐
│                    Firebase                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   Auth       │  │  Firestore    │  │   Hosting    │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└──────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────┼───────────────────────────────┐
│                    External Services                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Xtream IPTV  │  │ RevenueCat   │  │  Stripe      │   │
│  │ Servers      │  │ (Billing)    │  │  (Payments)  │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└──────────────────────────────────────────────────────────┘
```

---

## Application Architecture

### Package Structure

```
cloudstream/
├── apps/
│   ├── cloudstream_app/          # Flutter multi-platform app
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── app.dart          # App widget + GoRouter
│   │   │   ├── core/             # Theme, constants, extensions
│   │   │   ├── features/         # Feature modules
│   │   │   │   ├── auth/
│   │   │   │   ├── home/
│   │   │   │   ├── player/
│   │   │   │   ├── guide/
│   │   │   │   ├── vod/
│   │   │   │   └── settings/
│   │   │   ├── shared/           # Shared widgets + design system
│   │   │   └── services/         # Repositories, API clients
│   │   └── pubspec.yaml
│   │
│   └── cloudstream_tvos/          # Native tvOS app (Phase 5)
│       ├── Sources/
│       │   ├── CloudStreamApp/
│       │   └── ContentView/
│       └── project.yml
│
├── packages/
│   ├── cloudstream_core/          # Shared business logic
│   │   ├── lib/
│   │   │   ├── entities/         # Domain models
│   │   │   ├── repositories/     # Repository interfaces
│   │   │   └── usecases/          # Business logic
│   │   └── pubspec.yaml
│   │
│   ├── cloudstream_data/          # Data layer implementation
│   │   ├── lib/
│   │   │   ├── datasources/       # Remote + local data sources
│   │   │   ├── models/            # DTOs, JSON serialisation
│   │   │   └── repositories/      # Concrete repository implementations
│   │   └── pubspec.yaml
│   │
│   ├── cloudstream_domain/        # Domain layer
│   │   ├── lib/
│   │   │   ├── entities/          # Core domain entities
│   │   │   ├── repositories/      # Repository interfaces (abstract)
│   │   │   └── exceptions/        # Domain exceptions
│   │   └── pubspec.yaml
│   │
│   ├── cloudstream_ui/             # Shared design system
│   │   ├── lib/
│   │   │   ├── tokens/            # Design tokens
│   │   │   ├── components/         # Reusable widgets
│   │   │   └── theme/             # ThemeData
│   │   └── pubspec.yaml
│   │
│   └── cloudstream_api/            # API client library
│       ├── lib/
│       │   ├── xtream/             # Xtream API client
│       │   ├── cloudstream_api/    # CloudStream backend client
│       │   └── firebase/           # Firebase auth + firestore helpers
│       └── pubspec.yaml
│
├── backend/
│   ├── epg-service/               # FastAPI EPG aggregation
│   │   ├── main.py
│   │   ├── routers/
│   │   ├── services/
│   │   └── requirements.txt
│   │
│   ├── dvr-service/               # FastAPI DVR scheduling + storage
│   │   ├── main.py
│   │   ├── routers/
│   │   ├── services/
│   │   └── requirements.txt
│   │
│   └── api-gateway/               # FastAPI unified gateway
│       ├── main.py
│       ├── routers/
│       └── requirements.txt
│
└── infra/
    ├── terraform/                  # Cloudflare + Firebase infra
    └── docker/                     # Backend containerisation
```

---

## Data Flows

### Authentication Flow

```
User → Firebase Auth (email/password or Google)
     ↓
Firebase JWT issued
     ↓
JWT stored in Flutter SecureStorage (iOS Keychain / Android Keystore)
     ↓
All Firestore reads → JWT attached via Firebase SDK
All CloudStream backend calls → JWT in Authorization header
     ↓
Backend validates JWT → extracts user_id → enforces subscription tier
```

### Channel Playback Flow

```
User taps channel
     ↓
ChannelRepository.getStreamUrl(channelId, userId)
     ↓
Check cache (Hive) for stream URL
     ↓
If not cached: fetch from Xtream API → cache in Hive (TTL: 5 min)
     ↓
Pass HLS URL to video_player
     ↓
ExoPlayer (Android) / AVPlayer (iOS/macOS) handles adaptive bitrate
     ↓
Analytics event: stream_start, stream_error, channel_switch_duration
```

### EPG Sync Flow

```
App launch → check last EPG refresh timestamp
     ↓
If > 6h since refresh: fetch from CloudStream backend / Xtream API
     ↓
Parse XMLTV / JSON → local Hive cache (7-day retention)
     ↓
Also push to Firestore for cross-device sync
     ↓
UI renders from Hive (offline-capable)
```

---

## State Management (Riverpod 2.x)

```
Providers are scoped by feature:

// Auth
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>
final currentUserProvider = Provider<User?>
final subscriptionTierProvider = FutureProvider<SubscriptionTier>

// Player
final currentChannelProvider = StateProvider<Channel?>
final playbackStateProvider = StateNotifierProvider<PlaybackNotifier, PlaybackState>
final recentChannelsProvider = StateProvider<List<Channel>>

// EPG
final epgProvider = FutureProvider<EpgData>
final nowNextProvider = Provider<List<Programme>>

// VOD
final vodRepositoryProvider = Provider<VodRepository>
final continueWatchingProvider = StreamProvider<List<VodItem>>
```

---

## API Contracts

See [`docs/architecture/api-contracts/`](api-contracts/README.md) for full API documentation.

---

## Security Model

| Surface | Mechanism |
|---------|-----------|
| User credentials | Firebase Auth (handled entirely by Firebase) |
| Xtream credentials | Stored in iOS Keychain / Android Keystore |
| Backend API calls | Firebase JWT in Authorization header |
| Subscription enforcement | Backend validates JWT + tier before serving DVR |
| DRM (Premium) | Widevine L1 (Android) + FairPlay (iOS/macOS) via Cloudflare Stream |
| Payment data | Never touches CloudStream servers — RevenueCat + Stripe |

---

## Deployment Model

| Environment | Trigger | Artefact |
|------------|---------|---------|
| Development | `flutter run` locally | Local device / simulator |
| CI | PR to `develop` or `main` | Build artefacts uploaded |
| Staging | Manual dispatch | APK / TestFlight |
| Production | Merge to `main` | App Store / Google Play / TestFlight |

---

## Related Docs

- [ADR Index](adr/README.md) — Why we chose each technology
- [API Contracts](api-contracts/README.md) — External API references
- [DEVELOPMENT.md](../guides/DEVELOPMENT.md) — Setting up your dev environment
