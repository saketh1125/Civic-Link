"""Civic-Link DPI - Commute Schemas

Pydantic models for commute API request/response validation.
"""

from datetime import date, time
from typing import Optional

from pydantic import BaseModel, Field

from app.models.commute import CommuteStatus, CommuteType


# =============================================================================
# REQUEST SCHEMAS
# =============================================================================


class CreateCommuteRequest(BaseModel):
    """Request model for creating a driver commute offer."""

    origin_lat: float = Field(..., ge=-90, le=90, description="Origin latitude")
    origin_lon: float = Field(..., ge=-180, le=180, description="Origin longitude")
    destination_lat: float = Field(
        ..., ge=-90, le=90, description="Destination latitude"
    )
    destination_lon: float = Field(
        ..., ge=-180, le=180, description="Destination longitude"
    )
    origin_address: str = Field(..., description="Human-readable origin address")
    destination_address: str = Field(
        ..., description="Human-readable destination address"
    )
    departure_date: date = Field(..., description="Date of departure")
    departure_time: time = Field(..., description="Time of departure")
    available_seats: int = Field(default=1, ge=1, le=8, description="Available seats")
    total_seats: int = Field(default=4, ge=1, le=8, description="Total seat capacity")
    is_women_only: bool = Field(
        default=False, description="Women-only safety flag"
    )
    commute_type: CommuteType = Field(
        default=CommuteType.ONE_TIME, description="One-time or recurring"
    )
    recurring_days: Optional[str] = Field(
        None, description="Comma-separated days for recurring commutes"
    )


class CreateCommuteOfferRequest(BaseModel):
    """Request model for creating a passenger commute offer."""

    origin_lat: float = Field(..., ge=-90, le=90, description="Origin latitude")
    origin_lon: float = Field(..., ge=-180, le=180, description="Origin longitude")
    destination_lat: float = Field(
        ..., ge=-90, le=90, description="Destination latitude"
    )
    destination_lon: float = Field(
        ..., ge=-180, le=180, description="Destination longitude"
    )
    origin_address: str = Field(..., description="Human-readable origin address")
    destination_address: str = Field(
        ..., description="Human-readable destination address"
    )
    preferred_departure_date: date = Field(..., description="Preferred departure date")
    preferred_departure_time: time = Field(
        ..., description="Preferred departure time"
    )
    is_women_only: bool = Field(
        default=False, description="Women-only safety flag"
    )
    max_walking_distance: int = Field(
        default=500, ge=0, le=2000, description="Max walking distance in meters"
    )
    time_flexibility_minutes: int = Field(
        default=15, ge=0, le=60, description="Time flexibility in minutes"
    )


# =============================================================================
# RESPONSE SCHEMAS
# =============================================================================


class CommuteResponse(BaseModel):
    """Response model for a commute."""

    id: str
    driver_id: str
    origin_address: str
    destination_address: str
    departure_date: date
    departure_time: time
    available_seats: int
    total_seats: int
    is_women_only: bool
    commute_type: CommuteType
    status: CommuteStatus

    class Config:
        from_attributes = True


class CommuteOfferResponse(BaseModel):
    """Response model for a commute offer."""

    id: str
    passenger_id: str
    origin_address: str
    destination_address: str
    preferred_departure_date: date
    preferred_departure_time: time
    is_women_only: bool
    max_walking_distance: int
    status: str

    class Config:
        from_attributes = True


class CommuteDetailResponse(CommuteResponse):
    """Extended commute response with driver info."""

    driver_name: str
    driver_gender: str
    driver_score: Optional[float] = None
