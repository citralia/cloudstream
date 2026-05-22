# CloudStream DVR Service API

> Internal API for scheduling recordings, managing storage, and playback of DVR content.

**Base URL:** `https://dvr-service.cloudstream.tv` (Cloudflare Workers / FastAPI on R2)

**Authentication:** Firebase JWT in `Authorization: Bearer <token>`

**Subscription enforcement:** All endpoints check `subscription.tier` from Firestore before processing.

---

## Recording a Programme

### POST /api/dvr/schedule

Schedule a recording of a programme from the EPG.

**Request:**
```json
{
  "user_id": "firebase-uid",
  "programme": {
    "epg_id": "epg-12345",
    "channel_id": "bbc_one_hd",
    "title": "BBC News at Six",
    "start": 1735689600,
    "end": 1735693200,
    "stream_id": 101
  },
  "options": {
    "series_link": false,
    "start_padding_seconds": 30,
    "end_padding_seconds": 30
  }
}
```

**Response:**
```json
{
  "id": "rec-abc123",
  "status": "scheduled",
  "programme": {
    "epg_id": "epg-12345",
    "title": "BBC News at Six"
  },
  "scheduled_start": 1735689630,
  "scheduled_end": 1735693230,
  "estimated_duration_seconds": 3720,
  "storage_required_mb": 950,
  "notify_on_start": true,
  "notify_on_complete": true
}
```

**Error — Storage limit exceeded:**
```json
{
  "error": {
    "code": "STORAGE_LIMIT_EXCEEDED",
    "message": "Recording would exceed your 200GB storage limit. Current usage: 199.8GB.",
    "current_usage_gb": 199.8,
    "limit_gb": 200,
    "required_gb": 0.9
  }
}
```

**Error — Tier not允许:**
```json
{
  "error": {
    "code": "TIER_DVR_DISABLED",
    "message": "DVR requires a Premium or Family subscription.",
    "current_tier": "standard"
  }
}
```

---

### GET /api/dvr/schedule/{userId}

List all scheduled recordings.

**Response:**
```json
{
  "recordings": [
    {
      "id": "rec-abc123",
      "status": "scheduled",
      "programme": {
        "epg_id": "epg-12345",
        "title": "BBC News at Six",
        "channel_id": "bbc_one_hd"
      },
      "scheduled_start": 1735689630,
      "scheduled_end": 1735693230,
      "series_link": false
    },
    {
      "id": "rec-def456",
      "status": "recording",
      "programme": {
        "epg_id": "epg-67890",
        "title": "The Simpsons",
        "channel_id": "fox_hd"
      },
      "progress_percent": 34,
      "started_at": 1735689600
    }
  ]
}
```

---

### DELETE /api/dvr/schedule/{recordingId}

Cancel a scheduled recording. If currently recording, stops the recording and saves what was captured.

**Response:**
```json
{
  "id": "rec-abc123",
  "status": "cancelled"
}
```

---

## Completed Recordings

### GET /api/dvr/recordings/{userId}

List all completed recordings.

**Query params:**

| Param | Default | Description |
|-------|---------|-------------|
| `status` | all | Filter: `all` \| `available` \| `processing` \| `failed` |
| `channel_id` | — | Filter by channel |
| `search` | — | Search in title |
| `cursor` | null | Pagination |
| `limit` | 20 | Results per page (max 50) |

**Response:**
```json
{
  "recordings": [
    {
      "id": "rec-xyz789",
      "status": "available",
      "programme": {
        "epg_id": "epg-12345",
        "title": "BBC News at Six",
        "description": "...",
        "channel_id": "bbc_one_hd",
        "start": 1735689600,
        "end": 1735693200,
        "category": "News",
        "icon": "https://..."
      },
      "duration_seconds": 3720,
      "size_mb": 940,
      "recorded_at": 1735693200,
      "expires_at": null,
      "manifest_url": "https://dvr-service.cloudstream.tv/recordings/rec-xyz789/manifest.m3u8",
      "thumbnail_url": "https://dvr-service.cloudstream.tv/recordings/rec-xyz789/thumb.jpg"
    }
  ],
  "storage_used_gb": 87.4,
  "storage_limit_gb": 200,
  "next_cursor": "def456",
  "has_more": false
}
```

---

### GET /api/dvr/recordings/{recordingId}/manifest

Get the HLS manifest for a recording. Used by the player.

**Response:**
```
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:1
#EXTINF:10.0,
segment1.ts
#EXTINF:10.0,
segment2.ts
...
#EXT-X-ENDLIST
```

---

### DELETE /api/dvr/recordings/{recordingId}

Delete a recording from R2 storage.

**Response:**
```json
{
  "id": "rec-xyz789",
  "status": "deleted",
  "storage_freed_mb": 940
}
```

---

## Storage Management

### GET /api/dvr/storage/{userId}

Get storage usage for a user.

**Response:**
```json
{
  "used_gb": 87.4,
  "limit_gb": 200,
  "percent_used": 43.7,
  "recordings_count": 42,
  "oldest_recording": "2026-01-15T10:00:00Z",
  "newest_recording": "2026-05-22T18:30:00Z"
}
```

---

## Recording Statuses

| Status | Meaning |
|--------|---------|
| `scheduled` | Recording is scheduled but hasn't started |
| `recording` | Currently recording |
| `processing` | Recording complete, transcoding/creating manifest |
| `available` | Recording is ready to play |
| `failed` | Recording failed — see `error_code` |
| `expired` | Recording was deleted due to storage limit |
| `cancelled` | User cancelled before recording started |

---

## Error Codes

| Code | Meaning |
|------|---------|
| `STORAGE_LIMIT_EXCEEDED` | No room for new recording |
| `TIER_DVR_DISABLED` | Free/Standard tier — DVR not available |
| `CHANNEL_NOT_RECORDABLE` | This channel doesn't support recording |
| `CONFLICT_OVERLAP` | Overlaps with existing scheduled recording |
| `PROGRAMME_NOT_IN_FUTURE` | Cannot record a programme that's already started |
| `RECORDING_NOT_FOUND` | Recording ID doesn't exist |
| `MAX_CONCURRENT_RECORDINGS` | User hit recording concurrency limit (Family: 3) |

---

## Tier Limits

| Tier | Concurrent recordings | Max storage |
|------|---------------------|-------------|
| Free | 0 | — |
| Standard | 1 | 50GB |
| Premium | 2 | 200GB |
| Family | 3 | 500GB |

---

## Related Docs

- [ADR-007](adr/ADR-007-dvr-storage.md) — Cloudflare R2 + Stream for DVR
- [ADR-006](adr/ADR-006-billing-stack.md) — RevenueCat tier enforcement
