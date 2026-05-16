"""Civic-Link DPI - API Router Configuration"""

from fastapi import APIRouter

from app.api.v1.endpoints import auth, civic_score, commutes, matches, telemetry

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

api_router.include_router(
    commutes.router,
    prefix="/commutes",
    tags=["commutes"],
)

api_router.include_router(
    matches.router,
    prefix="/matches",
    tags=["matches"],
)

api_router.include_router(
    civic_score.router,
    prefix="/civic-score",
    tags=["civic-score"],
)
