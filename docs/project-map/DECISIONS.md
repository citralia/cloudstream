# Key Decisions Log

> Major product and technical decisions — the *why* behind choices that shaped the product.

---

## Decision 001: Product Name — CloudStream

**Date:** 2026-05-22
**Deciders:** Josh + engineering

**Decision:** Name the product **CloudStream**.

**Rationale:**
- `StreamVault` was too generic and forgettable
- `CloudStream` directly communicates: cloud-connected, video streaming
- Domain `cloudstream.tv` is the target
- "Cloud" signals cross-device sync and DVR (cloud recording)
- Short, memorable, available as app names on both App Store and Google Play

**Alternatives considered:**
- StreamHub — too generic
- TVCloud — awkward construction
- IPTV Pro — can't trademark (generic)
- VelaTV — no meaning without explanation

---

## Decision 002: Monetisation — Subscription Tiers

**Date:** 2026-05-22
**Deciders:** Josh + engineering

**Decision:** Three-tier subscription model (Free / Standard / Premium / Family) with a free tier that is genuinely useful.

**Rationale:**
- Free tier drives organic growth through word-of-mouth and app store discovery
- The free tier should not feel crippled — 1 stream, 20 channels, 24h catch-up is genuinely useful for casual users
- Paying users subsidise free users — acceptable trade-off
- Tier differentiation (stream count, catch-up depth, DVR) is meaningful without being arbitrary
- Family tier at £19.99/month positions us as premium vs competitors

**Tier summary:**
| Tier | Streams | Catch-up | DVR | Price |
|------|---------|----------|-----|-------|
| Free | 1 | 24h | None | £0 |
| Standard | 3 | 7 days | 50GB | £7.99/mo |
| Premium | 5 | 14 days | 200GB | £12.99/mo |
| Family | 10 | Unlimited | 500GB | £19.99/mo |

---

## Decision 003: Cross-Platform Scope

**Date:** 2026-05-22
**Deciders:** Josh + engineering

**Decision:** iOS + Android + macOS (Flutter) + tvOS (native SwiftUI) — no Windows, no Linux desktop.

**Rationale:**
- TiviMate is Android-only — we fill that gap AND go further
- UHF tried to do everything and the quality suffers
- Apple's hardware ecosystem (iPhone + iPad + Apple TV + Mac) is the primary target demographic
- Windows/Linux desktop is low-ROI — Flutter web covers those use cases if demand emerges
- Native tvOS is non-negotiable — 10-foot UI + Siri Remote requires native implementation

**Windows/Linux:** Not planned. Revisit after App Store launch if demand is proven.

---

## Decision 004: Feature Priority — Onboarding Speed First

**Date:** 2026-05-22
**Deciders:** Josh + engineering

**Decision:** The single most important metric is: **time from app open to first channel playing**. This must be under 60 seconds.

**Rationale:**
- IPTV apps have historically terrible onboarding (TiviMate: 3-5 minutes)
- Most users abandon apps that require setup friction before seeing value
- If onboarding takes > 2 minutes, 60%+ of users never reach a playing channel
- Onboarding speed is a competitive moat — once users experience 60-second setup, TiviMate's flow feels archaic

**Target:** First launch → first channel playing in < 60 seconds for Xtream Codes connection.

---

## Decision 005: No Account Required to Start

**Date:** 2026-05-22
**Deciders:** Josh + engineering

**Decision:** Users can add an IPTV service and start watching without creating an account. Account is required for sync + subscription.

**Rationale:**
- Removes the biggest onboarding drop-off point (registration wall)
- User can evaluate the product fully before being asked to sign up
- Sync + multi-device is the primary account value proposition — once they experience it, they want it
- Subscription is prompted after 3 days of active use — enough time to be hooked

**Trade-off:** Without an account, EPG preferences and channel order are device-local only.

---

## Decision 006: RevenueCat for Subscriptions

**Date:** 2026-05-22
**Deciders:** engineering

**Decision:** RevenueCat as the subscription backend (see ADR-006).

**Rationale:**
- Covers App Store IAP, Google Play Billing, and Stripe web payments under one SDK
- Handles receipt validation, grace periods, and cross-platform attribution
- 2.5–5% revenue share is acceptable for the abstraction and time saved
- Firebase integration is mature and well-documented

---

## Decision 007: No Built-in IPTV Service

**Date:** 2026-05-22
**Deciders:** Josh

**Decision:** CloudStream is a *player*, not an IPTV service provider. We do not sell IPTV subscriptions. We are not an IPTV reseller.

**Rationale:**
- IPTV licensing is legally ambiguous in many jurisdictions
- Content licensing for live TV channels is complex and expensive
- Our users bring their own subscriptions — CloudStream is the vessel
- Legal risk of hosting/selling IPTV content is too high

**Implication:** We do not cache or redistribute IPTV streams. All streams go directly from provider → user.

---

## Decision 008: Cloudflare as Infrastructure Platform

**Date:** 2026-05-22
**Deciders:** engineering

**Decision:** Use Cloudflare (not AWS/GCP) for CDN, DVR storage, and backend hosting.

**Rationale:**
- No egress bandwidth charges — critical for video streaming workloads
- Cloudflare Workers is cheap and scales to zero for API endpoints
- R2 + Stream is purpose-built for video workloads
- Single vendor for CDN + storage + compute simplifies billing and support

---

*This log is append-only. To change a decision, create a new entry explaining the change and why.*
