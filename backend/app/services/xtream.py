"""
Xtream API client.

Xtream Codes API is documented at:
http://yourserver:port/api/

Standard endpoints:
- /player_api.php?username=X&password=Y&action=login
- /player_api.php?username=X&password=Y&action=get_live_categories
- /player_api.php?username=X&password=Y&action=get_live_streams&category_id=N
- /player_api.php?username=X&password=Y&action=get_vod_categories
- /player_api.php?username=X&password=Y&action=get_vod_streams&category_id=N
- /live/{username}/{password}/{stream_id}.m3u8
"""

import httpx
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional
from urllib.parse import urljoin


class XtreamAuthError(Exception):
    pass


class XtreamAPIError(Exception):
    pass


class XtreamClient:
    """Async client for Xtream Codes API."""

    def __init__(self, server_url: str, username: str, password: str):
        self.server_url = server_url.rstrip("/")
        self.username = username
        self.password = password
        self._token: Optional[str] = None
        self._user_info: Optional[dict] = None
        self._client: Optional[httpx.AsyncClient] = None

    @property
    def client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self.server_url,
                timeout=30.0,
                follow_redirects=True,
            )
        return self._client

    def _build_url(self, path: str) -> str:
        return urljoin(self.server_url, path)

    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None

    async def login(self) -> dict:
        """
        Authenticate and return user info + session token.
        Caches token locally so subsequent calls don't re-auth unless needed.
        """
        url = self._build_url("/player_api.php")
        params = {
            "username": self.username,
            "password": self.password,
            "action": "login",
        }

        try:
            response = await self.client.get(str(url), params=params)
            response.raise_for_status()
            data = response.json()
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 401:
                raise XtreamAuthError("Invalid Xtream credentials")
            raise XtreamAPIError(f"Xtream API error: {e.response.status_code}")
        except httpx.RequestError as e:
            raise XtreamAPIError(f"Connection error: {e}")

        if data.get("auth") == 0:
            raise XtreamAuthError("Authentication failed — check credentials")

        user_info = data.get("user_info") or data
        self._user_info = user_info
        self._token = self._generate_token()
        return self._user_info

    def _generate_token(self) -> str:
        """Generate a stable session token for this login session."""
        raw = f"{self.username}:{self.password}:{datetime.utcnow().isoformat()}"
        return hashlib.sha256(raw.encode()).hexdigest()[:32]

    @property
    def token(self) -> str:
        if not self._token:
            raise XtreamAuthError("Not authenticated — call login() first")
        return self._token

    def get_stream_url(self, stream_id: int) -> str:
        """
        Build direct stream URL.
        Format: /live/{username}/{password}/{stream_id}.m3u8
        """
        return f"/live/{self.username}/{self.password}/{stream_id}.m3u8"

    async def get_live_categories(self) -> list[dict]:
        """Fetch all live TV categories."""
        params = {
            "username": self.username,
            "password": self.password,
            "action": "get_live_categories",
        }
        return await self._get(params)

    async def get_vod_categories(self) -> list[dict]:
        params = {
            "username": self.username,
            "password": self.password,
            "action": "get_vod_categories",
        }
        return await self._get(params)

    async def get_series_categories(self) -> list[dict]:
        params = {
            "username": self.username,
            "password": self.password,
            "action": "get_series_categories",
        }
        return await self._get(params)

    async def get_live_streams(self, category_id: Optional[int] = None) -> list[dict]:
        """Fetch live streams, optionally filtered by category."""
        params = {
            "username": self.username,
            "password": self.password,
            "action": "get_live_streams",
        }
        if category_id is not None:
            params["category_id"] = str(category_id)
        return await self._get(params)

    async def get_vod_streams(self, category_id: Optional[int] = None) -> list[dict]:
        params = {
            "username": self.username,
            "password": self.password,
            "action": "get_vod_streams",
        }
        if category_id is not None:
            params["category_id"] = str(category_id)
        return await self._get(params)

    async def get_series(self, category_id: Optional[int] = None) -> list[dict]:
        params = {
            "username": self.username,
            "password": self.password,
            "action": "get_series",
        }
        if category_id is not None:
            params["category_id"] = str(category_id)
        return await self._get(params)

    async def get_epg_xml_url(self, channel_id: Optional[int] = None) -> str:
        """
        Xtream EPG is available as XML at /xmltv.php?username=X&password=Y.
        Returns the full URL for the Flutter app to consume or for us to proxy.
        """
        params = {
            "username": self.username,
            "password": self.password,
        }
        if channel_id is not None:
            params["channel_id"] = channel_id
        base = self._build_url("/xmltv.php")
        return f"{base}?{httpx.QueryParams(params)}"

    async def _get(self, params: dict) -> list[dict]:
        """Generic GET wrapper for player_api.php endpoints."""
        try:
            response = await self.client.get("/player_api.php", params=params)
            response.raise_for_status()
            data = response.json()
            if isinstance(data, dict):
                if "error" in data:
                    raise XtreamAPIError(f"API error: {data.get('error')}")
                return []
            if isinstance(data, list):
                return data
            return []
        except httpx.HTTPStatusError as e:
            raise XtreamAPIError(f"Xtream HTTP error: {e.response.status_code}")
        except httpx.RequestError as e:
            raise XtreamAPIError(f"Request error: {e}")

    def is_expired(self) -> bool:
        """Check if the session is expired based on user_info expiry field."""
        if not self._user_info:
            return True
        try:
            expiry_str = self._user_info.get("exp_date", "")
            if not expiry_str or expiry_str == "null":
                return False
            expiry = datetime.fromtimestamp(int(expiry_str))
            return datetime.utcnow() > expiry
        except (ValueError, TypeError):
            return False
