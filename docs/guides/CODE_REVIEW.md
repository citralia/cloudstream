# CloudStream Code Review Guide

> Standards and checklist for reviewing and being reviewed.

---

## Why Code Review

Code review is not just about finding bugs — it's about:
- **Knowledge sharing** — two people understand every change
- **Consistency** — enforced standards across the codebase
- **Quality** — catch what tests miss
- **Tradeoffs** — a second opinion on architecture decisions

---

## Review Process

```
Author opens PR
       ▼
Reviewers assigned (1 required for develop, 1 + CI green for main)
       ▼
Automated checks run (CI)
       ▼
Manual review (async, within 24 hours)
       ▼
Author addresses feedback OR discusses
       ▼
Reviewer approves
       ▼
PR merged (squash-merged to develop, merge commit to main)
```

---

## What to Review

### Correctness

- Does the code do what the description says?
- Are edge cases handled? (empty state, loading, error, network failure, slow network, no network)
- Are there any P0 bugs introduced? (crashes, data loss, security issues)
- Does the code handle concurrent access correctly?

### Design

- Is the change in the right place? (right package, right layer)
- Does it follow existing patterns?
- Are new abstractions justified by real reuse, or premature?
- Is the API surface clean?

### Tests

- Is there a test for the new behavior?
- Do tests cover the edge cases?
- Are tests testing behaviour, or implementation details?
- Is coverage maintained?

### Performance

- Any N+1 queries?
- Any expensive operations on the main thread?
- Any large allocations in loops?
- Any caching opportunities missed?

### Security

- Any credentials in code? (should be in environment variables / `.env`)
- Any user input used unsanitised?
- Any rate limiting missing on new endpoints?
- Any new permissions requested on iOS/Android?

---

## How to Leave Comments

**Be specific:**
```
❌ "This is slow"
✅ "This query will do N+1 reads when there are N channels.
     Consider fetching channels in a single batch query."
```

**Be constructive:**
```
❌ "This is wrong"
✅ "This will return a 404 if the user has no channels.
     Let's handle the empty case explicitly."
```

**Distinguish severity:**
- 🔴 **Blocking** — must fix before merge
- 🟡 **Suggestion** — consider, but not blocking
- 🟢 **Nit** — tiny style/format preference

---

## PR Review Checklist

### Author Checklist (submitting a PR)

- [ ] PR description explains *what* and *why*, not just *what changed*
- [ ] Screenshots / recordings for UI changes
- [ ] All CI checks green
- [ ] New tests added for new behavior
- [ ] No credentials or secrets in code
- [ ] `flutter analyze` returns 0 errors
- [ ] Breaking changes noted in PR description
- [ ] Related documentation updated

### Reviewer Checklist (reviewing a PR)

- [ ] Read the PR description first
- [ ] Understand the *goal*, not just the diff
- [ ] Check edge cases (load, empty, error states)
- [ ] Verify test coverage is adequate
- [ ] Check for security concerns
- [ ] Verify no unintended regressions
- [ ] Leave specific, actionable comments
- [ ] Distinguish blocking vs non-blocking feedback

---

## Response Time

- **Expected:** Review within 24 hours of assignment
- **If blocked:** Leave a comment so the author knows you're looking
- **If you can't review:** unassign yourself and assign someone else

---

## Merging

- **develop:** Squash-merged (one commit per feature)
- **main:** Merge commit (preserves feature branch history)

Never force-push to `main` or `develop`.

---

## Resolving Disagreements

If author and reviewer disagree:

1. Discuss in the PR thread (async)
2. If still unresolved, jump to a quick 10-minute call
3. If still unresolved, escalate to a written ADR

---

## Related Docs

- [CONTRIBUTING.md](../../CONTRIBUTING.md) — Branch strategy + commit conventions
- [TESTING.md](TESTING.md) — Writing tests
