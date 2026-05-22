# ADR-006: RevenueCat + Stripe for Subscriptions

**Status:** Accepted
**Date:** 2026-05-22
**Deciders:** Engineering team

---

## Context

CloudStream has a subscription business model with three tiers. We needed to handle:

- In-app purchases on iOS (App Store), Android (Google Play), and macOS
- Web subscriptions (Stripe Checkout)
- Cross-platform subscription state that the backend can enforce
- RevenueCat provides a unified SDK that handles all app stores + web

---

## Decision

**RevenueCat** as the subscription backend, with **Stripe** as the underlying payment processor for web, and native IAP for mobile/desktop.

```
iOS/macOS App Store IAP ─────┐
Android Google Play IAP ──────┼──→ RevenueCat ──→ Firestore (subscription state)
Web Stripe Checkout ──────────┘
```

**RevenueCat products:**
| Product | Platform Store ID | Entitlement |
|---------|-----------------|-------------|
| Standard Monthly | `cs_standard_monthly` | `standard` |
| Standard Annual | `cs_standard_annual` | `standard` |
| Premium Monthly | `cs_premium_monthly` | `premium` |
| Premium Annual | `cs_premium_annual` | `premium` |
| Family Monthly | `cs_family_monthly` | `family` |
| Family Annual | `cs_family_annual` | `family` |

**RevenueCat → Firestore sync:**
When a purchase or cancellation occurs, RevenueCat webhook fires → CloudStream backend validates → updates Firestore `/users/{userId}/subscription/`.

**Backend enforcement:**
- DVR service checks `user.subscription.tier` before allowing new recordings
- Stream concurrency limits enforced per tier
- DVR storage limits enforced

---

## Consequences

**Better:**
- One SDK (`purchases_flutter`) covers App Store, Google Play, and Stripe
- RevenueCat handles receipt validation, subscription status, grace periods, and cross-platform attribution
- Web subscriptions handled by Stripe without needing App Store cut
- RevenueCat analytics show MRR, churn, LTV without custom dashboards

**Worse:**
- RevenueCat takes a 2.5–5% revenue share on top of payment processor fees
- SDK adds to app bundle size
- Debugging payment issues requires RevenueCat dashboard access

**Neutral:**
- Apple requires App Store IAP for digital goods — we must use RevenueCat for iOS, cannot bypass
- Google Play similarly requires Google Play Billing

---

## Alternatives Considered

### Stripe Direct (No RevenueCat)

Rejected because: Stripe alone cannot handle App Store In-App Purchase receipt validation. We'd need to build our own Mac App Store and iOS IAP integration, which is non-trivial and error-prone. RevenueCat's 2.5% is worth it for the abstraction.

### Paddle

Paddle handles both web and app stores. Evaluated but RevenueCat's Flutter SDK and Firebase integration are more mature. Paddle also takes a larger cut (5%+). RevenueCat is the standard for subscription mobile apps.
