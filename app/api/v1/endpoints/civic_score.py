"""Civic-Link DPI - Civic Score API Endpoints

Civic score retrieval, history, and telemetry ingestion for authenticated users.
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.user import CivicScoreResponse
from app.services.civic_score_service import CivicScoreService

router = APIRouter()


# =============================================================================
# INGESTION SCHEMAS
# =============================================================================


class TelemetrySample(BaseModel):
    """Single telemetry sample from mobile device."""

    timestamp: str = Field(..., description="ISO 8601 timestamp")
    speed_kmh: float = Field(0.0, ge=0, le=300, description="Vehicle speed")
    acceleration_ms2: float = Field(0.0, description="Forward acceleration")
    braking_ms2: float = Field(0.0, ge=0, description="Braking deceleration")
    swerve_index: float = Field(0.0, ge=0, description="Lateral g-force proxy (0-1)")
    phone_usage_detected: bool = Field(False, description="Phone usage during driving")


class TelemetryIngestRequest(BaseModel):
    """Request model for telemetry sample ingestion."""

    trip_id: str = Field(..., description="Trip identifier")
    samples: List[TelemetrySample] = Field(
        ...,
        min_length=1,
        max_length=5000,
        description="Telemetry samples collected during trip",
    )


class TelemetryIngestResponse(BaseModel):
    """Response model for telemetry ingestion."""

    civic_score: float = Field(..., description="Updated civic score")
    delta: float = Field(..., description="Score change from previous value")
    tier: str = Field(..., description="Score tier label")


# =============================================================================
# ENDPOINTS
# =============================================================================


@router.post(
    "/ingest",
    response_model=TelemetryIngestResponse,
    status_code=status.HTTP_200_OK,
    summary="Ingest telemetry samples and recalculate civic score",
)
async def ingest_telemetry(
    request: TelemetryIngestRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> TelemetryIngestResponse:
    """Ingest raw telemetry samples and calculate weighted penalty score.

    Args:
        request: Telemetry samples with trip_id
        session: Database session
        current_user: Authenticated user

    Returns:
        Updated civic score, delta, and tier

    Raises:
        HTTPException: 400 if no samples provided
    """
    if not request.samples:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one telemetry sample is required",
        )

    service = CivicScoreService(session)

    samples_data = [s.model_dump() for s in request.samples]

    score, delta = await service.ingest_telemetry_samples(
        user_id=str(current_user.id),
        samples=samples_data,
        trip_id=request.trip_id,
    )

    return TelemetryIngestResponse(
        civic_score=score.score,
        delta=round(delta, 2),
        tier=score.score_tier,
    )


@router.get(
    "/me",
    response_model=CivicScoreResponse,
    summary="Get my civic score",
)
async def get_my_score(
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> CivicScoreResponse:
    """Retrieve the current user's civic score.

    Args:
        session: Database session
        current_user: Authenticated user

    Returns:
        Current civic score with statistics
    """
    service = CivicScoreService(session)
    score = await service.get_or_create_score(user_id=str(current_user.id))

    return CivicScoreResponse(
        score=score.score,
        score_tier=score.score_tier,
        total_trips=score.total_trips,
        swerve_count=score.swerve_count,
        speeding_count=score.speeding_count,
        hard_braking_count=score.hard_braking_count,
    )


@router.get(
    "/history",
    response_model=List[dict],
    summary="Get my score history",
)
async def get_score_history(
    limit: int = 50,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> List[dict]:
    """Retrieve civic score change history.

    Args:
        limit: Maximum number of history entries
        session: Database session
        current_user: Authenticated user

    Returns:
        List of score history entries
    """
    service = CivicScoreService(session)
    history = await service.get_score_history(
        user_id=str(current_user.id),
        limit=limit,
    )

    return [
        {
            "id": str(h.id),
            "old_score": h.old_score,
            "new_score": h.new_score,
            "trigger_event": h.trigger_event,
            "swerve_count": h.swerve_count_at_time,
            "speeding_count": h.speeding_count_at_time,
            "created_at": h.created_at.isoformat() if h.created_at else None,
        }
        for h in history
    ]
