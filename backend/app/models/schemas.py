from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional


class LoginRequest(BaseModel):
    server_url: str = Field(..., description="Xtream server URL (e.g. http://1.2.3.4:8080)")
    username: str
    password: str


class UserInfo(BaseModel):
    id: int
    username: str
    status: str
    expiry: str
    is_trial: bool
    max_connections: int
    allowed_output_formats: list[str]


class LoginResponse(BaseModel):
    token: str
    user: UserInfo
    active: bool


class Channel(BaseModel):
    id: int
    name: str
    logo: Optional[str] = None
    category_id: int
    category_name: str
    stream_url: str
    is_recording: bool = False


class ChannelListResponse(BaseModel):
    channels: list[Channel]
    total: int


class Category(BaseModel):
    id: int
    name: str
    type: str  # "live" | "vod" | "series"


class CategoryListResponse(BaseModel):
    live: list[Category]
    vod: list[Category]
    series: list[Category]


class EPGProgramme(BaseModel):
    id: str  # "{channel_id}_{start_timestamp}"
    channel_id: int
    title: str
    description: Optional[str] = None
    start: datetime
    end: datetime
    category: Optional[str] = None
    is_catchup: bool = False


class EPGChannel(BaseModel):
    id: int
    name: str
    logo: Optional[str] = None
    programmes: list[EPGProgramme]


class EPGResponse(BaseModel):
    channels: list[EPGChannel]
    updated_at: datetime


class StreamManifestResponse(BaseModel):
    manifest_url: str
    channel_id: int
    expires_at: datetime


class HealthResponse(BaseModel):
    status: str
    timestamp: datetime
    version: str = "1.0.0"
