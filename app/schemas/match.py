"""Civic-Link DPI - Match Schemas

Pydantic models for match API request/response validation.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.models.match import MatchStatus, PaymentStatus


# =============================================================================
# REQUEST SCHEMAS
# =============================================================================


class ConfirmMatchRequest(BaseModel):
    """Request model for confirming a match."""

    pass


class RateMatchRequest(BaseModel):
    """Request model for rating a completed match."""

    driver_rating: Optional[int] = Field(
        None, ge=1, le=5, description="Passenger's rating of driver (1-5)"
    )
    driver_review: Optional[str] = Field(
        None, max_length=1000, description="Passenger's review of driver"
    )
    passenger_rating: Optional[int] = Field(
        None, ge=1, le=5, description="Driver's rating of passenger (1-5)"
    )
    passenger_review: Optional[str] = Field(
        None, max_length=1000, description="Driver's review of passenger"
    )


# =============================================================================
# RESPONSE SCHEMAS
# =============================================================================


class MatchResponse(BaseModel):
    """Response model for a commute match."""

    id: str
    commute_id: str
    driver_id: str
    passenger_id: str
    status: MatchStatus
    pickup_radius_meters: int
    fare_amount: Optional[float] = None
    payment_status: PaymentStatus
    commute_was_women_only: bool
    offer_was_women_only: bool
    confirmed_at: Optional[datetime] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class MatchDetailResponse(MatchResponse):
    """Extended match response with driver and passenger info."""

    driver_name: str
    passenger_name: str
    origin_address: str
    destination_address: str
    departure_time: Optional[datetime] = None


class MatchListResponse(BaseModel):
    """Response model for a list of matches."""

    items: list[MatchResponse]
    total: int
