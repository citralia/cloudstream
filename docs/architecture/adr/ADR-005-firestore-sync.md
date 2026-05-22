# ADR-005: Firestore for Cross-Device Sync

**Status:** Accepted
**Date:** 2026-05-22
**Deciders:** Engineering team

---

## Context

CloudStream users want seamless continuity: start watching on iPhone, pick up on Apple TV. This requires synchronising:
- Favourites
- Watch history + resume positions
- Custom channel sort order
- Playback preferences
- Last active profile

We needed a data store that is:
- Real-time (changes propagate across devices quickly)
- Works offline (user may be on a plane with no internet)
- Scales to millions of users without infrastructure management
- Has a Flutter SDK that integrates cleanly

---

## Decision

**Firebase Firestore** as the primary sync store, with **Hive** for local-first caching.

```
Read path:  Firestore → local Hive cache → UI
Write path: UI → Hive (immediate) → Firestore (async, retry on reconnect)
```

**Sync scope per user:**
```
/users/{userId}/
  profile/{profileId}/
    favorites: string[]         # channel IDs
    channelOrder: string[]     # custom channel sort
    watchHistory: WatchItem[]   # channel ID + timestamp + resume position
    settings: object          # playback preferences

  subscriptions/{subscriptionId}/
    tier: 'free' | 'standard' | 'premium' | 'family'
    status: 'active' | 'expired'
    expiresAt: timestamp
```

**Conflict resolution:** Last-write-wins with client-side timestamp. No optimistic locking needed for this use case.

**Offline support:**
1. All writes go to Hive first (instant, no network)
2. On reconnect, Firestore SDK syncs automatically
3. If conflict: Firestore's offline queue resolves on reconnect

---

## Consequences

**Better:**
- Zero infrastructure to manage — Firebase handles scaling
- Real-time listeners for cross-device sync
- Works offline out of the box
- Consistent with Firebase Auth integration (same SDK)
- Security rules enforce per-user data isolation

**Worse:**
- Vendor lock-in to Firebase
- Firestore's free tier is limited (50K reads/writes/day across all users)
- At scale, Firestore costs can be significant — need to monitor and potentially migrate hot data to a custom backend

**Neutral:**
- Not all data lives in Firestore — Xtream channel data lives in Hive locally
- Firestore is NOT used as the primary video stream source — only metadata

---

## Alternatives Considered

### Custom Backend + PostgreSQL

Rejected because: we would need to build and maintain a sync service, handle offline queue management, and manage scaling. For a pre-launch product, Firebase is faster to ship with.

### Supabase

Considered. Supabase is excellent but its Flutter SDK is less mature than Firebase. RevenueCat integration (for subscriptions) works better with Firebase. Staying with Firebase reduces integration complexity.

### Couchbase Mobile (Lite)

Evaluated. Excellent offline-first sync, but heavier weight and more complex setup than needed for our use case. Firestore's offline mode is sufficient.
