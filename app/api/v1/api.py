"""Civic-Link DPI - API Router Configuration"""

from fastapi import APIRouter

from app.api.v1.endpoints import auth, telemetry

api_router = APIRouter()

# Authentication endpoints (public)
api_router.include_router(
    auth.router,
    prefix="/auth",
    tags=["authentication"],
)

# Protected endpoints
api_router.include_router(
    telemetry.router,
    prefix="/telemetry",
    tags=["telemetry"],
)
