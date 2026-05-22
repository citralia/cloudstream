# Xtream Codes API Reference

> The Xtream Codes Player API is a third-party API owned by IPTV providers. CloudStream implements a client library for this API. This document is a reference for the client implementation.

**Base URL:** `http://{server_host}:{server_port}/`

**Note:** CloudStream communicates with the Xtream API directly from the Flutter app — there is no CloudStream backend involvement in Xtream API calls.

---

## Authentication

### Login

```
GET /player_api.php?username={username}&password={password}
```

**Response:**
```json
{
  "user_auth": {
    "auth_token": "abc123...",
    "exp_date": "1735689600",
    "status": "Active",
    "is_trial": "0",
    "active_cons": "1",
    "max_cons": "1"
  },
  "user_info": {
    "username": "john_doe",
    "password": "",
    "message": "",
    "auth": 1,
    "status": "Active",
    "exp_date": "1735689600",
    "trial": 0,
    "active_cons": 1,
    "created_at": "2024-01-01",
    "max_connections": 1,
    "allowed_output_formats": ["m3u8", "ts"]
  },
  "server_info": {
    "url": "http://server.example.com",
    "port": "8080",
    "https_port": "443",
    "server_protocol": "http",
    "rtmp_port": "25461",
    "timestamp": 1735689600
  }
}
```

**Error responses:**
```json
{ "user_auth": null, "user_info": { "auth": 0, "message": "Wrong username or password" } }
```

**CloudStream handling:**
- Store `auth_token` for constructing stream URLs
- Store `exp_date` — if expired, show subscription expired screen
- `max_connections` — enforce per-tier stream limits in-app

---

## Live TV

### Get Live Categories

```
GET /player_api.php?action=get_live_categories
```

**Response:**
```json
[
  { "category_id": "1", "category_name": "Sports", "parent_id": 0 },
  { "category_id": "2", "category_name": "News", "parent_id": 0 },
  { "category_id": "3", "category_name": "Entertainment", "parent_id": 0 },
  { "category_id": "4", "category_name": "Kids", "parent_id": 0 },
  { "category_id": "5", "category_name": "Movies", "parent_id": 0 },
  { "category_id": "6", "category_name": "UK Premium", "parent_id": 0 }
]
```

### Get Live Streams (all or by category)

```
GET /player_api.php?action=get_live_streams&category_id={category_id}
```

**Response:**
```json
[
  {
    "num": 1,
    "name": "BBC One",
    "logo": "https://server.example.com/images/bbc1.png",
    "logo_old": "https://server.example.com/images/bbc1.png",
    "category_id": "1",
    "category_ids": ["1", "6"],
    "stream_id": 101,
    "stream_type": "live",
    "stream_icon": "https://server.example.com/images/bbc1.png",
    "epg_channel": "bbc_one_hd",
    "added": "2024-01-01",
    "is_ads": 0,
    "direct_source": "",
    "tv_archive": 1,
    "tv_archive_duration": 48
  },
  {
    "num": 2,
    "name": "Sky Sports News",
    "logo": "https://server.example.com/images/ssn.png",
    "category_id": "1",
    "stream_id": 102,
    "stream_type": "live",
    "epg_channel": "sky_sports_news_hd",
    "tv_archive": 1,
    "tv_archive_duration": 48
  }
]
```

### Get Single Stream Info

```
GET /player_api.php?action=get_live_streams&stream_id={stream_id}
```

Returns full stream object (same shape as above, single item).

---

## Stream URLs

### Live Stream URL

```
http://{server}/live/{username}/{password}/{stream_id}.m3u8
```
or with auth token:
```
http://{server}/live/{auth_token}/{stream_id}.m3u8
```

**Note:** Some Xtream servers require the original username/password, not the auth token. The `auth_token` from login is only for session validation server-side.

### Catch-Up Stream URL

```
http://{server}/live/{username}/{password}/{stream_id}.m3u8?start={unix_timestamp}
```

The `start` parameter is the Unix timestamp of when the programme started. The stream will begin from that point.

### Timeshift URL

```
http://{server}/timeshift/{username}/{password}/{unix_timestamp}/{duration}/stream.m3u8
```

---

## Video on Demand (VOD)

### Get VOD Categories

```
GET /player_api.php?action=get_vod_categories
```

**Response:** Same structure as live categories.

### Get VOD Streams

```
GET /player_api.php?action=get_vod_streams&category_id={category_id}
```

**Response:**
```json
[
  {
    "num": 101,
    "name": "The Matrix",
    "logo": "https://server.example.com/images/matrix.jpg",
    "category_id": "10",
    "category_ids": ["10", "11"],
    "stream_id": 1001,
    "stream_type": "movie",
    "stream_icon": "https://server.example.com/images/matrix.jpg",
    "rating": "8.7",
    "plot": "A computer hacker...",
    "cast": "Keanu Reeves, Laurence Fishburne",
    "director": "The Wachowskis",
    "releaseDate": "1999",
    "duration": "8119",
    "added": "2024-01-01"
  }
]
```

### Get Single VOD Info

```
GET /player_api.php?action=get_vod_info&vod_id={stream_id}
```

Returns full VOD details including `custom_sid`, episode list (if series).

### VOD Stream URL

```
http://{server}/movie/{username}/{password}/{stream_id}.m3u8
```

---

## Series

### Get Series Categories

```
GET /player_api.php?action=get_series_categories
```

### Get Series

```
GET /player_api.php?action=get_series&series_id={series_id}
```

**Response:**
```json
{
  "info": {
    "seasons": [
      {
        "season_number": 1,
        "episodes": [
          {
            "episode_num": 1,
            "title": "Pilot",
            "description": "...",
            "duration": "2520",
            "stream_id": 5001
          }
        ]
      }
    ],
    "name": "Breaking Bad",
    "cover": "https://...",
    "plot": "...",
    "cast": "Bryan Cranston, Aaron Paul",
    "director": "Vince Gilligan",
    "genre": "Drama",
    "releaseDate": "2008",
    "rating": "9.5"
  }
}
```

### Series Episode Stream URL

```
http://{server}/series/{username}/{password}/{episode_stream_id}.m3u8
```

---

## EPG

### Get EPG for Channel

```
GET /player_api.php?action=get_epg&stream_id={stream_id}
```

**Response:**
```json
{
  "epg_listings": [
    {
      "id": "12345",
      "channel_id": "bbc_one_hd",
      "start": "1735689600",
      "end": "1735693200",
      "title": "BBC News",
      "description": "Latest news...",
      "category": "News",
      "icon": "https://..."
    }
  ]
}
```

### Alternative: XMLTV Endpoint

Some Xtream servers expose an XMLTV file directly:

```
GET /xmltv.php?username={user}&password={pass}
```

Returns XMLTV-formatted EPG data. CloudStream's EPG parser handles both the JSON API and XMLTV formats.

---

## Error Codes

| Code | Meaning |
|------|---------|
| `user_auth` = null | Invalid credentials |
| `status` != "Active" | Account not active |
| `exp_date` in past | Subscription expired |
| `active_cons` >= `max_cons` | Max connections reached |

---

## CloudStream Client Implementation

The Dart client is at `packages/cloudstream_api/lib/xtream/`.

```dart
class XtreamApiClient {
  Future<XtreamLoginResponse> login(String server, String username, String password);
  Future<List<XtreamCategory>> getLiveCategories();
  Future<List<XtreamChannel>> getLiveStreams({int? categoryId});
  Future<XtreamVod> getVodInfo(int vodId);
  Future<List<XtreamSeries>> getSeries(int seriesId);
  String buildLiveStreamUrl(String username, String password, int streamId);
  String buildCatchupUrl(String username, String password, int streamId, DateTime start);
}
```

---

*Note: Xtream Codes API is third-party. CloudStream does not control this API — it changes between Xtream server versions. The client handles the most common API variations.*
