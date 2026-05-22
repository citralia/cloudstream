# CloudStream Development Guide

> How to set up your local development environment and build CloudStream.

---

## Prerequisites

Before you start, ensure you have:

| Tool | Version | Install |
|-------|---------|---------|
| Flutter | 4.0.0+ | [flutter.dev](https://flutter.dev) |
| Dart | 3.x (bundled with Flutter) | Bundled |
| Xcode | 15.0+ | Mac App Store |
| Android Studio | Latest | [android.com](https://developer.android.com) |
| CocoaPods | 1.14+ | `sudo gem install cocoapods` |
| Git | 2.40+ | `brew install git` |
| gh | Latest | `brew install gh` |

**Platform requirements:**
- iOS builds: macOS only (Xcode required)
- Android builds: macOS, Linux, or Windows
- macOS builds: macOS only

---

## Step 1 — Clone the Repository

```bash
git clone git@github.com:citralia/cloudstream.git
cd cloudstream
```

If you haven't set up SSH keys for GitHub:
```bash
gh auth login
gh auth setup-git
```

---

## Step 2 — Install Flutter

```bash
# Download Flutter SDK (if not already installed)
cd ~
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# Add to PATH (add to ~/.zshrc or ~/.bashrc)
export PATH="$HOME/flutter/bin:$PATH"

# Verify
flutter --version
```

---

## Step 3 — Firebase Setup

Firebase credentials are required to run the app. **Credentials are not committed to the repo** — they're provided separately and stored locally.

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** (Email/Password + Google Sign-In)
3. Enable **Firestore** (start in production mode, set rules later)
4. Download the configuration files:
   - **iOS:** `GoogleService-Info.plist` → save to `apps/cloudstream_app/ios/Runner/`
   - **Android:** `google-services.json` → save to `apps/cloudstream_app/android/app/`
5. Copy `.env.example` to `.env` and fill in your Firebase config:

```bash
cp .env.example .env
```

Edit `.env`:
```
FIREBASE_API_KEY=your_api_key
FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_project.appspot.com
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_APP_ID=your_app_id
```

**Important:** `.env` is in `.gitignore` — never commit credentials.

---

## Step 4 — Install Dependencies

```bash
cd apps/cloudstream_app
flutter pub get
```

For iOS specifically:
```bash
cd ios
pod install
cd ..
```

---

## Step 5 — Verify the Setup

```bash
# Check Flutter doctor
flutter doctor

# Run the app (requires a device or simulator)
flutter run

# Run tests
flutter test

# Analyze code
flutter analyze
```

Expected `flutter doctor` output:
```
[✓] Flutter (Channel stable)
[✓] Android toolchain
[✓] Xcode
[✓] Chrome (for web, optional)
```

---

## Running on Specific Platforms

### iOS Simulator

```bash
# List available simulators
xcrun simctl list devices available

# Run on a specific simulator
flutter run -d "iPhone 15 Pro"
```

### Android Emulator / Device

```bash
# List devices
flutter devices

# Run on connected device
flutter run -d <device_id>
```

### macOS

```bash
# Enable macOS support (first time only)
flutter config --enable-macos-desktop

# Run
flutter run -d macos
```

---

## Project Structure Quick Reference

```
apps/cloudstream_app/
├── lib/
│   ├── main.dart              # Entry point
│   ├── app.dart               # App widget + GoRouter
│   ├── core/                  # Theme, constants, extensions
│   ├── features/              # Feature modules (auth, home, player, etc.)
│   ├── shared/                # Design system components
│   └── services/              # Repositories, API clients
└── pubspec.yaml
```

---

## Common Tasks

### Add a New Dependency

```bash
cd apps/cloudstream_app
flutter pub add <package_name>
```

### Regenerate Code (if using riverpod_generator or freezed)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Check for Breaking Changes in Dependencies

```bash
flutter pub outdated
```

### Clean Build Cache

```bash
flutter clean
flutter pub get
```

---

## Troubleshooting

### `flutter doctor` shows Xcode errors

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcodebuild -runFirstLaunch
```

### Pod install fails on iOS

```bash
cd ios
pod deintegrate
pod install --repo-update
cd ..
```

### Android build fails with Gradle error

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### `google-services.json` not found

Ensure you've placed `google-services.json` in `android/app/` — the file is required for Firebase on Android.

---

## Related Docs

- [TESTING.md](TESTING.md) — Writing and running tests
- [CI_CD.md](CI_CD.md) — Understanding the CI pipeline
- [CODE_REVIEW.md](CODE_REVIEW.md) — Review checklist
