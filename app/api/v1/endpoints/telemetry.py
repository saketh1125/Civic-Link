"""Civic-Link DPI - Telemetry API Endpoints

POST /api/v1/telemetry - Process 50Hz IMU readings
Uses FastAPI BackgroundTasks for zero-lag response.
"""

from typing import List, Optional

import structlog
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_user
from app.core.database import get_db
from app.core.exceptions import CivicLinkException
from app.models.user import User
from app.services.telemetry_service import IMUReading, TelemetryService

logger = structlog.get_logger()
router = APIRouter()


class IMUReadingInput(BaseModel):
    """Input model for a single IMU reading from mobile device."""

    timestamp_ms: int = Field(
        ...,
        description="Unix timestamp in milliseconds",
        example=1704067200000,
    )
    gyro_x: float = Field(
        ...,
        description="Gyroscope X-axis in rad/s",
        example=0.05,
    )
    gyro_y: float = Field(
        ...,
        description="Gyroscope Y-axis in rad/s",
        example=0.02,
    )
    gyro_z: float = Field(
        ...,
        description="Gyroscope Z-axis in rad/s (lane-cutting detection)",
        example=2.1,
    )
    accel_x: float = Field(
        ...,
        description="Accelerometer X-axis in m/s²",
        example=0.1,
    )
    accel_y: float = Field(
        ...,
        description="Accelerometer Y-axis in m/s²",
        example=-0.2,
    )
    accel_z: float = Field(
        ...,
        description="Accelerometer Z-axis in m/s²",
        example=9.8,
    )


class TelemetryBatchRequest(BaseModel):
    """Request model for telemetry batch submission."""

    user_id: str = Field(
        ...,
        description="User ID (driver) submitting telemetry",
        example="550e8400-e29b-41d4-a716-446655440000",
    )
    match_id: Optional[str] = Field(
        None,
        description="Optional match ID if telemetry is during an active ride",
        example="550e8400-e29b-41d4-a716-446655440001",
    )
    readings: List[IMUReadingInput] = Field(
        ...,
        description="Batch of 50Hz IMU readings",
        min_length=1,
        max_length=3000,  # Max 60 seconds at 50Hz
    )


class SwerveEventResponse(BaseModel):
    """Response model for detected swerve events."""

    timestamp_ms: int
    gyro_z_value: float
    severity: str


class TelemetryBatchResponse(BaseModel):
    """Response model for telemetry batch processing."""

    user_id: str
    processed_readings: int
    swerve_events_detected: int
    swerve_events: List[SwerveEventResponse]
    old_civic_score: float
    new_civic_score: float
    message: str


@router.post(
    "/telemetry",
    response_model=TelemetryBatchResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Submit telemetry batch for processing",
    description="""
    Submit a batch of 50Hz IMU readings for processing.
    
    The endpoint immediately returns 202 ACCEPTED and processes the data
    in the background to ensure zero-lag response to mobile clients.
    
    Lane-cutting detection:
    - Trigger: abs(gyro_z) > 1.5 rad/s
    - Cooldown: 60,000ms (1 minute) debounce between swerve events
    - Scoring: Weighted rolling average affects civic score
    """,
)
async def submit_telemetry(
    request: TelemetryBatchRequest,
    background_tasks: BackgroundTasks,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> TelemetryBatchResponse:
    """Submit telemetry batch for background processing.

    Args:
        request: Telemetry batch with IMU readings
        background_tasks: FastAPI background task handler
        session: Database session

    Returns:
        202 ACCEPTED response with acknowledgment

    Raises:
        HTTPException: If request validation fails
    """
    try:
        # Security: Verify the user_id in request matches the authenticated user
        if str(current_user.id) != request.user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot submit telemetry for another user",
            )
        
        # Convert input readings to service model
        readings = [
            IMUReading(
                timestamp_ms=r.timestamp_ms,
                gyro_x=r.gyro_x,
                gyro_y=r.gyro_y,
                gyro_z=r.gyro_z,
                accel_x=r.accel_x,
                accel_y=r.accel_y,
                accel_z=r.accel_z,
            )
            for r in request.readings
        ]

        # Create service instance
        telemetry_service = TelemetryService(session)

        # Process in background task for zero-lag response
        # This ensures the mobile client gets immediate acknowledgment
        background_tasks.add_task(
            _process_telemetry_background,
            telemetry_service,
            request.user_id,
            readings,
            request.match_id,
        )

        # Return immediate acknowledgment
        return TelemetryBatchResponse(
            user_id=request.user_id,
            processed_readings=len(readings),
            swerve_events_detected=0,  # Will be processed in background
            swerve_events=[],
            old_civic_score=0.0,  # Will be updated in background
            new_civic_score=0.0,  # Will be updated in background
            message="Telemetry batch accepted for processing",
        )

    except CivicLinkException as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process telemetry: {str(e)}",
        ) from e


async def _process_telemetry_background(
    service: TelemetryService,
    user_id: str,
    readings: List[IMUReading],
    match_id: Optional[str],
) -> None:
    """Background task for telemetry processing.

    This runs after the HTTP response is sent, ensuring zero-lag
    for the mobile client while heavy processing happens server-side.

    Args:
        service: TelemetryService instance
        user_id: User ID
        readings: IMU readings to process
        match_id: Optional match ID
    """
    try:
        result = await service.process_telemetry_batch(
            user_id=user_id,
            readings=readings,
            match_id=match_id,
        )

        # TODO: Send real-time notification if severe swerve detected
        # TODO: Update Redis cache for driver's active commute
        # TODO: Trigger audit log for swerve events

    except Exception as e:
        logger.error("Background telemetry processing failed", error=str(e))
