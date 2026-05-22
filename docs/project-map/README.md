# CloudStream — Project Map

> Complete map of all files, directories, and their purpose.

> **Generated:** 2026-05-22 · **Status:** Pre-Development

---

## Root Directory

```
cloudstream/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml              # PR checks: analyze + test + builds
│   │   └── release.yml         # Release: version bump + builds + draft release
│   └── pull_request_template.md # PR checklist template
│
├── apps/                        # (Created in Phase 0.1)
│   └── cloudstream_app/         # Flutter iOS/Android/macOS app
│
├── packages/                    # (Created in Phase 0.1)
│   ├── cloudstream_core/        # Domain entities + repository interfaces
│   ├── cloudstream_data/        # DTOs + concrete repository implementations
│   ├── cloudstream_domain/      # Domain exceptions + use cases
│   ├── cloudstream_ui/          # Design tokens + shared widgets
│   └── cloudstream_api/         # API clients (Xtream, CloudStream backend)
│
├── backend/                     # (Created in Phase 4)
│   ├── epg-service/             # FastAPI EPG aggregation
│   ├── dvr-service/             # FastAPI DVR scheduling + storage
│   └── api-gateway/             # FastAPI unified gateway
│
├── infra/                      # (Created in Phase 4)
│   ├── terraform/               # Cloudflare + Firebase infra
│   └── docker/                  # Backend containerisation
│
├── docs/
│   ├── README.md               # This file
│   ├── architecture/
│   │   ├── README.md           # System overview + data flows
│   │   ├── adr/
│   │   │   ├── README.md       # ADR index
│   │   │   ├── ADR-001-flutter-vs-native.md
│   │   │   ├── ADR-002-package-structure.md
│   │   │   ├── ADR-003-state-management.md
│   │   │   ├── ADR-004-xtream-client.md
│   │   │   ├── ADR-005-firestore-sync.md
│   │   │   ├── ADR-006-billing-stack.md
│   │   │   ├── ADR-007-dvr-storage.md
│   │   │   └── ADR-008-tvos-native.md
│   │   └── api-contracts/
│   │       ├── README.md       # API contract index
│   │       ├── XTREAM.md       # Xtream Codes API reference
│   │       ├── EPGSERVICE.md   # CloudStream EPG service API
│   │       └── DVR.md          # CloudStream DVR service API
│   │
│   ├── guides/
│   │   ├── README.md           # Guide index
│   │   ├── DEVELOPMENT.md       # Local dev setup
│   │   ├── ONBOARDING.md        # User guide: connecting IPTV
│   │   ├── TESTING.md          # Testing strategy + conventions
│   │   ├── CI_CD.md           # CI/CD pipeline walkthrough
│   │   ├── CODE_REVIEW.md      # Review checklist + standards
│   │   ├── RELEASE.md          # How to cut a release
│   │   └── CONTRIBUTING.md     # Redirects to root CONTRIBUTING.md
│   │
│   ├── releases/
│   │   ├── README.md           # Release index + changelog conventions
│   │   ├── TEMPLATE.md         # Release note template
│   │   └── v0.1.0.md          # Initial architecture release
│   │
│   ├── runbooks/
│   │   ├── README.md           # Runbook index + severity levels
│   │   ├── INCIDENT_RESPONSE.md # Incident response playbook
│   │   ├── DEBUGGING.md        # Per-symptom debugging guide
│   │   └── incidents/          # Incident post-mortems (created during incidents)
│   │       └── README.md       # Incident log index
│   │
│   └── project-map/
│       ├── README.md           # This file
│       ├── DECISIONS.md        # Key product + technical decisions
│       └── GLOSSARY.md         # Term definitions
│
├── SPEC.md                     # Full product specification
├── PROJECT_PLAN.md             # 6-phase development plan
├── CONTRIBUTING.md            # Branch strategy, commit format, DoD
├── README.md                  # Public-facing repo readme
└── .gitignore
```

---

## Package Architecture

```
cloudstream_ui ──────────────┐
                            ▼
cloudstream_domain ──► cloudstream_core ──► cloudstream_app
                            ▲
cloudstream_api ─────────────┘
         │
         └──► cloudstream_data
                   │
                   └──► cloudstream_core (interfaces)
```

**Dependency rules (enforced by import rules in `analysis_options.yaml`):**
- `cloudstream_ui` → `cloudstream_core` only
- `cloudstream_data` → `cloudstream_core` + `cloudstream_api`
- `cloudstream_api` → no internal package dependencies (pure client)
- `cloudstream_app` → all packages

---

## Key Files by Phase

| Phase | Files to Create | Location |
|-------|---------------|---------|
| Phase 0.1 | Flutter project scaffold | `apps/cloudstream_app/` |
| Phase 0.2 | Design tokens + components | `packages/cloudstream_ui/` |
| Phase 0.3 | Navigation + app shell | `apps/cloudstream_app/lib/core/` |
| Phase 0.4 | Firebase Auth | `packages/cloudstream_api/lib/firebase/` |
| Phase 0.5 | Xtream client | `packages/cloudstream_api/lib/xtream/` |
| Phase 0.6 | Onboarding flow | `apps/cloudstream_app/lib/features/onboarding/` |
| Phase 1 | Player, EPG | `apps/cloudstream_app/lib/features/player/`, `guide/` |
| Phase 2 | VOD, profiles, Firestore sync | `vod/`, `profiles/` |
| Phase 3 | Subscriptions (RevenueCat) | `packages/cloudstream_api/lib/billing/` |
| Phase 4 | Backend services | `backend/` |
| Phase 5 | tvOS app | `apps/cloudstream_tvos/` |

---

## Files That Don't Exist Yet

The following will be created in future phases:

```
apps/cloudstream_app/
├── lib/
│   ├── main.dart                        # Phase 0.1
│   ├── app.dart                         # Phase 0.1
│   ├── core/
│   │   ├── theme/                       # Phase 0.2
│   │   ├── router/                       # Phase 0.3
│   │   └── constants/                    # Phase 0.1
│   └── features/
│       ├── auth/                         # Phase 0.4
│       ├── home/                         # Phase 0.3
│       ├── player/                       # Phase 1
│       ├── guide/                       # Phase 1
│       ├── vod/                         # Phase 2
│       └── settings/                    # Phase 0.6
└── pubspec.yaml                         # Phase 0.1

packages/cloudstream_ui/                 # Phase 0.2
packages/cloudstream_core/                # Phase 0.1
packages/cloudstream_data/                # Phase 0.5
packages/cloudstream_api/                 # Phase 0.4
backend/epg-service/                     # Phase 4
backend/dvr-service/                      # Phase 4
backend/api-gateway/                      # Phase 4
infra/terraform/                          # Phase 4
```

---

## What's Documented vs What Exists

| Document | Exists? | Last Updated |
|---------|---------|-------------|
| SPEC.md | ✅ Yes | 2026-05-22 |
| PROJECT_PLAN.md | ✅ Yes | 2026-05-22 |
| CONTRIBUTING.md | ✅ Yes | 2026-05-22 |
| README.md | ✅ Yes | 2026-05-22 |
| docs/architecture/README.md | ✅ Yes | 2026-05-22 |
| docs/architecture/adr/* (8 files) | ✅ Yes | 2026-05-22 |
| docs/guides/DEVELOPMENT.md | ✅ Yes | 2026-05-22 |
| docs/guides/TESTING.md | ✅ Yes | 2026-05-22 |
| docs/guides/CI_CD.md | ✅ Yes | 2026-05-22 |
| docs/guides/CODE_REVIEW.md | ✅ Yes | 2026-05-22 |
| docs/guides/RELEASE.md | ✅ Yes | 2026-05-22 |
| docs/guides/ONBOARDING.md | ✅ Yes | 2026-05-22 |
| docs/releases/README.md | ✅ Yes | 2026-05-22 |
| docs/releases/v0.1.0.md | ✅ Yes | 2026-05-22 |
| docs/runbooks/README.md | ✅ Yes | 2026-05-22 |
| docs/runbooks/INCIDENT_RESPONSE.md | ✅ Yes | 2026-05-22 |
| docs/runbooks/DEBUGGING.md | ✅ Yes | 2026-05-22 |
| docs/architecture/api-contracts/* | ❌ Not yet | — |
| docs/project-map/DECISIONS.md | ❌ Not yet | — |
| docs/project-map/GLOSSARY.md | ❌ Not yet | — |
| .github/workflows/ci.yml | ✅ Yes | 2026-05-22 |
| .github/workflows/release.yml | ✅ Yes | 2026-05-22 |
