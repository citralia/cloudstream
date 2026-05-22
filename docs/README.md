# CloudStream Documentation

> The authoritative source for CloudStream architecture, decisions, guides, and references.

---

## What's Here

```
docs/
├── architecture/
│   ├── README.md              ← Architecture overview + system diagram
│   ├── adr/                   ← Architecture Decision Records
│   │   ├── README.md
│   │   ├── ADR-001-flutter-vs-native.md
│   │   ├── ADR-002-package-structure.md
│   │   ├── ADR-003-state-management.md
│   │   ├── ADR-004-xtream-client.md
│   │   ├── ADR-005-firestore-sync.md
│   │   ├── ADR-006-billing-stack.md
│   │   ├── ADR-007-dvr-storage.md
│   │   └── ADR-008-tvos-native.md
│   └── api-contracts/         ← API contracts
│       ├── README.md
│       ├── XTREAM.md          ← Xtream Codes API reference
│       ├── EPGSERVICE.md      ← CloudStream EPG service
│       ├── DVR.md             ← CloudStream DVR service
│       ├── AUTH.md            ← Firebase Auth integration
│       └── BILLING.md         ← RevenueCat webhook handling
│
├── guides/
│   ├── README.md              ← Guide index
│   ├── DEVELOPMENT.md         ← Full dev setup walkthrough
│   ├── ONBOARDING.md          ← User guide: connecting a service
│   ├── TESTING.md             ← Testing strategy + conventions
│   ├── CI_CD.md              ← CI/CD pipeline walkthrough
│   ├── CODE_REVIEW.md         ← Review checklist + standards
│   ├── RELEASE.md            ← How to cut a release
│   └── CONTRIBUTING.md        ← Redirects to root CONTRIBUTING.md
│
├── releases/
│   ├── README.md              ← Release index + conventions
│   ├── TEMPLATE.md           ← Release note template
│   └── v0.1.0.md             ← Initial architecture release
│
├── runbooks/
│   ├── README.md             ← Runbook index + severity levels
│   ├── INCIDENT_RESPONSE.md  ← Incident response playbook
│   ├── DEBUGGING.md          ← Per-symptom debugging guide
│   └── incidents/
│       └── README.md         ← Incident log index
│
└── project-map/
    ├── README.md             ← Full project map
    ├── DECISIONS.md          ← Key decisions log
    └── GLOSSARY.md           ← Term definitions
```

---

## Quick Links

| Document | When You Need It |
|----------|-----------------|
| [DEVELOPMENT.md](guides/DEVELOPMENT.md) | First time setup, getting the app running |
| [ARCHITECTURE.md](architecture/README.md) | Understanding how the system fits together |
| [ADR index](architecture/adr/README.md) | Why we made specific technical choices |
| [API contracts](architecture/api-contracts/README.md) | All API endpoint references |
| [PROJECT_PLAN.md](../../PROJECT_PLAN.md) | 6-phase development roadmap |
| [RELEASE.md](guides/RELEASE.md) | Cutting a new version |
| [TESTING.md](guides/TESTING.md) | Writing and running tests |
| [INCIDENT_RESPONSE.md](runbooks/INCIDENT_RESPONSE.md) | Production incident playbook |
| [GLOSSARY.md](project-map/GLOSSARY.md) | What does Xtream mean? |

---

## How to Contribute to Docs

Docs live alongside code in `/docs`. If you change architecture, add a feature, or make a decision — update the docs in the same PR.

**Rule:** A PR that changes behaviour must update relevant docs. A PR that adds a new API endpoint must add/update an ADR and update the API contracts.

**Doc types:**
- `guides/` — How to do things. Task-oriented.
- `architecture/adr/` — Why we made decisions. Immutable once merged.
- `architecture/api-contracts/` — What APIs do. Authoritative reference.
- `runbooks/` — When things go wrong. Operational.
- `releases/` — What changed. Changelog for users.

---

## Metrics

| Metric | Count |
|--------|-------|
| Architecture Decision Records | 8 |
| API contract docs | 5 |
| Guides | 7 |
| Runbooks | 3 |
| Total doc pages | ~25 |

---

*Maintained by: engineering team*
*Last reviewed: 2026-05-22*
