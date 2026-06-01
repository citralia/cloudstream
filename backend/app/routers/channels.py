"""
Channels router — /api/channels/*
"""
from fastapi import APIRouter, HTTPException, Depends
from typing import Optional

from app.models.schemas import Channel, ChannelListResponse
from app.routers.auth import _require_auth


router = APIRouter(prefix="/api/channels", tags=["channels"])


@router.get("", response_model=ChannelListResponse)
async def list_channels(
    category_id: Optional[int] = None,
    session: dict = Depends(_require_auth),
):
    """
    Return all live TV channels, optionally filtered by category.
    """
    from app.services.xtream import XtreamClient, XtreamAPIError

    try:
        client = XtreamClient(
            server_url=session["server_url"],
            username=session["username"],
            password=session["password"],
        )
        await client.login()

        streams = await client.get_live_streams(category_id=category_id)
        await client.close()
    except XtreamAPIError as e:
        raise HTTPException(status_code=502, detail=f"Xtream error: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    channels = []
    for stream in streams:
        cat_id = stream.get("category_id")
        if isinstance(cat_id, str) and cat_id.isdigit():
            cat_id = int(cat_id)
        elif cat_id is None:
            cat_id = None
        channels.append(Channel(
            id=stream["stream_id"],
            name=stream.get("name") or "Unknown",
            logo=stream.get("stream_icon"),
            category_id=cat_id,
            category_name=stream.get("category_name") or "",
            stream_url=f"/api/stream/{stream['stream_id']}",
            is_recording=False,
        ))

    return ChannelListResponse(channels=channels, total=len(channels))


@router.get("/{channel_id}", response_model=Channel)
async def get_channel(channel_id: int, session: dict = Depends(_require_auth)):
    """Return a single channel by ID."""
    from app.services.xtream import XtreamClient, XtreamAPIError

    try:
        client = XtreamClient(
            server_url=session["server_url"],
            username=session["username"],
            password=session["password"],
        )
        await client.login()

        # Fetch all channels and filter (Xtream doesn't expose single stream by ID)
        streams = await client.get_live_streams()
        await client.close()
    except XtreamAPIError as e:
        raise HTTPException(status_code=502, detail=f"Xtream error: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    for stream in streams:
        if stream.get("stream_id") == channel_id:
            return Channel(
                id=stream["stream_id"],
                name=stream.get("name", "Unknown"),
                logo=stream.get("stream_icon", ""),
                category_id=stream.get("category_id", 0),
                category_name=stream.get("category_name", ""),
                stream_url=f"/api/stream/{stream['stream_id']}",
                is_recording=False,
            )

    raise HTTPException(status_code=404, detail="Channel not found")
