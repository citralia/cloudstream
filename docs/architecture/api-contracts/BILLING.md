# CloudStream Billing API

> How subscriptions are managed, how RevenueCat webhooks are handled, and how tier state is synchronised with Firestore.

**This is not a user-facing API.** RevenueCat handles the payment UI. CloudStream's backend only handles webhook events from RevenueCat and updates Firestore accordingly.

---

## RevenueCat → CloudStream Flow

```
[User pays on iOS/Android/Web]
        │
        ▼
[RevenueCat validates receipt]
        │
        ▼
[RevenueCat sends webhook to CloudStream backend]
        POST https://api.cloudstream.tv/webhooks/revenuecat
        │
        ▼
[CloudStream backend validates webhook signature]
        │
        ▼
[CloudStream backend writes to Firestore: subscription.tier]
        │
        ▼
[Flutter app observes Firestore → updates subscription state]
```

---

## RevenueCat Webhook Events

RevenueCat sends webhook events to `POST /webhooks/revenuecat`. The backend listens for:

| Event | Action |
|-------|--------|
| `INITIAL_PURCHASE` | Set Firestore `subscription.tier` + `status=active` |
| `RENEWAL` | Update `expires_at`, keep status=active |
| `CANCELLATION` | Set `status=cancelled`, tier remains until expires |
| `BILLING_ISSUE` | Set `status=billing_issue` |
| `EXPIRATION` | Set `status=expired`, set tier to free |
| `PRODUCT_CHANGE` | Upgrade/downgrade tier immediately |
| `TRIAL_CONVERSION` | Treat as INITIAL_PURCHASE |
| `TRIAL_CANCELLATION` | Set status=trial_cancelled |

---

## Webhook Payload

```json
{
  "event": {
    "type": "INITIAL_PURCHASE",
    "app_user_id": "RC-user-id-abc123",
    "product_id": "cs_premium_monthly",
    "entitlement_id": "premium",
    "expiration_at_ms": 1740009600000,
    " purchased_at_ms": 1735689600000,
    "period_type": "normal"
  },
  "configuration": {
    "app_id": "cloudstream-ios"
  }
}
```

---

## Signature Validation

RevenueCat webhooks are signed. The backend validates:

```python
import hmac
import hashlib

def validate_revenuecat_signature(payload: bytes, signature: str, secret: str) -> bool:
    expected = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)
```

---

## Firestore Subscription Document

Updated by the webhook handler:

```
/users/{uid}/subscription/
```

```json
{
  "tier": "premium",
  "status": "active",
  "entitlement_id": "premium",
  "product_id": "cs_premium_monthly",
  "revenuecat_app_user_id": "RC-user-id-abc123",
  "started_at": "2026-05-22T00:00:00Z",
  "expires_at": "2026-06-22T00:00:00Z",
  "cancelled_at": null,
  "billing_issue_at": null,
  "last_sync_at": "2026-05-22T18:30:00Z"
}
```

---

## Tier Mapping

| RevenueCat entitlement_id | Firestore `subscription.tier` |
|---------------------------|-------------------------------|
| `standard` | `standard` |
| `premium` | `premium` |
| `family` | `family` |
| (no entitlement) | `free` |

---

## Subscription Enforcement in Backend

DVR and other premium features check Firestore before processing:

```python
def require_tier(user_id: str, min_tier: str) -> bool:
    doc = firestore.collection("users").document(user_id).get()
    tier = doc.to_dict().get("subscription", {}).get("tier", "free")
    tier_levels = {"free": 0, "standard": 1, "premium": 2, "family": 3}
    return tier_levels[tier] >= tier_levels[min_tier]
```

---

## Related Docs

- [ADR-006](adr/ADR-006-billing-stack.md) — RevenueCat + Stripe decision
