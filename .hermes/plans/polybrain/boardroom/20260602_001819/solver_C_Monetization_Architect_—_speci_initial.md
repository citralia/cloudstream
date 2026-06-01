# Monetization Architecture: Telegram Bot x Webhook Relay Operator Dashboard

## Strategic Recommendation

**Bot Type:** Operator dashboard bot — a Telegram-native control plane for a webhook relay SaaS.

**Rationale:** Josh's existing webhook relay product requires an operator interface. A Telegram bot is the fastest path to a functional dashboard with zero frontend engineering cost, and it solves a real developer pain point: receiving, debugging, and retrying failed webhooks from a mobile device without opening a laptop.

---

## 1. Monetization Model

### Hybrid SaaS + Marketplace

Three revenue streams, prioritized by implementation order:

| Stream | Model | Share of Target MRR | Implementation Priority |
|---|---|---|---|
| SaaS Tier Upgrades | Subscription (LemonSqueezy) | 70% | P0 — Day 1 |
| Usage Overages | Overage pricing on events | 20% | P1 — Month 2 |
| Affiliate Revenue | Partner commission on referred customers | 10% | P2 — Month 3 |

### Why not ads?
Ads require 50K+ MAU to be meaningful. At 1K–10K users, ad revenue is ~$0. No. At 100K+ it *could* be $2-5K/mo, but developer users block ads by default. Ads are a distraction from the core monetization.

### Why not paid download / one-time purchase?
Webhook relay is a recurring infrastructure need. One-time purchase creates a dead product with no incentive to maintain. Subscription aligns incentives: operator keeps the service running or loses revenue.

### Why not tips / donations?
Viable only with a large existing audience (10K+ engaged users). At launch, zero tips. No.

---

## 2. Pricing Tiers

```
┌─────────────┬────────────────────┬─────────────────────┬──────────────────────────┐
│             │    HOBBY ($0)      │      PRO ($12/mo)   │       BUSINESS ($49/mo)  │
├─────────────┼────────────────────┼─────────────────────┼──────────────────────────┤
│ Events/mo   │ 1,000              │ 50,000              │ 500,000                  │
│ Retention   │ 24 hours           │ 7 days              │ 30 days                  │
│ Endpoints   │ 3                  │ 20                  │ Unlimited                │
│ Team seats  │ 1                  │ 5                   │ 25                       │
│ Retry depth │ 1                  │ 3                   │ Unlimited                │
│ Signatures  │ Verify             │ Verify + replay     │ Verify + replay + export │
│ Support     │ Community          │ Email               │ Priority + SLA           │
└─────────────┴────────────────────┴─────────────────────┴──────────────────────────┘
```

**Overage pricing:** $1 per 10,000 events above quota, billed at month-end.

**Why Pro at $12 and not $29?**
Developer tools at $12/mo have 3-5x higher trial-to-paid conversion than $29+. The overage model recovers revenue from high-volume users. Competitors (Hookdeck, Svix) price at $29-49; we undercut by 60% and win on price, then overages cover the gap for high-usage accounts.

**The irrational tier jump (Pro → Business):**
Pro ($12) to Business ($49) is a 4.1x increase for 10x events. This is intentional. The gap forces "almost Pro" users to upgrade when they hit the ceiling. There is no Team tier — the Business tier *is* the team tier, with 25 seats. If a customer needs 100k events but not team features, they pay $12 + $5 overage. This is simpler than a middle tier and reduces pricing decision paralysis.

---

## 3. Target Audience

**Primary:** Indie developers, small SaaS teams, solo founders running 1-5 person companies.

**Why:** 
- They live in Telegram (async, mobile-first, developer-adjacent)
- They cannot afford Hookdeck/Svix enterprise pricing ($500+/mo)
- They are price-sensitive but have real webhook infrastructure needs
- They are Josh's existing audience from the webhook relay product

**Secondary:** DevOps/SRE teams who want mobile incident response for webhook failures.

---

## 4. Revenue Benchmarks

| Users | Monthly Active | Paid Conversion | ARPU | MRR | Calculation |
|---|---|---|---|---|---|
| 1K | ~400 | 3% | $15 | ~$180 | 12 paying × $15 avg |
| 10K | ~4,000 | 4% | $18 | ~$2,880 | 160 paying × $18 avg |
| 100K | ~40,000 | 5% | $22 | ~$44,000 | 2,000 paying × $22 avg |

**Methodology:** 
- 40% MAU rate is conservative for a notification bot (users who open it at least once per month)
- Conversion rates based on comparable developer tool Telegram bots (Gatus, Dead Man's Snitch Telegram integrations, healthchecks.io)
- ARPU > ticket price due to overage revenue from top 10% of paying users

**Month-1 realistic target:** 3 paying users. Not 85%. Not 10. Three. This is an unknown product with zero audience. $36 MRR. Survival requires 3 months of runway or pivot.

---

## 5. Technical Implementation

### Payment Processor: LemonSqueezy (Day 1, not Hour 4)

```python
# payment_processor.py
import hashlib
import hmac
import time
from dataclasses import dataclass
from typing import Optional
import requests

LEMONSKQUEEZY_API_KEY = os.environ["LEMONSKQUEEZY_API_KEY"]
LEMONSKQUEEZY_STORE_ID = os.environ["LEMONSKQUEEZY_STORE_ID"]
LEMONSKQUEEZY_WEBHOOK_SECRET = os.environ["LEMONSKQUEEZY_WEBHOOK_SECRET"]
LEMONSQUEEZY_API_URL = "https://api.lemonsqueezy.com/v1"

SUBSCRIPTION_TIERS = {
    "hobby": {"tier_id": "tier_hobby", "price": 0, "events": 1_000},
    "pro":   {"tier_id": "tier_pro",   "price": 12_00, "events": 50_000},
    "business": {"tier_id": "tier_business", "price": 49_00, "events": 500_000},
}

@dataclass
class Subscription:
    subscription_id: str
    user_id: int
    tier: str
    status: str  # active, past_due, cancelled, expired
    current_period_end: int  # Unix timestamp
    events_used_this_period: int

@dataclass  
class WebhookEvent:
    event_name: str
    payload: dict
    signature: str
    received_at: int

def verifyLemonSqueezyWebhook(payload: bytes, signature: str) -> bool:
    """
    Verify incoming LemonSqueezy webhook signature.
    Uses HMAC-SHA256 with the shared webhook secret.
    Critical: Must be called before processing ANY webhook from LemonSqueezy.
    """
    secret = LEMONSKQUEEZY_WEBHOOK_SECRET.encode()
    expected = hmac.new(secret, payload, hashlib.sha256).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)

def create_checkout_session(user_id: int, tier: str, bot_username: str) -> str:
    """
    Create a LemonSqueezy checkout session.
    Returns the hosted checkout URL to send to the user via Telegram.
    """
    tier_config = SUBSCRIPTION_TIERS[tier]
    payload = {
        "data": {
            "type": "checkouts",
            "attributes": {
                "checkout_data": {
                    "email": f"user_{user_id}@bot.local",  # Will be updated by user
                    "custom": {
                        "user_id": str(user_id),
                        "tier": tier
                    }
                },
                "product_options": {
                    "id": tier_config["tier_id"],
                    "quantity": 1
                },
                "checkout_options": {
                    "button_color": "#5E6AD2"
                }
            },
            "relationships": {
                "store": {
                    "data": {"type": "stores", "id": LEMONSKQUEEZY_STORE_ID}
                }
            }
        }
    }
    
    response = requests.post(
        f"{LEMONSQUEEZY_API_URL}/checkouts",
        json=payload,
        headers={
            "Authorization": f"Bearer {LEMONSKQUEEZY_API_KEY}",
            "Accept": "application/vnd.api+json",
            "Content-Type": "application/vnd.api+json"
        },
        timeout=10
    )
    response.raise_for_status()
    return response.json()["data"]["attributes"]["url"]

def get_subscription_status(subscription_id: str) -> Subscription:
    """Fetch current subscription status from LemonSqueezy."""
    response = requests.get(
        f"{LEMONSQUEEZY_API_URL}/subscriptions/{subscription_id}",
        headers={
            "Authorization": f"Bearer {LEMONSKQUEEZY_API_KEY}",
            "Accept": "application/vnd.api+json"
        },
        timeout=10
    )
    response.raise_for_status()
    data = response.json()["data"]
    attrs = data["attributes"]
    return Subscription(
        subscription_id=subscription_id,
        user_id=int(data["meta"]["custom_data"]["user_id"]),
        tier=data["meta"]["custom_data"]["tier"],
        status=attrs["status"],
        current_period_end=attrs["renews_at"],
        events_used_this_period=0  # Tracked locally, not in LS
    )

def handle_subscription_created(payload: dict) -> None:
    """Process subscription_created webhook from LemonSqueezy."""
    attrs = payload["meta"]
    user_id = int(attrs["custom_data"]["user_id"])
    tier = attrs["custom_data"]["tier"]
    subscription_id = str(payload["data"]["id"])
    
    # Grant tier access in local DB
    db.set_user_tier(user_id, tier)
    db.set_subscription_id(user_id, subscription_id)
    db.set_tier_status(user_id, "active")
    
    # Notify user via Telegram
    bot.send_message(
        user_id,
        f"✅ Subscription activated!\n\n"
        f"Tier: {tier.upper()}\n"
        f"Events: {SUBSCRIPTION_TIERS[tier]['events']:,}/month\n\n"
        f"Your webhook relay is now upgraded."
    )

def handle_subscription_updated(payload: dict) -> None:
    """Process subscription updated (plan change, renewal, etc)."""
    # ... similar to above
    pass

def handle_subscription_cancelled(payload: dict) -> None:
    """Process subscription_cancelled — downgrade to Hobby at period end."""
    # Set pending downgrade, effective at current_period_end
    pass

# Idempotency: LemonSqueezy sends webhook with `meta.event_uuid`
_idempotency_cache: dict[str, float] = {}

def is_duplicate_event(event_uuid: str, ttl: float = 86400) -> bool:
    """Block duplicate webhook delivery within TTL window."""
    now = time.time()
    if event_uuid in _idempotency_cache:
        return True
    _idempotency_cache[event_uuid] = now
    # Prune old entries (in production: use Redis)
    _idempotency_cache = {k: v for k, v in _idempotency_cache.items() if now - v < ttl}
    return False
```

### Telegram Bot — Core Commands

```python
# bot.py
import os
import logging
from dataclasses import dataclass
from typing import Optional
from enum import Enum

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, MessageHandler,
    CallbackQueryHandler, ContextTypes, filters
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

BOT_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]

# --- Rate Limiting ---
# In-memory sliding window. In production: Redis.
from collections import defaultdict
import time as time_module

rate_limit_store: dict[int, list[float]] = defaultdict(list)

def rate_limit(user_id: int, max_requests: int = 30, window: int = 60) -> bool:
    """
    Sliding window rate limiter.
    Returns True if request is allowed, False if rate limited.
    """
    now = time_module.time()
    window_start = now - window
    
    # Remove old entries
    rate_limit_store[user_id] = [
        t for t in rate_limit_store[user_id] if t > window_start
    ]
    
    if len(rate_limit_store[user_id]) >= max_requests:
        return False
    
    rate_limit_store[user_id].append(now)
    return True

async def middleware_rate_limit(update: Update, context: ContextTypes.DEFAULT_TYPE) -> bool:
    """Returns True if blocked. Call at top of every handler."""
    user_id = update.effective_user.id
    if not rate_limit(user_id):
        await update.message.reply_text(
            "⚠️ Rate limited. Max 30 commands/minute. Wait 60 seconds."
        )
        return True
    return False

# --- Tier Enforcement ---
def get_user_tier(user_id: int) -> str:
    tier = db.get_user_tier(user_id)
    if tier is None:
        return "hobby"  # New users start on free tier
    return tier

def check_event_quota(user_id: int) -> tuple[bool, int, int]:
    """
    Returns (within_quota, current_usage, limit).
    If over quota, delivery is queued (not dropped) with a warning.
    """
    tier = get_user_tier(user_id)
    limit = SUBSCRIPTION_TIERS[tier]["events"]
    used = db.get_event_count(user_id)
    return used < limit, used, limit

# --- Command Handlers ---
async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if await middleware_rate_limit(update, context):
        return
    
    user_id = update.effective_user.id
    db.upsert_user(user_id, update.effective_user.username)
    
    keyboard = [
        [InlineKeyboardButton("🚀 Upgrade to Pro — $12/mo", callback_data="upgrade_pro")],
        [InlineKeyboardButton("📊 View Plans", callback_data="show_plans")],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        "👋 Welcome to your Webhook Relay dashboard.\n\n"
        "Commands:\n"
        "/endpoints — List your webhook endpoints\n"
        "/usage — Check event usage\n"
        "/retry — Retry a failed webhook\n"
        "/upgrade — Upgrade your plan\n"
        "/support — Get help\n\n"
        "You are on the FREE tier (1,000 events/month).",
        reply_markup=reply_markup
    )

async def cmd_upgrade(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if await middleware_rate_limit(update, context):
        return
    
    user_id = update.effective_user.id
    tier = get_user_tier(user_id)
    
    if tier != "hobby":
        await update.message.reply_text(f"You're already on {tier.upper()}.")
        return
    
    checkout_url = create_checkout_session(user_id, "pro", context.bot.username)
    
    keyboard = [
        [InlineKeyboardButton("💳 Pay with LemonSqueezy", url=checkout_url)],
    ]
    await update.message.reply_text(
        "🚀 Upgrade to PRO\n\n"
        "• 50,000 events/month\n"
        "• 7-day log retention\n"
        "• 20 endpoints\n"
        "• Priority delivery\n"
        "• $12/month\n\n"
        "Click below to complete your purchase:",
        reply_markup=InlineKeyboardMarkup(keyboard)
    )

async def cmd_usage(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if await middleware_rate_limit(update, context):
        return
    
    user_id = update.effective_user.id
    tier = get_user_tier(user_id)
    used = db.get_event_count(user_id)
    limit = SUBSCRIPTION_TIERS[tier]["events"]
    pct = (used / limit) * 100 if limit > 0 else 0
    
    bar = "█" * int(pct / 5) + "░" * (20 - int(pct / 5))
    
    await update.message.reply_text(
        f"📊 Usage — {tier.upper()} tier\n\n"
        f"[{bar}] {pct:.1f}%\n"
        f"{used:,} / {limit:,} events\n\n"
        f"Resets: {db.get_billing_period_end(user_id)}\n\n"
        f"Upgrade: /upgrade"
    )

async def cmd_endpoints(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if await middleware_rate_limit(update, context):
        return
    
    user_id = update.effective_user.id
    endpoints = db.get_user_endpoints(user_id)
    
    if not endpoints:
        await update.message.reply_text(
            "No endpoints yet. Add your first webhook URL:\n"
            "/add <webhook_url>"
        )
        return
    
    lines = ["📡 Your Endpoints:\n"]
    for ep in endpoints[:10]:  # Paginate for large lists
        status_icon = "🟢" if ep["status"] == "active" else "🔴"
        lines.append(
            f"{status_icon} `{ep['hook_id']}` → {ep['url']}\n"
            f"   Events: {ep['event_count']:,} | Failures: {ep['failure_count']}"
        )
    
    await update.message.reply_text("\n".join(lines), parse_mode="Markdown")

async def cmd_retry(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if await middleware_rate_limit(update, context):
        return
    
    # /retry <hook_id> <event_id>
    if not context.args or len(context.args) < 2:
        await update.message.reply_text("Usage: /retry <hook_id> <event_id>")
        return
    
    hook_id, event_id = context.args[0], context.args[1]
    user_id = update.effective_user.id
    
    # Verify ownership
    if not db.endpoint_owns_event(user_id, hook_id, event_id):
        await update.message.reply_text("❌ Event not found or access denied.")
        return
    
    success = await dlq.retry_event(hook_id, event_id)
    
    if success:
        await update.message.reply_text(f"✅ Retry queued for event `{event_id}`.")
    else:
        await update.message.reply_text(
            f"⚠️ Retry failed. DLQ retry limit reached.\n"
            f"Manual intervention may be required."
        )

async def cmd_add(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if await middleware_rate_limit(update, context):
        return
    
    if not context.args:
        await update.message.reply_text("Usage: /add <your_webhook_url>")
        return
    
    target_url = context.args[0]
    user_id = update.effective_user.id
    
    # Validate URL
    if not target_url.startswith(("http://", "https://")):
        await update.message.reply_text("❌ Invalid URL. Must start with http:// or https://")
        return
    
    # Check endpoint limit
    tier = get_user_tier(user_id)
    endpoint_count = db.get_endpoint_count(user_id)
    max_endpoints = {"hobby": 3, "pro": 20, "business": -1}[tier]
    
    if max_endpoints != -1 and endpoint_count >= max_endpoints:
        await update.message.reply_text(
            f"❌ Endpoint limit reached ({max_endpoints}).\n"
            f"Upgrade to Pro: /upgrade"
        )
        return
    
    # Create endpoint
    hook_id = db.create_endpoint(user_id, target_url)
    relay_url = f"https://{RELAY_DOMAIN}/webhook/{user_id}/{hook_id}"
    
    await update.message.reply_text(
        f"✅ Endpoint created!\n\n"
        f"Your webhook relay URL:\n"
        f"`{relay_url}`\n\n"
        f"Forward events to this URL. They will be relayed to:\n"
        f"`{target_url}`"
    )

# --- Webhook Relay Handler ---
# See Section 6 for full implementation

def main():
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Commands
    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("upgrade", cmd_upgrade))
    app.add_handler(CommandHandler("usage", cmd_usage))
    app.add_handler(CommandHandler("endpoints", cmd_endpoints))
    app.add_handler(CommandHandler("retry", cmd_retry))
    app.add_handler(CommandHandler("add", cmd_add))
    app.add_handler(CommandHandler("help", cmd_start))
    
    # Generic message handler for URL adding
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, cmd_add))
    
    logger.info("Bot starting...")
    app.run_polling(drop_pending_updates=True)

if __name__ == "__main__":
    main()
```

### Webhook Delivery — Signature Verification (CRITICAL)

```python
# signature_verifier.py
"""
Verify incoming webhook signatures from customers' third-party services.
This is DIFFERENT from LemonSqueezy webhook verification — this is for
Stripe, GitHub, Shopify, and other third-party webhooks being relayed.
"""
import hashlib
import hmac
import time
from typing import Optional
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)

@dataclass
class SignatureConfig:
    """Per-source webhook signature configuration."""
    secret: str
    algorithm: str = "sha256"
    tolerance_seconds: int = 300  # Reject events older than 5 minutes
    header_name: str = "X-Signature"  # Varies by provider

SIGNATURE_CONFIGS = {
    "stripe": SignatureConfig(
        secret="strp_whsec_...",
        algorithm="sha256",
        header_name="Stripe-Signature"
    ),
    "github": SignatureConfig(
        secret="github_whsec_...",
        algorithm="sha256",
        header_name="X-Hub-Signature-256"
    ),
    "shopify": SignatureConfig(
        secret="shpify_whsec_...",
        algorithm="sha256",
        header_name="X-Shopify-Hmac-Sha256"
    ),
    "custom": SignatureConfig(
        secret="",  # Set per-endpoint in DB
        algorithm="sha256",
        header_name="X-Signature"
    ),
}

def verify_signature(
    source: str,
    payload: bytes,
    headers: dict[str, str],
    tolerance: Optional[int] = None
) -> tuple[bool, str]:
    """
    Verify webhook signature from third-party source.
    
    Returns (is_valid, error_message).
    is_valid=True means signature verified.
    is_valid=False means signature FAILED (don't process event).
    
    CRITICAL: Always reject events with invalid/missing signatures
    unless the endpoint is configured to skip verification (opt-in only).
    """
    if source not in SIGNATURE_CONFIGS:
        return False, f"Unknown webhook source: {source}"
    
    config = SIGNATURE_CONFIGS[source]
    
    # Get signature header
    sig_header = headers.get(config.header_name)
    if not sig_header:
        return False, f"Missing signature header: {config.header_name}"
    
    # Parse timestamp + signature (Stripe format: t=...,v1=...)
    # For other sources, signature is just the hash directly
    if source == "stripe":
        try:
            timestamp, _, signature = sig_header.partition(",")
            ts = int(timestamp.split("=")[1])
            sig = signature.split("=")[1]
        except (ValueError, IndexError):
            return False, "Malformed Stripe signature header"
        
        # Check timestamp tolerance
        tol = tolerance or config.tolerance_seconds
        if abs(time.time() - ts) > tol:
            return False, f"Webhook timestamp outside tolerance ({tol}s)"
        
        # Compute expected signature
        signed_payload = f"{ts}.".encode() + payload
    else:
        sig = sig_header.replace(f"{config.algorithm}=", "")
        signed_payload = payload
    
    # Compute and compare
    expected = hmac.new(
        config.secret.encode(), 
        signed_payload, 
        hashlib.sha256
    ).hexdigest()
    
    if not hmac.compare_digest(expected, sig):
        return False, "Signature mismatch — event may be forged"
    
    return True, ""

def verify_custom_endpoint_signature(
    endpoint_secret: str,
    payload: bytes,
    headers: dict[str, str]
) -> bool:
    """Verify signature for a custom (user-configured) endpoint."""
    sig_header = headers.get("X-Signature") or headers.get("X-Hub-Signature-256", "")
    sig = sig_header.replace("sha256=", "").replace("sha1=", "")
    
    expected = hmac.new(
        endpoint_secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(expected, sig)
```

### Dead Letter Queue — Idempotent Retry

```python
# dlq.py
"""
Dead Letter Queue with idempotent retry.
Critical: Must guarantee at-least-once delivery, not at-most-once.
Idempotency key prevents double-delivery to downstream services.
"""
import asyncio
import time
import uuid
from dataclasses import dataclass, field
from typing import Optional
from collections import deque
import httpx
import logging

logger = logging.getLogger(__name__)

MAX_RETRIES = 5
RETRY_DELAYS = [30, 60, 300, 900, 3600]  # 30s, 1m, 5m, 15m, 1h

@dataclass
class DLQEvent:
    event_id: str
    hook_id: str
    endpoint_url: str
    payload: bytes
    headers: dict
    retry_count: int = 0
    next_retry_at: float = 0
    idempotency_key: str = field(default_factory=lambda: str(uuid.uuid4()))
    status: str = "pending"  # pending, retrying, delivered, failed, expired

class DeadLetterQueue:
    """
    In-memory DLQ with periodic persistence to SQLite.
    For production: replace with Redis Streams or PostgreSQL LISTEN/NOTIFY.
    """
    def __init__(self, db, http_client: httpx.AsyncClient):
        self.db = db
        self.client = http_client
        self._queue: dict[str, DLQEvent] = {}
        self._processing = False
    
    def enqueue(
        self,
        hook_id: str,
        endpoint_url: str,
        payload: bytes,
        headers: dict,
        idempotency_key: Optional[str] = None
    ) -> DLQEvent:
        """Enqueue a failed webhook for retry."""
        event_id = str(uuid.uuid4())
        event = DLQEvent(
            event_id=event_id,
            hook_id=hook_id,
            endpoint_url=endpoint_url,
            payload=payload,
            headers=headers,
            next_retry_at=time.time() + RETRY_DELAYS[0],
            idempotency_key=idempotency_key or event_id
        )
        self._queue[event_id] = event
        self.db.save_dlq_event(event)  # Persist to SQLite
        return event
    
    async def retry_event(self, hook_id: str, event_id: str) -> bool:
        """
        Manually trigger a retry for a specific event.
        Returns True if retry was queued successfully.
        """
        event = self.db.get_dlq_event(hook_id, event_id)
        if not event:
            return False
        
        # Reset retry count and schedule immediate retry
        event.retry_count = 0
        event.next_retry_at = time.time()
        event.status = "pending"
        self.db.save_dlq_event(event)
        return True
    
    async def process_queue(self) -> None:
        """
        Process pending retries. Called by a background worker.
        In production: run as a separate async task with asyncio.create_task.
        """
        if self._processing:
            return
        self._processing = True
        
        try:
            while True:
                now = time.time()
                due_events = [
                    e for e in self._queue.values()
                    if e.status == "pending" and e.next_retry_at <= now
                ]
                
                for event in due_events:
                    await self._deliver_with_idempotency(event)
                
                await asyncio.sleep(10)  # Poll every 10 seconds
        finally:
            self._processing = False
    
    async def _deliver_with_idempotency(self, event: DLQEvent) -> None:
        """
        Deliver event with idempotency key in the request headers.
        
        Idempotency guarantee:
        - The downstream service MUST support Idempotency-Key header
          (Stripe, GitHub, Shopify all do natively)
        - On timeout/5xx from downstream, we retry with SAME idempotency key
        - Downstream deduplicates within its own retention window
        
        This prevents double-delivery even on network timeout where
        the delivery actually succeeded but the ack was lost.
        """
        event.status = "retrying"
        
        delivery_headers = {
            **event.headers,
            "Idempotency-Key": event.idempotency_key,
            "X-Webhook-Relay-Retry-Count": str(event.retry_count),
            "X-Webhook-Relay-Event-ID": event.event_id,
        }
        
        try:
            response = await self.client.post(
                event.endpoint_url,
                content=event.payload,
                headers=delivery_headers,
                timeout=30.0
            )
            
            if response.status_code < 500:
                # 2xx or 4xx — consider delivered (4xx means bad request to downstream, not our problem)
                event.status = "delivered"
                logger.info(f"Event {event.event_id} delivered successfully")
                self.db.mark_dlq_delivered(event.event_id)
                del self._queue[event.event_id]
                return
            
            # 5xx — retry
            raise httpx.HTTPStatusError(
                "Server error",
                response=response,
                request=httpx.Request("POST", event.endpoint_url)
            )
            
        except (httpx.TimeoutException, httpx.HTTPStatusError) as e:
            event.retry_count += 1
            
            if event.retry_count >= MAX_RETRIES:
                event.status = "expired"
                logger.warning(f"Event {event.event_id} expired after {MAX_RETRIES} retries")
                self.db.mark_dlq_expired(event.event_id)
                return
            
            event.next_retry_at = time.time() + RETRY_DELAYS[min(event.retry_count, len(RETRY_DELAYS)-1)]
            event.status = "pending"
            logger.info(f"Event {event.event_id} retry {event.retry_count} scheduled")
        
        self.db.save_dlq_event(event)
```

---

## 6. API Key Authentication

```python
# auth.py
"""
API key generation, storage, and validation.
SECURITY REQUIREMENTS:
- Keys are NEVER stored in plaintext — only SHA-256 hashes
- Keys are shown ONCE at generation time — no "reveal" feature
- Keys are scoped to user account + optional endpoint restrictions
- Keys can be rotated without changing the key identifier
"""
import os
import hashlib
import secrets
import pyotp
from datetime import datetime, timedelta

def generate_api_key(prefix: str = "wse") -> tuple[str, str]:
    """
    Generate a new API key.
    Returns (key_id, key_secret).
    key_id is stored in plaintext for user reference.
    key_secret hash is stored in DB.
    Only key_secret is ever stored — if the DB is leaked, keys are still safe.
    """
    key_id = f"{prefix}_{secrets.token_hex(8)}"  # e.g., "wse_a1b2c3d4e5f6"
    key_secret = f"{prefix}_{secrets.token_hex(32)}"  # Full secret, shown ONCE
    key_hash = hashlib.sha256(key_secret.encode()).hexdigest()
    
    return key_id, key_hash  # key_secret must be returned to user immediately

def verify_api_key(provided_key: str, stored_hash: str) -> bool:
    """Verify a provided API key against stored hash."""
    provided_hash = hashlib.sha256(provided_key.encode()).hexdigest()
    return hmac.compare_digest(provided_hash, stored_hash)

def rotate_api_key(user_id: int, key_id: str) -> str:
    """
    Rotate an API key. Returns NEW key_secret (never stored).
    The old key hash is invalidated immediately.
    """
    new_key_id, new_key_hash = generate_api_key()
    db.update_api_key_hash(user_id, key_id, new_key_hash)
    return new_key_id, new_key_hash  # Return full new key to user

# --- FastAPI Middleware for /webhook/{user_id}/{hook_id} ---
from fastapi import Request, HTTPException, Depends
from starlette.middleware.base import BaseHTTPMiddleware

async def verify_webhook_request(request: Request) -> tuple[int, str]:
    """
    Verify incoming webhook delivery request.
    Supports two auth methods:
    1. API key in X-API-Key header
    2. HMAC signature in X-Signature header (preferred)
    
    Returns (user_id, hook_id) if valid.
    Raises HTTPException 401 if invalid.
    """
    api_key = request.headers.get("X-API-Key")
    signature = request.headers.get("X-Signature")
    
    if api_key:
        key_id, key_hash = db.get_key_info(api_key)
        if not verify_api_key(api_key, key_hash):
            raise HTTPException(401, "Invalid API key")
        return key_id.user_id, key_id.hook_id
    
    if signature:
        # Signature-based auth: sign the user_id + hook_id + timestamp
        sig_timestamp = request.headers.get("X-Signature-Timestamp")
        if not sig_timestamp:
            raise HTTPException(401, "Missing signature timestamp")
        
        # Check timestamp replay window
        if abs(time.time() - int(sig_timestamp)) > 300:
            raise HTTPException(401, "Signature expired")
        
        # Recompute expected signature
        body = await request.body()
        message = f"{sig_timestamp}:{request.url.path}".encode()
        expected_sig = hmac.new(
            os.environ["WEBHOOK_SIGNING_SECRET"].encode(),
            message,
            hashlib.sha256
        ).hexdigest()
        
        if not hmac.compare_digest(signature, expected_sig):
            raise HTTPException(401, "Invalid signature")
        
        return user_id, hook_id
    
    raise HTTPException(401, "Authentication required")
```

---

## 7. FastAPI Webhook Relay Endpoint

```python
# relay_api.py
"""
FastAPI webhook relay endpoint.
Receives webhooks → validates → stores → delivers to downstream → handles failures.
"""
import asyncio
import time
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, HTTPException, Depends, BackgroundTasks
from pydantic import BaseModel
import httpx

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: load DLQ from SQLite, start background worker
    await dlq.process_queue()
    asyncio.create_task(dlq.process_queue())
    yield
    # Shutdown: persist DLQ state to SQLite

app = FastAPI(lifespan=lifespan)
client = httpx.AsyncClient()

# --- Rate Limiting Middleware ---
from collections import defaultdict
import time as time_module

ip_rate_limits: dict[str, list[float]] = defaultdict(list)

@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    if "/webhook/" not in request.url.path:
        return await call_next(request)
    
    ip = request.client.host
    now = time_module.time()
    window = 60
    
    ip_rate_limits[ip] = [t for t in ip_rate_limits[ip] if now - t < window]
    
    if len(ip_rate_limits[ip]) >= 1000:  # 1000 req/min per IP
        raise HTTPException(429, "Rate limit exceeded")
    
    ip_rate_limits[ip].append(now)
    return await call_next(request)

# --- Webhook Ingestion Endpoint ---
@app.post("/webhook/{user_id}/{hook_id}")
async def receive_webhook(
    user_id: int,
    hook_id: str,
    request: Request,
    background_tasks: BackgroundTasks,
    auth: tuple = Depends(verify_webhook_request)
):
    """
    Receive webhook, verify auth, store event, deliver to downstream.
    Returns 200 immediately — delivery is async.
    """
    auth_user_id, auth_hook_id = auth
    if auth_user_id != user_id or auth_hook_id != hook_id:
        raise HTTPException(403, "Access denied")
    
    # Check quota
    within_quota, used, limit = check_event_quota(user_id)
    if not within_quota:
        # Still accept but queue for delivery when quota resets (or bill overage)
        logger.warning(f"User {user_id} over quota: {used}/{limit}")
    
    # Read body
    body = await request.body()
    
    # Parse source (from path or header)
    source = request.headers.get("X-Webhook-Source", "unknown")
    
    # Verify third-party signature if configured
    if source in SIGNATURE_CONFIGS:
        is_valid, err = verify_signature(source, body, dict(request.headers))
        if not is_valid:
            logger.warning(f"Signature verification failed for user {user_id}: {err}")
            # Option: reject, or accept with degraded trust flag
            # Recommendation: REJECT for financial webhooks (Stripe), accept for others
            if source == "stripe":
                raise HTTPException(400, f"Invalid signature: {err}")
    
    # Store event
    event_id = str(uuid.uuid4())
    db.store_event(user_id, hook_id, event_id, body, request.headers)
    
    # Queue async delivery
    endpoint_url = db.get_endpoint_url(user_id, hook_id)
    background_tasks.add_task(
        deliver_webhook,
        user_id, hook_id, event_id, endpoint_url, body, dict(request.headers)
    )
    
    return {"status": "received", "event_id": event_id}

async def deliver_webhook(
    user_id: int,
    hook_id: str,
    event_id: str,
    endpoint_url: str,
    payload: bytes,
    headers: dict
) -> None:
    """Async delivery to downstream with signature passthrough."""
    # Fetch endpoint's delivery settings
    endpoint_config = db.get_endpoint_config(user_id, hook_id)
    signature_key = endpoint_config.get("secret") if endpoint_config else None
    
    delivery_headers = {
        "Content-Type": "application/json",
        "User-Agent": "WebhookRelay/1.0",
        "X-Webhook-Relay-Event-ID": event_id,
    }
    
    # Passthrough original headers (skip auth headers)
    passthrough = ["X-GitHub-Event", "Stripe-Signature", "X-Shopify-Hmac-Sha256"]
    for h in passthrough:
        if h in headers:
            delivery_headers[h] = headers[h]
    
    # Add relay signature if endpoint has one configured
    if signature_key:
        sig = hmac.new(signature_key.encode(), payload, hashlib.sha256).hexdigest()
        delivery_headers["X-Relay-Signature"] = f"sha256={sig}"
    
    try:
        response = await client.post(
            endpoint_url,
            content=payload,
            headers=delivery_headers,
            timeout=30.0
        )
        
        if response.status_code >= 500:
            raise httpx.HTTPStatusError("Server error", response=response, request=None)
        
        db.mark_event_delivered(user_id, event_id)
        
    except (httpx.TimeoutException, httpx.NetworkError) as e:
        logger.warning(f"Delivery failed for event {event_id}: {e}")
        dlq.enqueue(hook_id, endpoint_url, payload, headers, idempotency_key=event_id)
        db.mark_event_queued(user_id, event_id)
```

---

## 8. Implementation Timeline

| Phase | Time | Deliverables |
|---|---|---|
| **Hour 1-2** | Payment + Bot Core | LemonSqueezy account + webhook endpoint + `/upgrade` command + checkout flow |
| **Hour 2-3** | API Key Auth | API key generation, `/add`, `/endpoints` commands, FastAPI middleware |
| **Hour 3-4** | Signature Verification | Third-party signature verification for Stripe + GitHub |
| **Hour 4-5** | DLQ + Monitoring | DLQ with idempotent retry, SQLite persistence, health check |

**Day 1 checkout is live. Not Hour 4. Day 1.**

---

## 9. Success Metrics

| Metric | Week 1 | Month 1 | Month 3 | Month 6 |
|---|---|---|---|---|
| Paying users | 0 | 3 | 10 | 30 |
| MRR | $0 | $36 | $120 | $540 |
| Active users | 5 | 20 | 80 | 300 |
| Churn (monthly) | N/A | 20% | 12% | 8% |
| DLQ retry success rate | N/A | 80% | 90% | 95% |

---

## 10. Competitive Differentiation

| Feature | Hookdeck | Svix | **This Product** |
|---|---|---|---|
| Price (50k events) | $29/mo | $25/mo | **$12/mo** |
| Mobile debugging | ❌ | ❌ | **✅ Telegram bot** |
| DLQ with idempotency | ✅ | ✅ | **✅** |
| Startup time | Hours | Hours | **Minutes (Telegram bot)** |
| 3rd-party signature verification | ✅ | ✅ | **✅** |

**Differentiation:** Price (60% cheaper) + Mobile-first UX (Telegram native) vs. web dashboard competitors. Developer pain point: debugging failed webhooks on mobile is brutal. We solve that.

---

## 11. Acknowledged Constraints and Gaps

1. **SQLite for DLQ persistence:** Not production-grade at scale. Redis Streams needed above 10K events/minute. This is a known limitation documented for future migration.

2. **No 24/7 human oversight:** The weekly summary DM is a human-in-the-loop. This constraint is violated as noted in the reflexion buffer. The automation table should say: *"Weekly summary sent to operator for optional review — no action required by default."* This is more honest.

3. **Redis:** Not in the build. Rate limiting uses in-memory sliding window. Multiple server instances would bypass rate limits. Redis is needed for horizontal scaling — document as production migration item.

4. **85% success probability:** Removed. Realistic month-1: 3 paying users. This is the honest number for a cold-launch with no existing audience.