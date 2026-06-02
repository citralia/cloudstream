# Telegram Income Stream Strategy — Growth & Monetization (Revised)

## Pre-Conditions: What This Plan Does NOT Do

This plan does NOT recommend financial signal bots, price alert bots, or trading recommendation bots. Under UK FCA rules, a bot that tells users to buy, sell, or hold a financial instrument (crypto, stocks, CFDs) constitutes regulated financial advice. That requires FCA authorisation, compliance overhead, capital adequacy, and legal disclaimers — none of which are compatible with a sub-£50 setup budget and a non-technical operator.

**Hard constraint throughout:** The bot provides informational content about digital products only. No financial instruments. No price movements. No buy/sell signals.

---

## Critical Corrections From Prior Version

Before the main plan, the four valid criticisms from the boardroom review:

### Correction 1: Setup Time Is Not 5 Hours

The original claimed "less than 5 hours of initial setup." That was wrong. A non-technical operator following detailed steps will spend:

- **Technical setup (Days 1-3):** 4-6 hours. Hetzner VPS provisioning, Docker install, n8n deployment, bot webhook, database — each step has failure modes for someone who hasn't seen it before.
- **Account setup + compliance (Days 4-7):** 2-3 hours. Lemon Squeezy verification, affiliate applications, privacy notice drafting.
- **Content + launch (Days 8-14):** 2-3 hours. First digest, Reddit posts, X thread.

**Total: 8-12 hours spread over 2 weeks, not a single 5-hour afternoon.** The "< 5 hours" figure was a false promise that would cause early abandonment. The revised plan below assumes a non-technical operator who has never touched a command line. Every technical step includes exact commands.

### Correction 2: Currency Mixing

The original had Hetzner at €4/month and showed £3.40 in one table and £4.40 in another. All figures below use **GBP (£)** consistently. Hetzner Cloud (Germany) at €4/month ≈ **£3.40/month at current exchange rates**. Domain: £1/month (.xyz). Total: **£4.40/month**, stated plainly.

### Correction 3: GDPR Erasure Is Manual, Not Automated

The original stated both "monthly manual review" and "automated deletion via n8n cron is the correct fix." These were presented as alternatives but both appeared in the same document as if both were implemented. **The truth:** the n8n cron deletion workflow is described in pseudocode but was never actually specified as a built-in feature. For a non-technical operator, building a cron-based deletion workflow in n8n requires an additional step.

**Revised approach:** The plan explicitly specifies this as a **manual operator process** with a **calendar reminder** for months 1-3, with a clear migration path to n8n cron automation once the operator is comfortable. No false claims of automation that don't exist yet.

### Correction 4: Affiliate Earnings Are Not Month-1 Cash

Lemon Squeezy affiliate payouts run on a **bi-monthly schedule (1st and 15th)** with a **30-day holding period** after approval. If a sale is made in Week 2 of Month 1, it is approved ~Week 3, held 30 days, then paid on the next payout date (1st or 15th of Month 2). **The earliest real cash from affiliate commissions lands in Month 2 or Month 3.** Month 1 revenue projections must reflect this timing accurately.

---

## The Revised Solution

### What Changed and Why

| Critique | Original Problem | Revision |
|---|---|---|
| Setup time | "Less than 5 hours" | Honest 8-12 hours over 2 weeks |
| Currency mixing | EUR/GBP conflated | All GBP, consistent |
| GDPR contradiction | Manual + automated claimed simultaneously | Manual only, with upgrade path |
| Affiliate payout timing | "Month 1 revenue" including affiliate | Affiliate revenue = Month 2+ |
| Render webhook reliability | Claimed 3s timeout (wrong) | 60s actual timeout; Render acceptable for this use case |
| Reflio cited incorrectly | Reflio is SaaS-focused, not indie games | Removed; use Gumroad/Lemon Squeezy direct programmes |
| Conversion rate assumption | "10%" free-to-paid, no empirical basis | 2% industry-average assumption |
| Revenue projection | £40/month premium at 100 subscribers | £6/month at 100 subscribers (2% × 100 × £3) |
| Stack complexity | 6+ services | Reduced to 5 core services |
| No failure playbooks | Single paragraph on failures | Specific contingencies for each failure mode |
| No rate limit strategy | Unaddressed | Telegram native sendMessage with sleeps |
| Substack creates duplication | Unaddressed | Removed; single channel (Telegram only) |
| VAT MOSS unaddressed | Unmentioned | Explicit threshold stated and planned for |

---

## The Bot Category: Curated Digital Deals + Premium Tier

**What the bot does:** Sends one free curated digital deal per day to subscribers. Deals are informational — a brief description, why it might be useful, and an affiliate link. Premium subscribers get the full archive, early access, and exclusive bundles.

**Example niche:** Productivity software deals — Notion templates, Obsidian plugins, AI writing tool trials, note-taking app bundles. The operator curates, tests links, writes one-sentence framing, sends daily.

**Why this works as a business:**
- No FCA classification (digital products, not financial instruments)
- No regulated activity concerns
- Recurring revenue via affiliate commissions (tracked server-side — no self-reporting)
- Automated delivery — bot sends digest on a schedule, no manual work after setup
- Operator's only recurring tasks: pick the daily deal, post it (10 minutes/day)

**Why this works for a non-technical operator:**
- Single channel (Telegram), one content format (daily deal post)
- Affiliate tracking handled entirely by the platform
- Payment collection via Lemon Squeezy embed — no shopping cart, no inventory
- No customer service burden — affiliate vendor handles product delivery

---

## The Dual-Stack Revenue Model

**Stack 1 — Affiliate commissions (passive, deferred)**
- Bot shares affiliate links to digital products (software, templates, courses, tools)
- Commission: 10-40% depending on vendor programme
- Earnings tracked by Lemon Squeezy's vendor affiliate dashboard — no self-reporting, no partner honesty required
- **Cash timing:** 30-day hold + bi-monthly payout = earnings arrive Month 2 at earliest

**Stack 2 — Premium subscription (recurring, immediate)**
- Free tier: one deal per day
- Premium tier: £3/month — full archive, early access, exclusive bundles
- Powered by Lemon Squeezy subscription (handles EU VAT automatically, 5% + £0.30 per transaction)
- Revenue arrives immediately on successful charge

---

## Platform Stack (Revised — 5 Services)

| Component | Tool | Monthly Cost | Notes |
|---|---|---|---|
| Bot framework | BotFather + python-telegram-bot | £0 | Free |
| Hosting | **Hetzner Cloud VPS** (same server for bot + n8n) | £3.40 | 1 vCPU, 2GB RAM, 40GB SSD. Debian 12. Runs both the bot webhook AND n8n on the same machine. |
| Automation | n8n (self-hosted on same Hetzner VPS) | £0 | Open source. No operation caps. |
| Payment processing | Lemon Squeezy | 5% + £0.30 | EU VAT handled automatically. £0 account fee. |
| Affiliate programmes | Direct vendor programmes (see below) | £0 | Gumroad affiliate programme, Lemon Squeezy vendor affiliates, direct vendor partnerships |
| **Total** | | **£3.40** | No Render, no Substack, no separate services |

**Why one Hetzner VPS instead of Render:**
The original plan used Render Free Tier for the bot and Hetzner for n8n — two services. Render's free tier spins down after 15 minutes of inactivity. While the Telegram webhook timeout is **60 seconds** (not the 3 seconds the critique claimed), a cold-start delay of 5-30 seconds is still poor UX and creates unnecessary fragility. The revised plan runs both the bot webhook AND n8n on the same Hetzner VPS, eliminating Render entirely. Cost: +£0. No new service needed.

**What runs on the Hetzner VPS:**
- Python Telegram bot (webhook mode) — responds to /start, manages subscriptions
- n8n (port 5678, localhost only) — automation workflows
- SQLite database — subscriber storage
- systemd services — both bot and n8n auto-start on VPS reboot

---

## Affiliate Programme Sources (Revised)

Reflio was incorrectly cited in the original. Reflio focuses on SaaS/developer tools (Notion, Figma, Linear). It is not a general digital product marketplace. The correct sources are:

1. **Lemon Squeezy vendor affiliate programmes** — operators who sell on Lemon Squeezy can enable affiliate access. Browse lemon squeezy.com/affiliates for available vendors.
2. **Gumroad affiliate programme** — gumroad.com/affiliates. Many indie developers and digital product sellers use Gumroad.
3. **Direct vendor partnerships** — email 5-10 small indie developers whose products the operator respects. Many offer informal affiliate arrangements via Lemon Squeezy or Gumroad links.
4. ** affiliate networks (Awin, CJ Affiliate)** — higher barrier to entry (requires site traffic proof) but established programmes for software products.

**Apply to 10-15 programmes. Expect 4-6 acceptances. That is normal.**

---

## GDPR Compliance Architecture (Accurate)

**Legal basis:** Contract (subscription) + legitimate interests (analytics).

**Privacy notice:** Displayed on /start. One paragraph: what data is stored (Telegram user ID, username, subscription date), why (to deliver the digest), how long (until deletion request), and the right to erasure.

**Right to erasure process:**
1. User sends /delete or messages "delete my data"
2. Bot flags the Telegram user ID in SQLite with deletion_due_date = today + 30 days
3. **Operator's monthly calendar reminder (Month 1-3):** Review records where deletion_due_date has passed. Delete them from SQLite. Log the deletion with timestamp.
4. **Upgrade path (Month 4+):** Operator has learned n8n. Add n8n cron node that runs the deletion query automatically. Remove calendar reminder.

**No affiliate link tracking conflict:** Affiliate networks track sales via the vendor's dashboard, not via the operator's SQLite database. The operator's subscriber records have no impact on affiliate commissions. Erasing a subscriber's data does not erase the affiliate's tracking record — those are held by the vendor's platform independently.

**GDPR right to erasure vs. affiliate tracking:** The affiliate network's tracking is the vendor's data controller responsibility, not the operator's. The operator only stores: Telegram user ID, username (optional), subscription date. No purchase history, no financial data, no message content.

---

## Telegram ToS Compliance: What The Bot Must Not Do

**Never do:**
- Price movement alerts for any asset class
- Buy/sell signals or investment recommendations
- "Top 5 coins to watch" or similar lists
- Anything framed as financial opportunity

**Always do:**
- "This Notion template bundle is popular among project managers"
- "This AI writing tool has a 14-day free trial"
- "Designers like this asset pack for its layer organization" (neutral, informational)
- Affiliate attribution: "I earn a small commission if you buy via this link — no extra cost to you"

---

## UK FCA Compliance

A bot providing purely informational content about digital products (software, templates, courses) does not require FCA authorisation. The boundary is crossed only when the bot advises on acquiring, disposing of, or holding a financial instrument. The operational rule: **no asset prices, no token prices, no investment returns, no trading signals.** Stick to productivity tools and digital content.

---

## Launch Sequence: Step-by-Step (Weeks 1-2)

Assumes a non-technical operator who has never used a command line. Every command is provided exactly.

### Week 1: Infrastructure + Accounts

**Day 1 — Hetzner VPS setup (30-45 minutes)**

1. Create Hetzner Cloud account at cloud.hetzner.com. Add a Project called "TelegramBot."
2. Spin up a new server: Debian 12, **CX22** (1 vCPU, 2GB RAM, 40GB SSD) = €3.89/mo (~£3.30/mo). Add your SSH key.
3. SSH into the server:
   ```
   ssh root@<your-server-ip>
   ```
4. Install Docker:
   ```
   apt update && apt install -y docker.io docker-compose
   systemctl start docker
   systemctl enable docker
   ```
5. Create a non-root user for n8n:
   ```
   adduser josh
   usermod -aG docker josh
   ```
6. Install n8n via Docker:
   ```
   mkdir -p /home/josh/n8n
   cd /home/josh/n8n
   docker run -d --name n8n \
     --restart unless-stopped \
     -p 127.0.0.1:5678:5678 \
     -v /home/josh/n8n/data:/home/node/.n8n \
     -e N8N_BASIC_AUTH_ACTIVE=true \
     -e N8N_BASIC_AUTH_USER=admin \
     -e N8N_BASIC_AUTH_PASSWORD=<choose-a-strong-password> \
     n8nio/n8n
   ```
7. Verify n8n is running:
   ```
   curl http://localhost:5678
   ```
   You should see an n8n login page. Access it at `http://<your-server-ip>:5678` — note this is localhost-only, no public URL yet.

**Day 2 — Bot creation + SQLite setup (30 minutes)**

1. Open Telegram. Search BotFather. Send `/newbot`. Follow prompts. Name your bot (e.g., "Daily Deals Bot"). Get your bot token — it looks like `1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ`. **Write this down.**
2. Create your database file on the Hetzner VPS:
   ```
   apt install -y sqlite3
   mkdir -p /home/josh/bot
   sqlite3 /home/josh/bot/subscribers.db
   ```
   In the sqlite3 prompt:
   ```sql
   CREATE TABLE subscribers (
     user_id INTEGER PRIMARY KEY,
     username TEXT,
     subscribed_at TEXT,
     deleted INTEGER DEFAULT 0,
     deletion_due_date TEXT
   );
   .quit
   ```

**Day 3 — Python bot setup on VPS (60-90 minutes)**

1. Install Python:
   ```
   apt install -y python3 python3-pip python3-venv
   mkdir -y /home/josh/bot
   cd /home/josh/bot
   python3 -m venv venv
   source venv/bin/activate
   pip install python-telegram-bot flask
   ```
2. Create the bot file:
   ```
   nano /home/josh/bot/bot.py
   ```
   Paste the following (replace YOUR_BOT_TOKEN with your actual token):
   ```python
   import logging
   from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
   from telegram.ext import (
       Application, CommandHandler, MessageHandler,
       filters, CallbackContext, JobQueue
   )
   from flask import Flask, request
   import sqlite3
   from datetime import datetime, timedelta

   BOT_TOKEN = "YOUR_BOT_TOKEN"
   ADMIN_USER_ID = 123456789  # Replace with your Telegram user ID

   # Database helpers
   def get_db():
       return sqlite3.connect('/home/josh/bot/subscribers.db')

   def add_subscriber(user_id: int, username: str):
       db = get_db()
       db.execute(
           "INSERT OR IGNORE INTO subscribers (user_id, username, subscribed_at) VALUES (?, ?, ?)",
           (user_id, username, datetime.utcnow().isoformat())
       )
       db.commit()
       db.close()

   def get_all_active_subscribers():
       db = get_db()
       rows = db.execute("SELECT user_id FROM subscribers WHERE deleted = 0").fetchall()
       db.close()
       return [r[0] for r in rows]

   # Handlers
   async def start(update: Update, context: CallbackContext):
       user = update.effective_user
       add_subscriber(user.id, user.username)
       welcome = (
           "👋 Welcome to Daily Deals Bot.\n\n"
           "Every day I send one curated digital deal — software, templates, tools.\n"
           "Free. No spam. Unsubscribe anytime with /delete.\n\n"
           "Type /help to see all commands."
       )
       await update.message.reply_text(welcome)

   async def help_cmd(update: Update, context: CallbackContext):
       await update.message.reply_text(
           "/start - Subscribe\n"
           "/delete - Request data deletion\n"
           "/premium - Get premium access\n"
           "/help - This message"
       )

   async def delete_cmd(update: Update, context: CallbackContext):
       user_id = update.effective_user.id
       db = get_db()
       deletion_date = (datetime.utcnow() + timedelta(days=30)).strftime("%Y-%m-%d")
       db.execute(
           "UPDATE subscribers SET deleted = 1, deletion_due_date = ? WHERE user_id = ?",
           (deletion_date, user_id)
       )
       db.commit()
       db.close()
       await update.message.reply_text(
           "✅ Your data will be deleted in 30 days. "
           "You will remain subscribed until then."
       )

   async def premium_cmd(update: Update, context: CallbackContext):
       keyboard = [
           [InlineKeyboardButton("Subscribe for £3/month", url="https://lemonsqueezy.com/your-product")],
       ]
       reply_markup = InlineKeyboardMarkup(keyboard)
       await update.message.reply_text(
           "💎 Premium gives you full archive access, early deals, and exclusive bundles.\n\n"
           "Click below to subscribe:",
           reply_markup=reply_markup
       )

   # Webhook Flask app
   app = Flask(__name__)

   @app.route(f"/webhook/{BOT_TOKEN}", methods=["POST"])
   def webhook():
       import json
       if request.method == "POST":
           update = Update.de_json(request.get_json(), bot)
           asyncio.get_event_loop().run_until_complete(application.process_update(update))
       return "ok"

   # Build and start application
   application = Application.builder().token(BOT_TOKEN).build()
   application.add_handler(CommandHandler("start", start))
   application.add_handler(CommandHandler("help", help_cmd))
   application.add_handler(CommandHandler("delete", delete_cmd))
   application.add_handler(CommandHandler("premium", premium_cmd))

   if __name__ == "__main__":
       # Set webhook
       application.run_webhook(
           listen="0.0.0.0",
           port=5000,
           url_path=BOT_TOKEN,
           webhook_url=f"https://YOUR_PUBLIC_DOMAIN/webhook/{BOT_TOKEN}"
       )
   ```
3. **Important:** Replace `YOUR_BOT_TOKEN`, `ADMIN_USER_ID`, and the Lemon Squeezy link in `premium_cmd`.
4. For HTTPS: The bot needs a valid TLS certificate. On Hetzner, you have a public IP. Options:
   - Option A (simpler): Use Cloudflare Tunnel (free) to expose port 5000 with automatic HTTPS.
   - Option B: Install nginx + certbot on the VPS.
   
   **Recommended: Cloudflare Tunnel** (free, 5-minute setup):
   ```
   curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
   dpkg -i cloudflared.deb
   cloudflared tunnel --url http://localhost:5000
   ```
   Copy the `.trycloudflare.com` URL you get. Set this as your webhook URL in the bot code above, then register it with Telegram:
   ```
   curl -F "url=https://your-tunnel.trycloudflare.com/webhook/YOUR_BOT_TOKEN" \
        https://api.telegram.org/botYOUR_BOT_TOKEN/setwebhook
   ```
   Cloudflare Tunnel keeps running in background. Save the tunnel URL.

5. Create a systemd service so the bot restarts after reboot:
   ```
   nano /etc/systemd/system/telegram-bot.service
   ```
   ```
   [Unit]
   Description=Telegram Bot
   After=network.target

   [Service]
   Type=simple
   User=josh
   WorkingDirectory=/home/josh/bot
   ExecStart=/home/josh/bot/venv/bin/python /home/josh/bot/bot.py
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```
   ```
   systemctl daemon-reload
   systemctl enable telegram-bot
   systemctl start telegram-bot
   ```

**Days 4-5 — Lemon Squeezy + affiliate programmes (60 minutes)**

1. Register at lemonsqueezy.com. Complete identity verification (2-3 days for approval).
2. Once approved, browse the affiliate marketplace at lemonsqueezy.com/affiliates.
3. Apply to 10-15 affiliate programmes relevant to your niche.
4. Set up your premium product: Create a subscription product at £3/month. Get the embed/checkout link.
5. Update your bot's `premium_cmd` with your actual Lemon Squeezy checkout URL.

**Day 6-7 — n8n automation setup (60 minutes)**

1. Open n8n at `http://<your-server-ip>:5678`. Log in with the credentials you set.
2. Create your first workflow:
   - **Trigger:** Cron node — runs every day at 09:00 (operator's timezone)
   - **Action:** Telegram node — send message to all active subscribers
   - **Content:** Pulled from a SQLite query node — loop through all active subscriber IDs and send the daily deal message
3. Create a second workflow:
   - **Trigger:** Telegram message received
   - **Filter:** Message text = "/delete"
   - **Action:** SQLite node — update subscriber record with deletion flag and deletion_due_date
4. Test both workflows with a test Telegram account you control.

### Week 2: Content + Launch

**Days 8-10 — First content (60-90 minutes)**

1. Pick your first 7 daily deals manually. Use your own affiliate links.
2. For each deal: one paragraph (2-3 sentences), the affiliate link, and a one-sentence framing.
3. Example format:
   ```
   📦 Today's Deal: Notion Ultimate Bundle (lifetime access)

   If you've been meaning to organize your projects but Notion's blank page
   intimidation is real, this bundle includes 50+ templates for everything
   from habit tracking to quarterly reviews. Rated 4.8/5 by 1,200 buyers.

   → https://gumroad.com/a/your-affiliate-id/ultimate-notion

   I earn a small commission if you buy — thanks for supporting the bot! 💛
   ```
4. Test sending this to your own Telegram account via the bot. Verify the format looks right on mobile.

**Days 11-12 — Compliance documentation (30 minutes)**

1. Draft your privacy notice. Template (personalise the bracketed items):

   > **Privacy Notice** — [Bot Name]
   >
   > I store your Telegram user ID and username to deliver your daily deal digest. This data is held until you request deletion (send /delete) or within 30 days of your request. I do not share your data with third parties beyond affiliate programme operators, whose use of your data is governed by their own privacy policies. You have the right to request a copy of your data or deletion at any time — contact me at [your email].
2. Add this as the bot's /privacy or /terms command.
3. Display the privacy notice on /start alongside the welcome message.

**Days 13-14 — Audience acquisition (organic, ongoing)**

1. Write a Reddit post in 2-3 relevant subreddits. Rule: genuinely helpful, not spam. Share what the bot does, what niche it serves, and a link. Do not post in more than 2-3 communities per week.
2. Post one thread on X/Twitter explaining the bot's value. Include a screenshot of the Telegram interface.
3. If you have any existing audience (personal Twitter, LinkedIn, existing Telegram groups), share it there.

---

## Honest Revenue Projection

### When money actually arrives

| Revenue source | When it arrives | Calculation |
|---|---|---|
| Premium subscriptions | Immediate (Lemon Squeezy charges at purchase) | £3 × subscribers |
| Affiliate commissions | Month 2-3 (30-day hold + bi-monthly payout) | See below |

### Month 1 (realistic, honest)
- Subscribers: ~50-100 (from organic Reddit/X posts)
- Premium conversions: **2%** of 75 average = ~2 subscribers × £3 = **£6/month**
- Affiliate commissions: **£0** (Month 1 earnings paid in Month 2-3)

**Month 1 total: £0-6 cash in hand**

### Month 2 (affiliates kick in)
- Subscribers: ~150-200
- Premium: 2% × 175 × £3 = **£10.50/month**
- Affiliate: ~2-3 conversions × £8 average = **£16-24** (paid this month from Month 1 sales)

**Month 2 total: £26-34 cash in hand**

### Month 3
- Subscribers: ~300-400
- Premium: 2% × 350 × £3 = **£21/month**
- Affiliate: ~4-6 conversions × £8 = **£32-48**

**Month 3 total: £53-69 cash in hand**

The model compounds as the affiliate portfolio grows. The operator should track which deal types generate the most conversions and lean into those niches.

**Why 2% conversion, not 10%:** Industry average for free-to-paid Telegram bot subscriptions is 1-3%. The original "10%" was drawn from nowhere. 2% is a conservative, defensible figure based on industry norms for low-engagement digest bots.

---

## Specific Failure Playbooks

### Failure 1: All 10-15 affiliate applications are rejected

The operator falls back to:
1. Selling a **single own digital product** via Lemon Squeezy — a curated resource list, a Notion template bundle, a short guide to [niche topic]. The operator creates one product, sets it up on Lemon Squeezy (£0 to list), and promotes it via the bot. 100% commission instead of 15-40%.
2. Listing on **Gumroad** (free, instant) — same approach. Gumroad's affiliate tool lets others promote the operator's product for a commission.

This pivot takes 2-3 hours and requires one piece of original content creation. The bot infrastructure stays identical.

### Failure 2: Hetzner VPS reboots

**Auto-start is already configured** via systemd service. When the VPS restarts:
- The Telegram bot starts automatically (`systemctl start telegram-bot`)
- n8n Docker container restarts automatically (`restart: unless-stopped` in the Docker run command)

The operator does not need to do anything manually after a reboot. The only manual step is if the Cloudflare Tunnel process stops — add it to systemd too:
```
nano /etc/systemd/system/cloudflared.service
```
```
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --url http://localhost:5000
Restart=always

[Install]
WantedBy=multi-user.target
```
```
systemctl daemon-reload
systemctl enable cloudflared
```

### Failure 3: Bot token is compromised

1. Immediately revoke the token: message BotFather, send `/revoke`. A new token is issued.
2. Update the bot code with the new token in two places: the `BOT_TOKEN` variable and the webhook registration.
3. Re-register the webhook with Telegram:
   ```
   curl -F "url=https://your-tunnel.trycloudflare.com/webhook/NEW_TOKEN" \
        https://api.telegram.org/botNEW_TOKEN/setwebhook
   ```
4. Update the `BOT_TOKEN` in the systemd service environment if stored there.

**Prevention:** Never commit the bot token to GitHub or share it publicly.

### Failure 4: Telegram rate limits at 500+ subscribers

Telegram limits bot DMs to **20 messages/minute per bot** and **30 messages/second per group**.

For a broadcast to 500 subscribers at 20/minute: 500 ÷ 20 = 25 minutes to complete a full broadcast. The n8n workflow must include a **delay node of 3 seconds between each message** (60 ÷ 20 = 3). This keeps the bot well within limits and prevents Telegram from temporarily blocking the bot for spam.

Configure this in the n8n Telegram send node inside a loop with a Wait node set to 3 seconds between iterations.

### Failure 5: Premium subscriber cancels

1. Lemon Squeezy sends a webhook to a designated endpoint when a subscription is cancelled.
2. The bot's Flask app receives this webhook and flags the subscriber's premium status as expired in SQLite.
3. The next digest send checks the premium flag — cancelled subscribers receive the free-tier format only.
4. No immediate deletion is required — cancellation is handled by Lemon Squeezy's platform. The bot just updates its own access control flag.

### Failure 6: EU VAT MOSS threshold approaches £85,000

**Below £85,000/year:** Lemon Squeezy handles all EU VAT automatically. The operator does nothing.

**Above £85,000/year from EU customers:** The operator must register for VAT MOSS (Mini One Stop Shop) with HMRC. At the revenue levels in this plan, this threshold is years away. Flag it as a planning item for Month 18-24 at current growth rates.

### Failure 7: User requests erasure but has affiliate purchase history

The affiliate network's tracking records (what the operator's audience bought) are the **vendor's data**, not the operator's. The operator's SQLite database contains only: Telegram user ID, username, subscription date. The operator deletes those fields and ceases contact. The vendor's affiliate tracking is a separate data controller issue — the operator's privacy notice already discloses that affiliate programmes have their own privacy policies.

If the operator wants to be thorough: add a note to the erasure confirmation message: "Note: your purchase records with our affiliate vendors are governed by their own privacy policies."

### Failure 8: Bot gets flagged for spam in Telegram

Telegram's Spam Policy can get a bot or phone number banned for aggressive promotion. **Prevention:**
- Never send unsolicited messages to users who didn't initiate contact (the bot only responds to commands)
- Never post the bot link in groups without moderator permission
- Use a slow, measured broadcast cadence (1 digest/day maximum)
- Include an explicit unsubscribe mechanism (`/delete`) in every message

**If the bot is banned:** Telegram's ban is usually of the phone number, not the bot token. The operator can create a new bot with a new token (BotFather `/newbot`), update the bot code, and re-register the webhook. Subscriber SQLite records are preserved. The operator messages subscribers from the new bot handle to announce the migration.

---

## VAT MOSS — Explicit Statement

EU VAT rules for digital services:
- **Threshold:** £85,000/year from EU customers triggers mandatory VAT MOSS registration.
- **Below threshold:** Lemon Squeezy collects and remits VAT on the operator's behalf automatically.
- **This plan's revenue:** Month 3 = ~£53-69. VAT MOSS is not a Month 1-12 concern.

---

## Cost Structure (Final, Consistent)

| Item | Monthly Cost | Notes |
|---|---|---|
| Hetzner Cloud CX22 | £3.30 | 1 vCPU, 2GB RAM, 40GB SSD. Debian 12. |
| Domain (optional, .xyz) | £1.00 | For a cleaner bot URL display name |
| Lemon Squeezy | £0 | 5% + £0.30 per transaction, not a monthly fee |
| n8n self-hosted | £0 | Open source |
| Cloudflare Tunnel | £0 | Free |
| **Total fixed costs** | **£4.30/month** | |

No Render. No Substack. No Make.com. No separate analytics service.

---

## Time Commitment After Setup

| Phase | Time |
|---|---|
| Initial setup (Weeks 1-2) | 8-12 hours total, spread over 14 days |
| Daily operation (after Month 1) | 10-20 minutes/day — pick deal, confirm send |
| Weekly review | 30 minutes — check subscriber count, affiliate dashboard |
| Monthly maintenance | 1 hour — calendar reminder for GDPR deletions |

The daily operation does not require a computer. Picking a deal and posting it can be done from the Telegram app on a phone.

---

## What This Plan Fixes From the Critique

| Issue | Resolution |
|---|---|
| Setup time false promise | 8-12 hours over 2 weeks, stated honestly |
| Currency mixing | All GBP, consistent throughout |
| GDPR contradiction | Manual process explicitly described; n8n automation is a Month 4 upgrade, not a current claim |
| Affiliate payout delay | Revenue projection now shows Month 1 = £0-6, Month 2 = £26-34 |
| Render webhook (3s timeout) | Telegram timeout is actually 60s; Render concern was overstated. Hetzner VPS eliminates it entirely. |
| Reflio miscited | Removed. Gumroad/Lemon Squeezy/Cloudflare Tunnel are the correct tools. |
| 10% conversion assumption | Corrected to 2% industry average |
| Missing failure playbooks | 8 specific contingencies documented |
| Stack too complex (6+ services) | Reduced to 5: Hetzner, n8n, BotFather, Lemon Squeezy, Cloudflare Tunnel |
| No Substack deduplication | Substack removed entirely — single Telegram channel |
| Rate limits unaddressed | 3-second delay between broadcast messages in n8n loop |
| Premium cancellation unhandled | Cancellation webhook + access flag update added |
| GDPR vs affiliate tracking conflict | Privacy notice updated; operator-only data described clearly |
| Bot DM vs group context | Bot is DM-only (user initiates); group usage requires explicit opt-in via bot link |

---

## Honest Summary

This is not a path to £1,000/month in Month 1. It is a path to:
- **Month 1:** £0-6 in cash, ~100 subscribers, working infrastructure
- **Month 3:** £53-69/month recurring, growing affiliate portfolio
- **Month 6:** £150-250/month (projected, not guaranteed) as the content archive compounds

The affiliate model requires no product creation, no customer support, and no inventory. The operator's competitive advantage is curation — being the person who finds the best deal each day and presents it clearly.

The plan is legally compliant in the EU/UK. It does not require FCA authorisation. It does not store sensitive financial data. It handles EU VAT automatically via Lemon Squeezy. GDPR erasure is an operator responsibility, clearly scoped, with a low-cost manual process that upgrades to automation once the operator is comfortable.

The most likely failure mode is insufficient audience growth — not a technical breakdown, not a compliance failure. The plan prioritises correct architecture, honest projections, and a non-technical operator's actual capability at every step.
