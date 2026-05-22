# Firebase Auth API

> How authentication works in CloudStream.

**This is not a REST API reference** — Firebase Auth is handled by the Firebase SDK. This document describes the authentication flow and integration points.

---

## Authentication Methods

CloudStream supports two authentication methods:

1. **Email/Password** — Firebase Auth native
2. **Google Sign-In** — via `firebase_auth` + `google_sign_in` packages

---

## Auth Flow

```
[App Launch]
    │
    ▼
FirebaseAuth.instance.authStateChanges.listen(...)
    │
    ├── User is signed in
    │       ▼
    │   Get Firebase ID token (getIdToken())
    │       │
    │       ▼
    │   Fetch Firestore user profile
    │   Fetch subscription tier from Firestore
    │       │
    │       ▼
    │   App initialised with auth state
    │
    └── No user (first launch or signed out)
            ▼
        Show onboarding / sign-in screen
```

---

## Token Management

### Firebase ID Token

The Flutter app obtains a Firebase ID token:

```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final idToken = await user.getIdToken();
  // Use idToken in Authorization header for backend calls
}
```

**Token is refreshed automatically** by the Firebase SDK when it expires (1 hour).

### Passing Token to Backend

All CloudStream backend API calls include the Firebase token:

```
Authorization: Bearer <firebase_id_token>
```

The backend validates the token via Firebase Admin SDK:

```python
import firebase_admin
from firebase_admin import auth

def verify_token(id_token: str) -> str:
    """Returns the Firebase UID from a valid token."""
    decoded = auth.verify_id_token(id_token)
    return decoded['uid']
```

---

## Firestore User Document

After sign-up, a Firestore document is created:

```
/users/{uid}/
```

```json
{
  "uid": "firebase-uid",
  "email": "user@example.com",
  "display_name": "Marcus",
  "avatar_id": 3,
  "created_at": "2026-01-15T10:00:00Z",
  "last_active_at": "2026-05-22T18:30:00Z",
  "subscription": {
    "tier": "standard",
    "status": "active",
    "expires_at": "2026-06-22T00:00:00Z",
    "revenuecat_id": "RC-abc123",
    "entitlement": "standard"
  },
  "profiles": {
    "default": {
      "name": "Marcus",
      "avatar_id": 3,
      "favorites": ["channel-101", "channel-102"],
      "channel_order": ["101", "102", "103"],
      "watch_history": [
        {
          "channel_id": "bbc_one_hd",
          "watched_at": "2026-05-22T18:30:00Z",
          "resume_position_seconds": 1247
        }
      ]
    }
  },
  "connections": [
    {
      "id": "conn-abc123",
      "name": "My IPTV",
      "type": "xtream",
      "server_url": "https://server.example.com",
      "username": "user123",
      "logo": "https://...",
      "active": true,
      "added_at": "2026-01-15T10:00:00Z"
    }
  ]
}
```

---

## Auth Security Rules (Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own document only
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## Sign-Out

```dart
await FirebaseAuth.instance.signOut();
```

On sign-out:
- Local Hive cache is cleared (optional — user choice)
- Navigation resets to onboarding
- All Firestore listeners are cancelled

---

## Multi-Device Detection

Firebase Auth doesn't natively support multi-device session management. To detect if a user is signed in on multiple devices simultaneously:

- Subscribe to `authStateChanges` on app launch
- On new device sign-in, invalidate the previous session's local tokens
- Store session metadata in Firestore: `last_active_at`, `device_id`

This is used to enforce the stream concurrency limits per subscription tier.

---

## Related Docs

- [ADR-005](adr/ADR-005-firestore-sync.md) — Firestore data model
