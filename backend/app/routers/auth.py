"""
Auth router — /api/auth/*
"""
from fastapi import APIRouter, HTTPException, Depends, Header
from typing import Optional
import secrets

from app.models.schemas import LoginRequest, LoginResponse, UserInfo
from app.services.xtream import XtreamClient, XtreamAuthError, XtreamAPIError


router = APIRouter(prefix="/api/auth", tags=["auth"])

# In-memory token store (per-server-session)
# In production: Redis or DB-backed session store
_sessions: dict[str, dict] = {}


def _build_token() -> str:
    return secrets.token_urlsafe(32)


def _require_auth(authorization: Optional[str] = Header(None)) -> dict:
    """Extract and validate Bearer token. Returns session dict."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header required")
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization scheme")
    token = authorization.removeprefix("Bearer ").strip()
    if token not in _sessions:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return _sessions[token]


@router.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    """
    Authenticate with Xtream credentials.
    Returns a session token for subsequent requests.
    """
    try:
        client = XtreamClient(
            server_url=request.server_url,
            username=request.username,
            password=request.password,
        )
        user_info = await client.login()
        await client.close()
    except XtreamAuthError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except XtreamAPIError as e:
        raise HTTPException(status_code=502, detail=f"Xtream error: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {e}")

    token = _build_token()
    _sessions[token] = {
        "token": token,
        "server_url": request.server_url,
        "username": request.username,
        "password": request.password,
        "user_info": user_info,
    }

    return LoginResponse(
        token=token,
        user=UserInfo(
            id=user_info.get("id", 0),
            username=user_info.get("username", request.username),
            status=user_info.get("status", "Active"),
            expiry=user_info.get("exp_date", ""),
            is_trial=bool(user_info.get("is_trial", False)),
            max_connections=int(user_info.get("max_connections", 1)),
            allowed_output_formats=user_info.get("allowed_output_formats", ["m3u8"]),
        ),
        active=True,
    )


@router.post("/logout")
async def logout(authorization: Optional[str] = Header(None)):
    """Invalidate the session token."""
    session = _require_auth(authorization)
    token = session["token"]
    del _sessions[token]
    return {"status": "ok"}


@router.get("/me")
async def me(authorization: Optional[str] = Header(None)):
    """Return current user info for the session."""
    session = _require_auth(authorization)
    return {"user": session["user_info"]}
