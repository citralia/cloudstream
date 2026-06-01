# CloudStream Backend — API Gateway

FastAPI-based IPTV proxy service. Sits between the Flutter app and the Xtream server.

## Purpose
- Authenticates Xtream credentials and caches session
- Proxies channel list, categories, EPG
- Forwards/proxies stream requests (avoids CORS, handles auth tokens)
- Provides a clean REST/JSON API for the Flutter app

## Tech stack
- FastAPI (Python 3.11+)
- httpx (async HTTP client for Xtream)
- SQLite (session + EPG cache)
- uvicorn (ASGI server)
- Docker + Docker Compose

## Local development

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `XTREAM_BASE_URL` | Yes | Base URL of Xtream server (e.g. `http://123.45.67.89:8080`) |
| `XTREAM_USERNAME` | Yes | Xtream account username |
| `XTREAM_PASSWORD` | Yes | Xtream account password |
| `DATABASE_URL` | No | SQLite path (default: `./data/cloudstream.db`) |
| `PORT` | No | Server port (default: `8000`) |
| `CORS_ORIGINS` | No | Comma-separated allowed origins |

## API endpoints

### Auth
```
POST /api/auth/login
  Body: { "server_url": "...", "username": "...", "password": "..." }
  Response: { "token": "...", "user": {...}, "active": bool }

POST /api/auth/logout
  Headers: Authorization: Bearer <token>
```

### Channels
```
GET /api/channels
  Headers: Authorization: Bearer <token>
  Query: ?category_id=<int> (optional)
  Response: { "channels": [...], "total": int }

GET /api/channels/{id}
  Headers: Authorization: Bearer <token>
  Response: { "id", "name", "logo", "category_id", "stream_url" }
```

### Categories
```
GET /api/categories
  Headers: Authorization: Bearer <token>
  Response: { "live": [...], "vod": [...], "series": [...] }
```

### EPG
```
GET /api/epg
  Headers: Authorization: Bearer <token>
  Query: ?channel_id=<int>&hours=<int> (optional, default 24h)
  Response: { "channels": [{ "id", "name", "logo", "programmes": [...] }] }

GET /api/epg/refresh
  Headers: Authorization: Bearer <token>
  Response: { "status": "ok", "programmes_cached": int }
```

### Stream
```
GET /api/stream/{channel_id}
  Headers: Authorization: Bearer <token>
  Response: redirect to m3u8 stream URL

GET /api/stream/{channel_id}/manifest
  Headers: Authorization: Bearer <token>
  Response: manifest URL (for video player)
```

### Health
```
GET /health
  Response: { "status": "ok", "timestamp": "..." }
```

## Architecture

```
app/
├── main.py              # FastAPI app entry point
├── config.py            # Settings from env
├── database.py          # SQLite connection + models
├── app/
│   ├── __init__.py
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── auth.py      # /api/auth/*
│   │   ├── channels.py  # /api/channels/*
│   │   ├── categories.py # /api/categories/*
│   │   ├── epg.py       # /api/epg/*
│   │   └── stream.py    # /api/stream/*
│   ├── services/
│   │   ├── __init__.py
│   │   ├── xtream.py    # Xtream API client
│   │   ├── epg.py       # EPG fetch + parse
│   │   └── cache.py     # Response caching
│   └── models/
│       ├── __init__.py
│       └── schemas.py   # Pydantic models
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
└── README.md
```

## Response shapes

### Channel
```json
{
  "id": 12345,
  "name": "BBC One",
  "logo": "https://example.com/logos/bbc1.png",
  "category_id": 1,
  "category_name": "UK",
  "stream_url": "/api/stream/12345",
  "is_recording": false
}
```

### EPG Programme
```json
{
  "id": "ch123_20260601_1900",
  "channel_id": 12345,
  "title": "The Six O'Clock News",
  "description": "Daily news programme...",
  "start": "2026-06-01T18:00:00Z",
  "end": "2026-06-01T18:30:00Z",
  "category": "News",
  "is_catchup": true
}
```

### User Info
```json
{
  "id": "usr_123",
  "username": "john_smith",
  "status": "Active",
  "expiry": "2027-01-01T00:00:00Z",
  "is_trial": false,
  "max_connections": 1,
  "allowed_output_formats": ["m3u8", "ts"]
}
```
