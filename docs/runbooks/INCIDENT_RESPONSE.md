# Incident Response Playbook

> What to do when a P0 or P1 incident is declared.

---

## Step 1 — Declare the Incident

**Who can declare:** Any engineer

**How:**
1. Post in `#incidents` (or equivalent): "P0/P1 INCIDENT DECLARED: [brief description]"
2. Identify the **Incident Commander (IC)**
3. Open a new incident doc: `docs/runbooks/incidents/YYYY-MM-DD-incident-name.md`

---

## Step 2 — Assess

Answer these questions immediately:

- **What is broken?** (auth, streams, EPG, payments, all)
- **How many users are affected?** (%, absolute numbers from Firebase Analytics)
- **Is it getting worse?** (trending up/down)
- **What started it?** (recent deployment, third-party outage, traffic spike)

---

## Step 3 — Communicate

**Internal (15 min into incident):**
- Post status update in `#incidents`
- Update status page (if one exists)

**External (30 min into incident):**
- Post on status page
- Notify customer support / account managers

**Template:**
```
[INVESTIGATING] We are aware of an issue affecting [service].
Our team is investigating. We will provide an update in [timeframe].
```

**Resolution:**
```
[RESOLVED] The issue affecting [service] has been resolved as of [time].
Users should see normal functionality. [Brief explanation of cause if known.]
```

---

## Step 4 — Investigate

**Common causes and where to look:**

| Symptom | Check |
|---------|-------|
| All streams failing | Xtream server status, Cloudflare Stream status |
| Auth not working | Firebase Auth dashboard, recent Firebase outages |
| EPG not loading | EPG service logs, Cloudflare Workers |
| DVR recordings failing | Cloudflare R2 status, DVR service health |
| Payments failing | RevenueCat dashboard, Stripe dashboard |
| App crashing | Firebase Crashlytics, crash logs |
| Slow performance | Cloudflare CDN cache hit rate, database latency |

---

## Step 5 — Mitigate

**Immediate actions (stop the bleeding):**

```bash
# Roll back last deployment
git revert HEAD
git push origin main

# Disable offending feature flag
# (in Firebase Remote Config or LaunchDarkly)

# Switch to backup service
# (if Xtream server is down, switch to backup server)
```

---

## Step 6 — Resolve

Once the root cause is fixed:

1. Verify the fix works (test on staging / real device)
2. Confirm metrics return to normal
3. Mark incident as resolved in `#incidents`
4. Update status page

---

## Step 7 — Post-Mortem

**Due:** 48 hours after resolution

**Write in:** `docs/runbooks/incidents/YYYY-MM-DD-incident-name.md`

**Template:**
```markdown
# Incident Post-Mortem — [Name]

**Date:** YYYY-MM-DD
**Duration:** X hours Y minutes
**Severity:** P0/P1
**Incident Commander:** [name]
**Status:** RESOLVED

## Summary

One-paragraph description of what happened and impact.

## Timeline (UTC)

| Time | Event |
|------|-------|
| HH:MM | Incident detected |
| HH:MM | IC assigned |
| HH:MM | Root cause identified |
| HH:MM | Mitigation applied |
| HH:MM | Incident resolved |

## Root Cause

What actually caused the incident.

## Contributing Factors

What conditions made this possible or worse.

## Impact

- Users affected: ~X
- Duration: X hours
- Revenue impact (if applicable): £X

## What Went Well

- Fast detection
- Clear communication
- ...

## What Went Poorly

- Slow escalation
- Missing monitoring
- ...

## Action Items

| Action | Owner | Due |
|--------|-------|-----|
| Add monitoring for X | @name | YYYY-MM-DD |
| Fix Y so it doesn't happen again | @name | YYYY-MM-DD |
```
