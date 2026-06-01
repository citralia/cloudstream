"""
EPG service — fetches, parses, and caches XMLTV data from Xtream.
"""

import httpx
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import EPGCache


XMLTV_NAMESPACES = {
    "tv": "http://xmltv.org/xmltv/"
}


class EPGService:
    """Fetches and parses XMLTV EPG data from Xtream."""

    def __init__(self, xtream_base_url: str, username: str, password: str):
        self.xtream_base_url = xtream_base_url.rstrip("/")
        self.username = username
        self.password = password
        self._client: Optional[httpx.AsyncClient] = None

    @property
    def client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(timeout=60.0, follow_redirects=True)
        return self._client

    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None

    def _epg_url(self, channel_id: Optional[int] = None) -> str:
        params = f"username={self.username}&password={self.password}"
        if channel_id:
            return f"{self.xtream_base_url}/xmltv.php?{params}&channel_id={channel_id}"
        return f"{self.xtream_base_url}/xmltv.php?{params}"

    async def fetch_and_parse(
        self,
        session: AsyncSession,
        hours_ahead: int = 24,
        max_channels: int = 50,
    ) -> list[dict]:
        """
        Fetch XMLTV from Xtream, parse it, and store in DB.
        Returns a list of channel dicts with their programmes.
        """
        url = self._epg_url()
        try:
            response = await self.client.get(url)
            response.raise_for_status()
            xml_content = response.text
        except httpx.RequestError as e:
            raise EPGFetchError(f"Failed to fetch EPG: {e}")

        channels = self._parse_xmltv(xml_content, hours_ahead, max_channels)

        # Store in DB
        await self._store_in_db(session, channels)

        return channels

    def _parse_xmltv(
        self, xml_content: str, hours_ahead: int, max_channels: int
    ) -> list[dict]:
        """Parse XMLTV XML into channel dicts with programmes."""
        now = datetime.utcnow()
        cutoff = now + timedelta(hours=hours_ahead)

        try:
            root = ET.fromstring(xml_content)
        except ET.ParseError as e:
            raise EPGParseError(f"Invalid XML: {e}")

        channels: list[dict] = []
        channel_count = 0

        for channel_elem in root.findall("channel", XMLTV_NAMESPACES):
            if channel_count >= max_channels:
                break

            channel_id = channel_elem.get("id", "")
            display_name = ""
            icon = ""
            if channel_elem.find("display-name", XMLTV_NAMESPACES) is not None:
                display_name = (
                    channel_elem.find("display-name", XMLTV_NAMESPACES).text or ""
                ).strip()
            icon_elem = channel_elem.find("icon", XMLTV_NAMESPACES)
            if icon_elem is not None:
                icon = icon_elem.get("src", "")

            programmes: list[dict] = []
            for prog_elem in root.findall(
                f".//programme[@channel='{channel_id}']", XMLTV_NAMESPACES
            ):
                start_str = prog_elem.get("start", "")
                end_str = prog_elem.get("stop", "")
                title_elem = prog_elem.find("title", XMLTV_NAMESPACES)
                title = title_elem.text if title_elem is not None else ""
                desc_elem = prog_elem.find("desc", XMLTV_NAMESPACES)
                desc = desc_elem.text if desc_elem is not None else None
                category_elems = prog_elem.findall("category", XMLTV_NAMESPACES)
                category = (
                    category_elems[0].text if category_elems else None
                )

                start_dt = self._parse_xmltv_datetime(start_str)
                end_dt = self._parse_xmltv_datetime(end_str)

                if start_dt is None or end_dt is None:
                    continue
                if start_dt < now or start_dt > cutoff:
                    continue

                prog_id = f"{channel_id}_{start_str}"

                programmes.append({
                    "id": prog_id,
                    "channel_id": channel_id,
                    "title": title or "Unknown",
                    "description": desc,
                    "start": start_dt,
                    "end": end_dt,
                    "category": category,
                    "is_catchup": True,  # Most Xtream servers support catchup
                })

            if programmes:
                channels.append({
                    "id": channel_id,
                    "name": display_name,
                    "logo": icon,
                    "programmes": programmes,
                })
                channel_count += 1

        return channels

    def _parse_xmltv_datetime(self, dt_str: str) -> Optional[datetime]:
        """Parse XMLTV datetime format: 20260601190000 +0000"""
        try:
            # Format: 20260601190000 +0000
            dt_str = dt_str.strip()
            if len(dt_str) < 14:
                return None
            date_part = dt_str[:8]
            time_part = dt_str[8:14]
            return datetime.strptime(f"{date_part}{time_part}", "%Y%m%d%H%M%S")
        except ValueError:
            return None

    async def _store_in_db(self, session: AsyncSession, channels: list[dict]):
        """Clear old EPG data and insert fresh."""
        # Clear all existing
        await session.execute(delete(EPGCache))
        await session.commit()

        all_programmes = []
        for ch in channels:
            for prog in ch.get("programmes", []):
                all_programmes.append(EPGCache(
                    channel_id=prog["channel_id"],
                    title=prog["title"],
                    description=prog.get("description"),
                    start=prog["start"],
                    end=prog["end"],
                    category=prog.get("category"),
                    catchup_available=prog.get("is_catchup", False),
                ))

        session.add_all(all_programmes)
        await session.commit()


class EPGFetchError(Exception):
    pass


class EPGParseError(Exception):
    pass
