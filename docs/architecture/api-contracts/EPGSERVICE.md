# CloudStream EPG Service API

> Internal API for EPG data aggregation, caching, and distribution.

**Base URL:** `https://epg-service.cloudstream.tv` (Cloudflare Workers)

**Authentication:** Firebase JWT in `Authorization: Bearer <token>`

---

## Endpoints

### GET /api/epg/{userId}

Fetch EPG data for a user. Returns channels + programmes.

**Query parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `since` | Unix timestamp | 0 | Only return programmes starting after this time |
| `until` | Unix timestamp | +7 days | Only return programmes starting before this time |
| `cursor` | string | null | Pagination cursor |
| `limit` | int | 200 | Max programmes per response (max 500) |

**Response:**
```json
{
  "channels": [
    {
      "id": "bbc_one_hd",
      "name": "BBC One",
      "logo": "https://epg-service.cloudstream.tv/logos/bbc_one_hd.png",
      "number": "1"
    }
  ],
  "programmes": [
    {
      "id": "epg-12345",
      "channel_id": "bbc_one_hd",
      "title": "BBC News",
      "description": "The latest news headlines.",
      "start": 1735689600,
      "end": 1735693200,
      "category": "News",
      "icon": "https://...",
      "catchup_available": true,
      "catchup_days": 7,
      "rating": null
    }
  ],
  "next_cursor": "abc123",
  "has_more": false
}
```

**Notes:**
- `channel_id` maps to Xtream's `epg_channel` field
- `catchup_available` = `true` if the programme is within the catch-up window
- `catchup_days` = how many days of catch-up are available (per Xtream `tv_archive_duration`)

---

### POST /api/epg/refresh

Force a refresh of EPG data from source providers. Used when user adds a new connection.

**Request body:**
```json
{
  "user_id": "firebase-uid",
  "connection_id": "xtream-server-123"
}
```

**Response:**
```json
{
  "status": "queued",
  "job_id": "epg-refresh-job-abc123",
  "estimated_completion_seconds": 30
}
```

**Notes:**
- This is an async operation. The app should poll or use websockets to know when it's done.
- For most users, EPG is refreshed automatically on app launch if stale (> 6 hours).

---

### GET /api/epg/sources

List available EPG source providers. Used for manual XMLTV URL addition.

**Response:**
```json
{
  "sources": [
    {
      "id": "xmltv-org",
      "name": "XMLTV.org",
      "url_template": "https://xmltv.org/xmltv/zip/{region}.xml.gz",
      "regions": ["uk", "us", "de", "fr", "es", "it", "pt"],
      "update_frequency_hours": 24,
      "free": true
    },
    {
      "id": "webguide-tv",
      "name": "WebGuide.tv",
      "url_template": "https://api.webguide.tv/epg/{country}.xml",
      "regions": ["uk"],
      "update_frequency_hours": 6,
      "free": false,
      "requires_subscription": true
    }
  ]
}
```

---

## Error Responses

```json
{
  "error": {
    "code": "EPG_SOURCE_UNAVAILABLE",
    "message": "The EPG source for this region is temporarily unavailable.",
    "retry_after_seconds": 300
  }
}
```

---

## Caching Strategy

- EPG data is cached in Cloudflare's CDN edge cache (TTL: 1 hour)
- User-specific EPG is stored in Firestore for fast retrieval
- App maintains a local Hive cache (7-day rolling window)
- On app launch: check Hive → if stale → fetch from EPG service → update Hive + Firestore

---

## Related Docs

- [ADR-005](adr/ADR-005-firestore-sync.md) — EPG caching strategy
