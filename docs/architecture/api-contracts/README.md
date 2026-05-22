# API Contracts

> Authoritative reference for all external and internal API endpoints.

---

## Index

| API | Type | Used By |
|-----|------|---------|
| [XTREAM.md](XTREAM.md) | External (provider-owned) | Flutter app (Phase 0.5+) |
| [EPGSERVICE.md](EPGSERVICE.md) | Internal (CloudStream backend) | Flutter app |
| [DVR.md](DVR.md) | Internal (CloudStream backend) | Flutter app |
| [AUTH.md](AUTH.md) | Internal (Firebase) | Flutter app |
| [BILLING.md](BILLING.md) | Internal (RevenueCat API) | CloudStream backend (webhook handler) |

---

## Common Patterns

### Authentication
All CloudStream backend API calls require a Firebase JWT:

```
Authorization: Bearer <firebase_id_token>
```

The Flutter app obtains this via `FirebaseAuth.instance.currentUser.getIdToken()`.

### Error Responses

All CloudStream backend APIs return errors in this format:

```json
{
  "error": {
    "code": "SUBSCRIPTION_REQUIRED",
    "message": "DVR requires Premium or Family subscription",
    "details": {}
  }
}
```

| HTTP Status | Meaning |
|-------------|---------|
| 200 | Success |
| 400 | Bad request — invalid parameters |
| 401 | Unauthenticated — Firebase JWT missing or invalid |
| 403 | Forbidden — valid auth but insufficient tier |
| 404 | Resource not found |
| 409 | Conflict — e.g., recording slot already occupied |
| 429 | Rate limited |
| 500 | Internal server error |

### Pagination

List endpoints use cursor-based pagination:

```
GET /api/dvr/recordings?cursor=abc123&limit=20
```

Response:
```json
{
  "data": [...],
  "next_cursor": "def456",
  "has_more": true
}
```

---

*Maintained by: engineering team*
