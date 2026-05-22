# ADR-004: Pure Dart Xtream API Client (No Native Code)

**Status:** Accepted
**Date:** 2026-05-22
**Deciders:** Engineering team

---

## Context

Xtream Codes is the dominant IPTV backend system. Virtually all third-party IPTV services expose Xtream's player API. The alternative is to support this via a native library (e.g., calling Java/Kotlin/Swift Xtream libraries), but:

- No official Xtream SDK exists for Dart/Flutter
- Third-party native wrappers exist but are poorly maintained
- The Xtream API is well-documented and straightforward (HTTP + JSON)

---

## Decision

**Build a pure Dart Xtream API client** (`cloudstream_api/lib/xtream/`)

The client implements the Xtream Codes Player API specification:

```
Base URL: http://<server>:<port>/

Login:
  GET /player_api.php?username={user}&password={pass}
  Response: { user_auth: token, user_info: {...}, categories: [...] }

Live Streams:
  GET /player_api.php?action=get_live_streams&category_id={id}

Stream URL:
  GET /live/{username}/{password}/{stream_id}.m3u8

VOD:
  GET /player_api.php?action=get_vod_streams&category_id={id}
  GET /vod/{username}/{password}/{stream_id}.m3u8

EPG:
  GET /player_api.php?action=get_simple_data_table&stream_id={id}
```

All communication is over HTTPS. Credentials are stored in iOS Keychain / Android Keystore via `flutter_secure_storage`.

---

## Consequences

**Better:**
- No native code dependencies for Xtream — no platform channel complexity
- Easy to test: mock HTTP responses with `mockito` or `dio` interceptors
- Works identically on all Flutter platforms
- Fast to iterate: change the client without rebuilding native code
- No native build toolchain required for Xtream features

**Worse:**
- We're reimplementing what a native library might do — but the API is simple enough this is not a burden
- If Xtream changes their API, we must update the client manually

**Neutral:**
- Some IPTV providers have non-standard Xtream implementations — we'll need to handle edge cases as they arise
- The client is for *consuming* Xtream, not for *building* an Xtream server

---

## Alternatives Considered

### Use Existing Flutter Xtream Package

Several community packages exist (`xtreaming`, etc.). Evaluated and rejected because: poorly maintained, missing key endpoints, no tests, not actively developed. Building our own is more reliable.

### Native Platform Channels

If a provider has custom crypto or auth beyond standard Xtream, we would need native code. This is planned as an escape hatch (Phase 2+ if required), but not the default approach.
