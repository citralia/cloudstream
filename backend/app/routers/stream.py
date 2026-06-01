"""
Stream router — /api/stream/*
Handles stream URL generation and proxying.
"""
from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import RedirectResponse
from datetime import datetime, timedelta

from app.models.schemas import StreamManifestResponse
from app.routers.auth import _require_auth


router = APIRouter(prefix="/api/stream", tags=["stream"])


@router.get("/{channel_id}")
async def get_stream_url(channel_id: int, session: dict = Depends(_require_auth)):
    """
    Redirect to the Xtream m3u8 stream URL.
    The Flutter app receives this redirect and plays the stream directly.
    This avoids passing Xtream credentials to the client.
    """
    from app.services.xtream import XtreamClient

    try:
        client = XtreamClient(
            server_url=session["server_url"],
            username=session["username"],
            password=session["password"],
        )
        await client.login()
        stream_url = client.get_stream_url(channel_id)
        await client.close()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Stream error: {e}")

    # Redirect to Xtream stream
    full_url = f"{session['server_url'].rstrip('/')}{stream_url}"
    return RedirectResponse(url=full_url, status_code=302)


@router.get("/{channel_id}/manifest", response_model=StreamManifestResponse)
async def get_stream_manifest(channel_id: int, session: dict = Depends(_require_auth)):
    """
    Return the manifest URL (m3u8) for a channel.
    Used by the Flutter video player to initialise HLS playback.
    """
    from app.services.xtream import XtreamClient

    try:
        client = XtreamClient(
            server_url=session["server_url"],
            username=session["username"],
            password=session["password"],
        )
        await client.login()
        stream_path = client.get_stream_url(channel_id)
        await client.close()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Stream error: {e}")

    full_url = f"{session['server_url'].rstrip('/')}{stream_path}"
    return StreamManifestResponse(
        manifest_url=full_url,
        channel_id=channel_id,
        expires_at=datetime.utcnow() + timedelta(hours=2),
    )
