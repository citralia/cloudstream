"""
CloudStream Backend — FastAPI entry point.
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime

from app.core.config import get_settings
from app.core.database import init_db
from app.models.schemas import HealthResponse
from app.routers import auth, channels, categories, epg, stream


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await init_db()
    yield
    # Shutdown — clean up httpx clients if needed


settings = get_settings()

app = FastAPI(
    title="CloudStream API",
    description="IPTV proxy API — Xtream auth, channel list, EPG, and stream proxy",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS
origins = settings.cors_origins.split(",") if settings.cors_origins != "*" else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(auth.router)
app.include_router(channels.router)
app.include_router(categories.router)
app.include_router(epg.router)
app.include_router(stream.router)


@app.get("/health", response_model=HealthResponse, tags=["health"])
async def health():
    return HealthResponse(
        status="ok",
        timestamp=datetime.utcnow(),
        version="1.0.0",
    )


@app.get("/", tags=["root"])
async def root():
    return {
        "name": "CloudStream API",
        "version": "1.0.0",
        "docs": "/docs",
    }
