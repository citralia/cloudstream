# CloudStream CI/CD Guide

> How the CI pipeline works, what each job does, and how to interpret results.

---

## Overview

CloudStream has two CI/CD workflows:

1. **`ci.yml`** — Runs on every PR to `main` or `develop`
2. **`release.yml`** — Runs on merge to `main` (production release)

---

## CI Pipeline (`ci.yml`)

Triggered on: PR to `main` or `develop`

### Jobs

```
┌─────────────────────────────────────────────────────────────┐
│                     PULL REQUEST                              │
└─────────────────────────┬─────────────────────────────────────┘
                          ▼
              ┌──────────────────────┐
              │  1. flutter analyze  │  (Ubuntu)
              └──────────┬───────────┘
                          ▼
              ┌──────────────────────┐
              │    flutter test      │  (Ubuntu)
              └──────────┬───────────┘
                          ▼
         ┌────────────────────────────────────────┐
         │  2. build-ios    │  build-android     │  (macOS) (Ubuntu)
         │                   │                    │
         └──────────┬────────┴────────┬───────────┘
                    ▼                 ▼
         ┌────────────────────────────────────────┐
         │         build-macos  (macOS)           │
         └──────────────────────┬─────────────────┘
                                ▼
                    ┌──────────────────────┐
                    │  All jobs must pass   │
                    │  before PR can merge │
                    └──────────────────────┘
```

**Job 1 — `analyze`** (Ubuntu)
```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
```
- Static analysis, linting
- 0 errors required (warnings acknowledged individually)

**Job 2 — `test`** (Ubuntu)
```bash
flutter test --no-pub
```
- Unit + widget tests

**Job 3 — `build-ios`** (macOS, runs in parallel after 1+2 pass)
```bash
flutter build ios --simulator --no-codesign
```
- iOS simulator build (no App Store signing required)
- Build artefact uploaded for inspection

**Job 4 — `build-android`** (Ubuntu, runs in parallel after 1+2 pass)
```bash
flutter build apk --debug
```
- Android debug APK

**Job 5 — `build-macos`** (macOS, runs in parallel after 1+2 pass)
```bash
flutter build macos
```

### Interpreting Results

| CI Status | Meaning |
|-----------|---------|
| ✅ Green | All jobs passed. PR is clear to merge. |
| ❌ Red | One or more jobs failed. Check the job logs. |
| 🔴 Orange | Job timed out (> 30 min). Check for slow tests. |
| ⚠️ Yellow warnings | `flutter analyze` found warnings. Evaluate each one. |

### Debugging CI Failures

**1. `flutter analyze` failures:**
Check the analysis output in the job log. Warnings are listed with file path and line number.

**2. `flutter test` failures:**
The test output is in the job log. Scroll to the failure traceback.

**3. Build failures:**
Build logs are verbose. Look for the first error (not the 100 lines of output that precede it).

---

## Release Pipeline (`release.yml`)

Triggered on: Push to `main`

### Version bumping

Versions follow [Semantic Versioning](https://semver.org):
```
major.minor.patch
  e.g. 1.0.0
```

- **patch:** Bug fixes, no new features
- **minor:** New features, backwards compatible
- **major:** Breaking changes

Version is determined by the `version-bump` input when triggering manually, or defaults to `patch`.

### Jobs

```
Push to main
      ▼
┌─────────────────────────┐
│   Determine version      │  (Parse current tag, bump, create new tag)
└───────────┬─────────────┘
            ▼
┌─────────────────────────────────────────────────────────┐
│  build-ios (macOS)  │  build-android (Ubuntu)         │
│  build-macos (macOS) │  ← all run in parallel         │
└───────────┬───────────────────────────┬────────────────┘
            ▼                           ▼
┌─────────────────────────────────────────────────────────┐
│           Create GitHub Release (draft)                 │
│  - Tag pushed: v1.2.3                                 │
│  - Build artefacts attached                            │
│  - Release notes drafted                              │
└─────────────────────────────────────────────────────────┘
```

### Releasing a New Version

```bash
# Create a PR from develop to main
# After PR is approved and merged:

# Trigger a release manually (optional)
gh workflow run release.yml -f version-bump=minor

# Or push a tag directly
git tag v1.0.0
git push origin v1.0.0
```

---

## Deployment Targets

| Environment | How to Deploy | Who Can Deploy |
|-------------|--------------|----------------|
| Development | `flutter run` locally | All engineers |
| CI (automated) | GitHub Actions | Auto on PR |
| Staging | Manual dispatch | Engineers |
| TestFlight (iOS) | Release workflow | All engineers |
| Google Play Internal | Release workflow | All engineers |
| Production App Store | Manual in App Store Connect | Admin |
| Production Google Play | Release workflow | All engineers |

---

## Artifacts

Build artifacts are retained for 3 days (CI) or 14 days (Release).

| Platform | Artifact Path |
|----------|--------------|
| iOS simulator | `build/ios/iphonesimulator/Runner.app` |
| Android APK | `build/app/outputs/flutter-apk/app-release.apk` |
| macOS | `build/macos/Build/Products/Release/Runner.app` |

---

## Branch Protection Rules

> Requires GitHub Pro for private repos.

`main` is protected. To merge to `main`:
1. PR must be opened from a feature branch
2. At least 1 approval required
3. All CI checks must pass
4. No force pushes to `main`

`develop` is the integration branch. PRs from feature branches target `develop`.

---

## Common Issues

### Build fails with "No simulator available"

The macOS runner has Xcode + simulators installed. Ensure `flutter run -d` uses the simulator name, not the UUID.

### Android build fails with "Keystore not found"

Release builds require a signing keystore. For CI, debug builds are produced (unsigned). For TestFlight/Play Store, configure signing in the release workflow.

### CI is green but the app crashes on device

CI only runs simulator/specified-device builds. Always do a manual test on a real device before release.

---

## Related Docs

- [DEVELOPMENT.md](DEVELOPMENT.md) — Local setup
- [TESTING.md](TESTING.md) — Writing tests
- [RELEASE.md](RELEASE.md) — Cutting a release
