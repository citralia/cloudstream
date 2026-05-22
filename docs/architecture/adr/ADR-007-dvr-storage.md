# ADR-007: Cloudflare R2 for DVR Storage

**Status:** Accepted
**Date:** 2026-05-22
**Deciders:** Engineering team

---

## Context

Cloud DVR requires storing recorded video files. A 1-hour HD recording is ~1–2GB. We needed:

- Storage that scales from 50GB (Standard) to 500GB (Family)
- HLS-compatible storage (the Flutter player needs HLS manifests)
- Affordable pricing at scale
- S3-compatible API (for DVR service) — standard tooling
- No bandwidth charges for data egress (important for video streaming)

---

## Decision

**Cloudflare R2** (S3-compatible object storage) + **Cloudflare Stream** (for HLS transcoding and delivery).

```
Recording workflow:
  1. DVR service pulls raw stream from Xtream server
  2. Cloudflare Stream transcodes → HLS manifest + segments → R2
  3. User plays recording → HLS manifest from R2 → CloudStream player

Storage tiers:
  Standard:  50GB R2  + Stream minutes
  Premium:   200GB R2 + Stream minutes
  Family:    500GB R2 + Stream minutes
```

**Why Cloudflare (not AWS S3):**
- No egress bandwidth charges — critical for video streaming
- Integrates natively with Cloudflare Stream for HLS transcoding
- S3-compatible API — same tooling as AWS S3
- R2 + Stream pricing is competitive vs AWS at video workloads
- One vendor for CDN + storage + stream processing simplifies operations

---

## Consequences

**Better:**
- No egress charges means predictable costs regardless of how much users watch recordings
- Cloudflare Stream handles HLS segmenting + manifest generation — we don't need to run FFmpeg servers
- S3-compatible means we can use standard AWS SDKs and CLI tooling
- Integration with Cloudflare Workers (our backend API runs on Workers) is zero-cost networking

**Worse:**
- R2 is eventually consistent for new objects — rare but can cause playback issues for brand-new recordings
  - Mitigation: poll until recording is visible before surfacing to user
- Vendor lock-in to Cloudflare (mitigated by S3-compatible API — easy to migrate if needed)

**Neutral:**
- Cloudflare Stream (transcoding) is priced per minute of video processed
- R2 storage is priced per GB/month

---

## Alternatives Considered

### AWS S3 + AWS MediaConvert

Rejected because: AWS egress charges make video streaming expensive. At 100K users watching 2 hours of DVR content/day, egress costs become significant. Cloudflare's no-egress model is better suited.

### Google Cloud Storage + Video Intelligence API

Rejected because: more complex to set up, egress charges similar to AWS. Cloudflare's integration is simpler for our use case.

### Backblaze B2 + Self-Hosted FFmpeg

Rejected because: we'd need to run our own transcoding infrastructure (FFmpeg). Cloudflare Stream removes this operational burden — we offload transcoding entirely.
