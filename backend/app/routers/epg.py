"""
EPG router — /api/epg/*
"""
from fastapi import APIRouter, HTTPException, Depends, Query
from datetime import datetime
from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.schemas import EPGChannel, EPGProgramme, EPGResponse
from app.routers.auth import _require_auth
from app.core.database import get_db, EPGCache


router = APIRouter(prefix="/api/epg", tags=["epg"])


@router.get("", response_model=EPGResponse)
async def get_epg(
    channel_id: Optional[int] = Query(None, description="Filter by channel ID"),
    hours: int = Query(24, ge=1, le=168, description="Hours ahead to fetch"),
    session: dict = Depends(_require_auth),
    db: AsyncSession = Depends(get_db),
):
    """
    Return EPG data for all channels (or filtered by channel_id).
    Data comes from the cached DB — refreshed via /api/epg/refresh.
    """
    from app.services.xtream import XtreamClient

    # If cache is empty, try to seed it
    result = await db.execute(select(EPGCache))
    cached = result.scalars().all()

    if not cached:
        # Try to seed from Xtream
        try:
            client = XtreamClient(
                server_url=session["server_url"],
                username=session["username"],
                password=session["password"],
            )
            await client.login()
            epg_url = await client.get_epg_xml_url(channel_id=channel_id)
            await client.close()
            # Trigger a refresh in background (EPG fetch can be slow)
        except Exception:
            pass

        # Return empty if no cache
        return EPGResponse(channels=[], updated_at=datetime.utcnow())

    # Group by channel
    from collections import defaultdict
    by_channel: dict = defaultdict(list)
    for row in cached:
        if channel_id and row.channel_id != channel_id:
            continue
        by_channel[row.channel_id].append(row)

    epg_channels = []
    for ch_id, progs in by_channel.items():
        first = progs[0]
        epg_channels.append(EPGChannel(
            id=ch_id,
            name="",  # Channel name not stored in EPGCache
            logo=None,
            programmes=[
                EPGProgramme(
                    id=f"{prog.channel_id}_{prog.start.timestamp()}",
                    channel_id=prog.channel_id,
                    title=prog.title,
                    description=prog.description,
                    start=prog.start,
                    end=prog.end,
                    category=prog.category,
                    is_catchup=prog.catchup_available,
                )
                for prog in sorted(progs, key=lambda p: p.start)
            ],
        ))

    updated = max((p.updated_at for p in cached), default=datetime.utcnow())

    return EPGResponse(channels=epg_channels, updated_at=updated)


@router.post("/refresh")
async def refresh_epg(
    channel_id: Optional[int] = Query(None),
    session: dict = Depends(_require_auth),
    db: AsyncSession = Depends(get_db),
):
    """
    Force-refresh the EPG cache from Xtream.
    Returns count of programmes cached.
    """
    from app.services.epg import EPGService, EPGFetchError, EPGParseError
    from app.services.xtream import XtreamClient

    try:
        client = XtreamClient(
            server_url=session["server_url"],
            username=session["username"],
            password=session["password"],
        )
        await client.login()
        xtream_base = session["server_url"]
        await client.close()

        epg = EPGService(xtream_base, session["username"], session["password"])
        channels = await epg.fetch_and_parse(db, hours_ahead=48, max_channels=100)
        await epg.close()
    except (EPGFetchError, EPGParseError) as e:
        raise HTTPException(status_code=502, detail=f"EPG error: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    total = sum(len(ch["programmes"]) for ch in channels)
    return {"status": "ok", "programmes_cached": total, "channels_cached": len(channels)}
