# User Guide — Connecting Your IPTV Service

> How to add your IPTV service to CloudStream.

---

## Supported Connection Types

CloudStream supports three ways to connect your IPTV service:

| Type | Best For |
|------|---------|
| Xtream Codes (server login) | Most IPTV providers (resellers, premium services) |
| M3U Playlist URL | Custom playlists, some older services |
| QR Code | Quickly importing from another device |

---

## Method 1 — Xtream Codes (Recommended)

Most IPTV providers use Xtream Codes. You'll receive these details from your provider.

**What you need:**
- Server URL (e.g., `https://my-iptv-provider.com` or `http://server.example.com:8080`)
- Username
- Password

**Steps:**

1. Open CloudStream → Settings → Connections → Add Connection
2. Select **Xtream Codes**
3. Enter your Server URL (include `http://` or `https://` — the port if non-standard)
4. Enter your Username
5. Enter your Password
6. Tap **Connect**

CloudStream will automatically:
- Verify your credentials
- Fetch your channel list
- Fetch the programme guide (if your provider supports it)
- Store your credentials securely

**That's it — you should be watching within 60 seconds.**

---

## Method 2 — M3U Playlist URL

If your provider gives you a `.m3u8` or `.m3u` URL:

1. Settings → Connections → Add Connection → **M3U Playlist**
2. Paste the URL into the field
3. Tap **Import**

CloudStream will parse the playlist and show your channels.

**M3U playlists don't include programme information by default.** You'll need to set up an EPG source separately (Settings → Guide → EPG Source).

---

## Method 3 — QR Code (Quick Import)

If you already have CloudStream set up on another device:

**On your existing device:**
1. Settings → Connections → [your connection] → Export QR Code
2. The QR code is shown on screen

**On your new device:**
1. Settings → Connections → Add Connection → **Scan QR Code**
2. Point your camera at the QR code
3. Your connection is imported — no need to re-enter credentials

---

## Setting Up the Programme Guide (EPG)

The programme guide (EPG) shows what's on now and next for each channel. After connecting your service:

1. Go to **Settings → Guide → EPG Source**
2. Choose:
   - **Auto** (default) — uses your provider's built-in EPG if available
   - **XMLTV URL** — enter a custom XMLTV URL (your provider may supply one)
   - **Manual** — no EPG, you'll see channel numbers only

The guide data downloads in the background. It may take a few minutes to populate on first setup.

---

## Managing Multiple Connections

CloudStream supports up to 5 connections per profile:

- **Settings → Connections** to add, edit, or remove connections
- Tap a connection to set it as Active (used for guide + channel list)
- Inactive connections are paused but not deleted

---

## Troubleshooting

### "Connection failed — check your details"

- Double-check your server URL (no trailing slash)
- Ensure your subscription is active
- Try the server URL in a browser — do you see an Xtream API response?
- Some providers block certain regions — try a VPN

### Channels load but no EPG

- Not all Xtream providers supply EPG data
- Try adding a custom XMLTV URL in Settings → Guide → EPG Source
- EPG may take up to 30 minutes to populate on first sync

### Stream fails to play

- Your IPTV subscription may have expired
- The stream URL may have changed — reconnect the service
- Check your internet speed (minimum 5 Mbps for HD, 15 Mbps for 4K)

### Wrong channel order

- Go to **Settings → Connections → [your connection] → Re-order channels**
- Drag channels to your preferred order
- Or: **Settings → Channels → Sort by** (category, alphabetical, most watched)
