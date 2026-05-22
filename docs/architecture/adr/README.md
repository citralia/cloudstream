# Architecture Decision Records

> ADRs document significant technical decisions — the *why* behind choices made. They are immutable once merged. If a decision is reversed, add a new ADR superseding the old one.

## Index

| # | Date | Decision | Status |
|---|------|----------|--------|
| [ADR-001](adr/ADR-001-flutter-vs-native.md) | 2026-05-22 | Flutter for mobile/desktop vs native development | Accepted |
| [ADR-002](adr/ADR-002-package-structure.md) | 2026-05-22 | Monorepo with Dart package separation | Accepted |
| [ADR-003](adr/ADR-003-state-management.md) | 2026-05-22 | Riverpod 2.x for state management | Accepted |
| [ADR-004](adr/ADR-004-xtream-client.md) | 2026-05-22 | Pure Dart Xtream API client (no native code) | Accepted |
| [ADR-005](adr/ADR-005-firestore-sync.md) | 2026-05-22 | Firestore for cross-device sync | Accepted |
| [ADR-006](adr/ADR-006-billing-stack.md) | 2026-05-22 | RevenueCat + Stripe for subscriptions | Accepted |
| [ADR-007](adr/ADR-007-dvr-storage.md) | 2026-05-22 | Cloudflare R2 for DVR storage | Accepted |
| [ADR-008](adr/ADR-008-tvos-native.md) | 2026-05-22 | Native SwiftUI for tvOS (not Flutter) | Accepted |

---

## Using ADRs

When making a significant technical decision:

1. Create a new ADR file: `docs/architecture/adr/ADR-XXX-short-title.md`
2. Fill in the template (see any existing ADR)
3. Submit as part of the same PR as the change
4. Add entry to this index

**ADR format:**
- **Status:** `Proposed | Accepted | Deprecated | Superseded`
- **Context:** What forced this decision?
- **Decision:** What was decided?
- **Consequences:** What becomes better / worse?
- **Alternatives considered:** What else was evaluated and why it was rejected

---

*Maintained by: engineering team*
