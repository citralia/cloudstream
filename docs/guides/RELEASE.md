# CloudStream Release Guide

> How to cut a new release — from develop to production.

---

## Release Philosophy

CloudStream releases are **small and frequent**. Never accumulate features for a big-bang release.

**Rule:** If it's been on `develop` for more than 2 weeks without a blocker, ship it.

---

## Release Types

| Type | When | Example |
|------|------|---------|
| **Patch** | Bug fixes only | `1.0.1` |
| **Minor** | New features, backwards compatible | `1.1.0` |
| **Major** | Breaking changes | `2.0.0` |

---

## Release Checklist

### Pre-Release

- [ ] All features for this release are merged to `develop`
- [ ] `develop` has been stable for at least 48 hours (no unresolved P0 bugs)
- [ ] All CI checks pass on `develop`
- [ ] Final manual test on a physical device (iOS + Android)
- [ ] TestFlight / Google Play Internal track tested
- [ ] Version bumped in `pubspec.yaml` + `android/app/build.gradle` + `ios/Runner/Info.plist`

### Release PR

1. Create a PR from `develop` → `main`
2. Title: `Release v{X.Y.Z}`
3. Description includes: what's new, what's fixed, any known issues
4. Get 1 approval (if `main` branch protection requires it)
5. Merge to `main`

### Cutting the Release

```bash
# After merging develop → main:

# Option A: GitHub UI
# Navigate to: github.com/citralia/cloudstream → Releases → Draft a new release

# Option B: Tag + push
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Option C: GitHub Actions (automatic on merge to main)
# The release.yml workflow will trigger and create a draft release
```

### Post-Release

- [ ] Draft release published (GitHub Releases page)
- [ ] TestFlight build submitted to App Store
- [ ] Google Play internal track promoted to production
- [ ] macOS app uploaded to App Store Connect
- [ ] Jira / Linear tickets closed
- [ ] Announcement posted to user channels (if significant release)

---

## Version Numbering

Versions are maintained in:

```yaml
# apps/cloudstream_app/pubspec.yaml
version: 1.0.0+1        # semver + build number (iOS uses build number differently)

# android/app/build.gradle
versionCode 1            # integer, increments with each build
versionName "1.0.0"      # string, shown to users

# ios/Runner/Info.plist
CFBundleShortVersionString: "1.0.0"
CFBundleVersion: "1"
```

**Build number (iOS):** Each upload to App Store must have a unique `CFBundleVersion`. Increment it for every TestFlight/Store submission.

---

## Release Notes Template

```markdown
## CloudStream v1.2.0

*Released: 2026-06-15*

### What's New
- Feature A — brief description (PR #123)
- Feature B — brief description (PR #124)

### Improvements
- Improvement A (PR #125)
- Improvement B (PR #126)

### Bug Fixes
- Fixed crash when switching channels rapidly (PR #127)
- Fixed EPG not loading for users with no server connected (PR #128)

### Known Issues
- None

### Upgrading
No special steps required. Update from the App Store or Google Play.
```

---

## Emergency Hotfix

For critical production bugs:

```bash
# Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/crash-on-channel-switch

# Fix the bug, add tests, commit

# Open PR to main (not develop — this is urgent)
gh pr create --base main --head hotfix/crash-on-channel-switch

# After merge: cherry-pick the commit to develop
git checkout develop
git cherry-pick <commit-sha>
git push origin develop
```

Hotfixes skip the full CI matrix in exceptional circumstances — but they still require:
1. `flutter analyze` to pass
2. A test that reproduces and prevents the bug
3. Manual verification on real device

---

## Related Docs

- [CI_CD.md](CI_CD.md) — Understanding the release pipeline
- [TESTING.md](TESTING.md) — Writing tests before release
