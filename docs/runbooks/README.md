# CloudStream Runbooks

> Operational playbooks for when things go wrong.

## Index

| Runbook | When to Use |
|---------|-------------|
| [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md) | Production incident — crash, outage, data breach |
| [DEBUGGING.md](DEBUGGING.md) | Debugging specific issues (player, auth, EPG) |

---

## Severity Levels

| Severity | Definition | Response Time | Example |
|----------|-----------|---------------|---------|
| **P0** | Total outage. App completely unusable. | 15 minutes | All streams down, auth failing for all users |
| **P1** | Major feature broken. Significant user impact. | 1 hour | EPG not loading, VOD playback broken |
| **P2** | Feature degraded. Workaround exists. | 4 hours | Slow channel switching, occasional stream drops |
| **P3** | Minor issue. Low user impact. | 24 hours | UI glitch, incorrect channel logo |

---

## Incident Commander

For P0/P1 incidents, one person is **Incident Commander (IC)**:
- IC owns the incident from detection to resolution
- IC writes the timeline in this document
- IC delegates investigation to others if needed

When the incident is resolved: IC writes the post-mortem.

---

## Emergency Contacts

| Role | Contact |
|------|---------|
| Engineering Lead | (to be filled) |
| Backend On-Call | (to be filled) |
| Firebase Support | support@firebase.google.com |
| RevenueCat Support | support@revenuecat.com |
| Cloudflare Support | (dashboard support + enterprise) |

---

*Maintained by: engineering team*
*Last reviewed: 2026-05-22*
