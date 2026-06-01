"""
Categories router — /api/categories/*
"""
from fastapi import APIRouter, HTTPException, Depends

from app.models.schemas import Category, CategoryListResponse
from app.routers.auth import _require_auth


router = APIRouter(prefix="/api/categories", tags=["categories"])


@router.get("", response_model=CategoryListResponse)
async def list_categories(session: dict = Depends(_require_auth)):
    """Return all live TV, VOD, and series categories."""
    from app.services.xtream import XtreamClient, XtreamAPIError

    try:
        client = XtreamClient(
            server_url=session["server_url"],
            username=session["username"],
            password=session["password"],
        )
        await client.login()

        live_cats = await client.get_live_categories()
        vod_cats = await client.get_vod_categories()
        series_cats = await client.get_series_categories()
        await client.close()
    except XtreamAPIError as e:
        raise HTTPException(status_code=502, detail=f"Xtream error: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return CategoryListResponse(
        live=[
            Category(id=c.get("category_id", 0), name=c.get("category_name", ""), type="live")
            for c in live_cats
        ],
        vod=[
            Category(id=c.get("category_id", 0), name=c.get("category_name", ""), type="vod")
            for c in vod_cats
        ],
        series=[
            Category(id=c.get("category_id", 0), name=c.get("category_name", ""), type="series")
            for c in series_cats
        ],
    )
