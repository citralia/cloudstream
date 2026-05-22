# ADR-002: Monorepo with Dart Package Separation

**Status:** Accepted
**Date:** 2026-05-22
**Deciders:** Engineering team

---

## Context

CloudStream is a multi-platform application with shared business logic across iOS, Android, macOS, and a separate tvOS app. We needed a structure that:

- Allows shared code to be consumed by all Flutter targets without copy-paste
- Keeps the tvOS SwiftUI app able to import shared Dart logic (via FFI or HTTP layer)
- Scales as the codebase grows
- Makes it obvious where new code should live

---

## Decision

**Monorepo with scoped Dart packages under `/packages`:**

```
cloudstream/
├── apps/
│   ├── cloudstream_app/     # Flutter (iOS, Android, macOS)
│   └── cloudstream_tvos/    # Native SwiftUI (tvOS)
├── packages/
│   ├── cloudstream_core/    # Domain entities + repository interfaces
│   ├── cloudstream_data/    # DTOs + concrete repository implementations
│   ├── cloudstream_domain/  # Domain exceptions + use cases
│   ├── cloudstream_ui/     # Design system + shared widgets
│   └── cloudstream_api/    # API clients (Xtream, CloudStream backend)
└── backend/                 # FastAPI services (separate deployment)
```

Each package is a standard Dart package with its own `pubspec.yaml` and `lib/`. The main Flutter app declares dependencies on the packages via path references in `pubspec.yaml`.

The tvOS app accesses shared logic through the CloudStream backend API (HTTP) — it does not import Dart packages directly.

---

## Consequences

**Better:**
- Single `flutter pub get` installs all package dependencies
- Changes to shared packages are visible across all consuming apps immediately
- Clear ownership: `cloudstream_ui` owns design tokens, `cloudstream_core` owns domain models
- Version discipline: each package can be versioned independently
- Easier to enforce architectural boundaries with Dart's `import` rules

**Worse:**
- Monorepo grows large — Git history for unrelated packages is shared
- Must be disciplined about not creating circular dependencies between packages
- `pubspec.yaml` in each package must be kept in sync with the main app's SDK constraints

**Neutral:**
- tvOS app is excluded from this package structure (separate repo or separate tree) — it consumes shared logic via the API layer, not direct Dart imports
- Backend services are separate Node.js/Python repos deployed independently

---

## Alternatives Considered

### Single Flat `lib/` Structure

Rejected because: as the app grows, a flat structure makes it unclear where code belongs. Feature modules start interleaving. The design system and API clients become scattered. Package separation enforces architectural discipline.

### Separate Repos Per Package

Rejected because: managing 5+ repos with versioned dependencies is overhead that slows down iteration. `flutter pub` path references are simpler during development. We can split to separate repos later if needed.

### No Shared Package for UI

Rejected because: the design system (tokens, colours, typography, shared widgets) needs to be consistent across all Flutter targets. Duplicating it would create UI drift and maintenance burden.
