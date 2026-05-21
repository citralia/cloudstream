# Contributing to CloudStream

## Branch Strategy

```
main              ← protected, production-ready releases only
  └── develop     ← integration branch, all feature PRs target this
        └── feature/*   ← individual features, squash-merged to develop
        └── fix/*       ← bug fixes
        └── chore/*     ← dependency updates, tooling
        └── hotfix/*    ← emergency production fixes (fast-tracked to main)
```

**Rules:**
- Never push directly to `main` or `develop`
- All PRs require CI to be green
- PRs to `main` require 1 approval + all builds passing
- PRs to `develop` require `flutter analyze` + `flutter test` to pass
- Feature branches are squash-merged to keep `develop` history clean
- Hotfixes skip CI requirements in exceptional circumstances (use sparingly)

## Commit Message Format

```
<type>(<scope>): <description>

Types: feat | fix | refactor | test | docs | chore | ci
Scopes: player | epg | auth | dvr | sub | onboarding | ui | infra
```

**Examples:**
```
feat(player): add quick channel switcher overlay
fix(epg): handle missing programme data gracefully
ci: add tvOS build to GitHub Actions matrix
docs(auth): document token refresh flow
```

**Rules:**
- Use imperative mood ("Add feature" not "Added feature")
- Keep subject line under 72 characters
- Body explains *what* and *why*, not *how*
- Reference issues: "Closes #42" or "Ref #12"

## Definition of Done

Every feature PR must meet ALL of:

1. **CI green** — `flutter analyze` (0 errors), all tests pass, all platform builds succeed
2. **Code review** — at least 1 approval (or self-review checklist for solo work)
3. **Functional test** — tested on target platform
4. **Edge cases** — loading states, empty states, error states, network failure
5. **No P0 bugs** — crashes, data loss, or security issues are zero-tolerance
6. **Telemetry** — analytics event fired for new user interaction
7. **Regression test** — existing features in the same area still work

## Development Setup

### Prerequisites

- Flutter 4.0.0+
- Dart 3.x
- Xcode 15+ (for iOS/macOS builds)
- Android Studio / Android SDK (for Android builds)

### Local Setup

```bash
# Clone the repo
git clone git@github.com:citralia/cloudstream.git
cd cloudstream

# Install Flutter dependencies
flutter pub get

# Run the app (requires a device or simulator)
flutter run

# Run tests
flutter test

# Analyze
flutter analyze
```

### Environment Variables

Copy `.env.example` to `.env` and fill in Firebase credentials (provided separately).

```bash
cp .env.example .env
```

### Code Generation

Some packages use build_runner for code generation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Testing

- **Unit tests:** `flutter test`
- **Widget tests:** `flutter test`
- **Integration tests:** `flutter test integration_test/`
- **Coverage:** target > 70% for new code

## Style Guide

- **Formatting:** `dart format` (included in `flutter analyze`)
- **Naming:** Dart conventions (camelCase for variables, PascalCase for classes)
- **Imports:** use `package:` imports, avoid relative imports for cross-package imports
- **Avoid:** `TODO` comments without an associated issue number
- **Prefer:** `const` constructors, early returns, named parameters over positional

## Reporting Issues

Bug reports should include:
- Platform + version (iOS/Android/macOS)
- Flutter version
- Steps to reproduce
- Expected vs actual behaviour
- Relevant log output / crash logs
