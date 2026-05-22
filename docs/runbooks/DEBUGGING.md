# CloudStream Debugging Guide

> How to diagnose and fix specific issue categories.

---

## Debugging Principles

1. **Reproduce first** — confirm the issue exists before investigating
2. **Narrow the scope** — is it the player, the network, the data source?
3. **Check the basics** — network, auth, credentials, third-party status
4. **Use the right tool** — logs > print statements > guessing

---

## Video Player Issues

### Symptom: Stream fails to start (black screen, spinner)

**Check in order:**

1. **Is the stream URL valid?**
```bash
# Test the stream URL directly
curl -I "https://your-server.com/live/username/password/stream_id.m3u8"
```

2. **Is the stream accessible from your network?**
   - Try in a browser
   - Check if the server IP is blocked by your ISP or VPN

3. **Is the stream format supported?**
   - CloudStream supports: HLS (.m3u8)
   - Not supported: RTMP, MMS, direct MP4 (without HLS)
   - Check the stream URL — if it ends in `.m3u8` it's HLS

4. **Is it a credential/auth issue?**
   - Xtream stream URLs expire — reconnect the service to refresh
   - Check: Settings → Connections → [your connection] → reconnect

5. **Check Crashlytics** (Firebase Console → Crashlytics)
   - Any `EXC_BAD_ACCESS` or `AVPlayer` errors?
   - Look at the most recent crash before the stream failure

### Symptom: Channel switches slowly (> 2 seconds)

**Expected:** < 1 second channel switch

**Causes:**
1. Stream URL not cached — first switch is always slower
2. DNS lookup delay — consider adding DNS prefetch
3. ExoPlayer/AVPlayer buffer reset — keep 3 stream connections warm
4. Network latency — test with `ping your-server.com`

**How to measure:**
```dart
// In playback_state_provider.dart, log channel switch time
final stopwatch = Stopwatch()..start();
await player.open(streamUrl);
stopwatch.stop();
debugPrint('Channel switch took: ${stopwatch.elapsedMilliseconds}ms');
```

### Symptom: Video plays but no audio

1. Check device volume is up
2. Check stream codec — AC3 audio tracks may not be supported on all devices
3. Try headphones (some devices have separate headphone audio paths)
4. Check: Settings → Playback → Audio → "Stereo downmix" (toggle)

---

## EPG / Guide Issues

### Symptom: Guide shows "No programme data"

**Check:**
1. Does your Xtream provider supply EPG?
   - Go to Settings → Guide → Source → "Auto"
   - If still nothing, your provider may not supply EPG

2. Try adding XMLTV URL manually
   - Settings → Guide → EPG Source → XMLTV URL
   - Many IPTV providers publish a public XMLTV file — ask your provider

3. Is the app connected to the internet?
   - Guide requires internet on first load (then cached for offline)

4. Check EPG refresh setting
   - Settings → Guide → Refresh Interval → "On Launch" (minimum)

### Symptom: Guide shows wrong programme times

- EPG data comes from your Xtream provider — if times are wrong, the provider's data is wrong
- Try a different XMLTV source
- File a bug report with your IPTV provider

---

## Authentication Issues

### Symptom: "Sign in failed" with Firebase

1. **Check Firebase Auth is enabled:**
   - Firebase Console → Authentication → Sign-in method
   - Ensure Email/Password and/or Google are enabled

2. **Check the error code:**
   - `INVALID_EMAIL` — malformed email address
   - `USER_DISABLED` — account disabled in Firebase Console
   - `WEAK_PASSWORD` — password must be 6+ characters
   - `EMAIL_EXISTS` — already registered (try sign in instead)
   - `INVALID_CREDENTIALS` — wrong email or password

3. **Google Sign-In fails on iOS:**
   - iOS: Requires `REVERSED_CLIENT_ID` in `GoogleService-Info.plist`
   - Check: `ios/Runner/GoogleService-Info.plist` exists and is correct

### Symptom: Auth works on one device, not another

1. Check device time / timezone is correct (Firebase Auth validates timestamps)
2. Clear app data on the failing device
3. Check if the account was created with a different sign-in method (Google vs email)

---

## Connection / Server Issues

### Symptom: "Server unreachable" for all channels

1. **Check if your IPTV provider is down:**
   - Ask on IPTV community forums
   - Check provider's status page / Telegram channel

2. **Check if Cloudflare/CDN is the issue:**
   - Try connecting directly (bypass CDN) if your provider offers it
   - Check Cloudflare status: [dash.cloudflare.com](https://dash.cloudflare.com)

3. **Reconnect the service:**
   - Settings → Connections → [connection] → Edit → Re-enter credentials
   - If credentials expired, update them

### Symptom: Only some channels fail

1. Specific channel issue — likely the Xtream server's transcoding for that channel
2. Report to your IPTV provider
3. As a workaround: try refreshing the channel list (reconnect service)

---

## Performance Issues

### Symptom: App is slow / laggy

1. **Check device storage:**
   - iOS/Android: Settings → Storage — if near full, CloudStream will be slow
   - Clear app cache: Settings → About → Clear Cache

2. **Too many channels cached:**
   - If you have 10,000+ channels, EPG caching may be heavy
   - Settings → Guide → "Limit guide to favourites only" (workaround)

3. **Memory pressure:**
   - Run `flutter doctor` + check for memory leaks in dev tools
   - Profile with DevTools: `flutter run --observe`

### Symptom: Battery drain

1. Background audio / video is draining battery
   - Check: Settings → Playback → "Keep audio playing in background" (turn off if not needed)
2. EPG refresh is too frequent
   - Settings → Guide → Refresh Interval → "Every 12 hours" (minimum for battery)

---

## Getting Help

If you can't resolve an issue:

1. Check [Firebase status](https://status.firebase.google.com)
2. Check [Cloudflare status](https://www.cloudflarestatus.com)
3. Check [RevenueCat status](https://status.revenuecat.com)
4. Open a GitHub Issue with: platform, Flutter version, steps to reproduce, logs
