"""Civic-Link DPI - Commute API Endpoints

Commute creation, listing, and management for drivers and passengers.
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_user
from app.core.database import get_db
from app.models.commute import CommuteStatus
from app.models.user import User
from app.schemas.commute import (
    CommuteDetailResponse,
    CommuteOfferResponse,
    CommuteResponse,
    CreateCommuteOfferRequest,
    CreateCommuteRequest,
)
from app.services.commute_service import CommuteService

router = APIRouter()


@router.post(
    "/",
    response_model=CommuteResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new commute offer",
)
async def create_commute(
    request: CreateCommuteRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> CommuteResponse:
    """Create a new commute offer as a driver.

    Args:
        request: Commute details
        session: Database session
        current_user: Authenticated user

    Returns:
        Created commute
    """
    service = CommuteService(session)

    commute = await service.create_commute(
        driver_id=str(current_user.id),
        origin_lat=request.origin_lat,
        origin_lon=request.origin_lon,
        destination_lat=request.destination_lat,
        destination_lon=request.destination_lon,
        origin_address=request.origin_address,
        destination_address=request.destination_address,
        departure_date=request.departure_date,
        departure_time=request.departure_time,
        available_seats=request.available_seats,
        total_seats=request.total_seats,
        is_women_only=request.is_women_only,
        commute_type=request.commute_type,
        recurring_days=request.recurring_days,
    )

    return CommuteResponse(
        id=str(commute.id),
        driver_id=commute.driver_id,
        origin_address=commute.origin_address,
        destination_address=commute.destination_address,
        departure_date=commute.departure_date,
        departure_time=commute.departure_time,
        available_seats=commute.available_seats,
        total_seats=commute.total_seats,
        is_women_only=commute.is_women_only,
        commute_type=commute.commute_type,
        status=commute.status,
    )


@router.get(
    "/my",
    response_model=List[CommuteResponse],
    summary="Get my active commutes",
)
async def get_my_commutes(
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> List[CommuteResponse]:
    """Get all active commutes for the current user (as driver).

    Args:
        session: Database session
        current_user: Authenticated user

    Returns:
        List of active commutes
    """
    service = CommuteService(session)
    commutes = await service.get_active_commutes_for_driver(
        driver_id=str(current_user.id)
    )

    return [
        CommuteResponse(
            id=str(c.id),
            driver_id=c.driver_id,
            origin_address=c.origin_address,
            destination_address=c.destination_address,
            departure_date=c.departure_date,
            departure_time=c.departure_time,
            available_seats=c.available_seats,
            total_seats=c.total_seats,
            is_women_only=c.is_women_only,
            commute_type=c.commute_type,
            status=c.status,
        )
        for c in commutes
    ]


@router.get(
    "/{commute_id}",
    response_model=CommuteDetailResponse,
    summary="Get commute details",
)
async def get_commute(
    commute_id: str,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> CommuteDetailResponse:
    """Get details of a specific commute.

    Args:
        commute_id: Commute UUID
        session: Database session
        current_user: Authenticated user

    Returns:
        Commute details with driver info
    """
    service = CommuteService(session)
    commute = await service.get_commute_by_id(commute_id)

    return CommuteDetailResponse(
        id=str(commute.id),
        driver_id=commute.driver_id,
        origin_address=commute.origin_address,
        destination_address=commute.destination_address,
        departure_date=commute.departure_date,
        departure_time=commute.departure_time,
        available_seats=commute.available_seats,
        total_seats=commute.total_seats,
        is_women_only=commute.is_women_only,
        commute_type=commute.commute_type,
        status=commute.status,
        driver_name=commute.driver.full_name if commute.driver else "Unknown",
        driver_gender=commute.driver.gender.value if commute.driver else "unknown",
    )


@router.post(
    "/{commute_id}/cancel",
    response_model=CommuteResponse,
    summary="Cancel a commute",
)
async def cancel_commute(
    commute_id: str,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> CommuteResponse:
    """Cancel an active commute.

    Only the driver who created the commute can cancel it.

    Args:
        commute_id: Commute UUID
        session: Database session
        current_user: Authenticated user

    Returns:
        Cancelled commute
    """
    service = CommuteService(session)
    commute = await service.get_commute_by_id(commute_id)

    if commute.driver_id != str(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the driver can cancel this commute",
        )

    commute = await service.cancel_commute(commute_id)

    return CommuteResponse(
        id=str(commute.id),
        driver_id=commute.driver_id,
        origin_address=commute.origin_address,
        destination_address=commute.destination_address,
        departure_date=commute.departure_date,
        departure_time=commute.departure_time,
        available_seats=commute.available_seats,
        total_seats=commute.total_seats,
        is_women_only=commute.is_women_only,
        commute_type=commute.commute_type,
        status=commute.status,
    )


@router.post(
    "/offers",
    response_model=CommuteOfferResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a commute offer (passenger)",
)
async def create_commute_offer(
    request: CreateCommuteOfferRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> CommuteOfferResponse:
    """Create a new commute offer as a passenger.

    Args:
        request: Offer details
        session: Database session
        current_user: Authenticated user

    Returns:
        Created commute offer
    """
    service = CommuteService(session)

    offer = await service.create_commute_offer(
        passenger_id=str(current_user.id),
        origin_lat=request.origin_lat,
        origin_lon=request.origin_lon,
        destination_lat=request.destination_lat,
        destination_lon=request.destination_lon,
        origin_address=request.origin_address,
        destination_address=request.destination_address,
        preferred_departure_date=request.preferred_departure_date,
        preferred_departure_time=request.preferred_departure_time,
        is_women_only=request.is_women_only,
        max_walking_distance=request.max_walking_distance,
        time_flexibility_minutes=request.time_flexibility_minutes,
    )

    return CommuteOfferResponse(
        id=str(offer.id),
        passenger_id=offer.passenger_id,
        origin_address=offer.origin_address,
        destination_address=offer.destination_address,
        preferred_departure_date=offer.preferred_departure_date,
        preferred_departure_time=offer.preferred_departure_time,
        is_women_only=offer.is_women_only,
        max_walking_distance=offer.max_walking_distance,
        status=offer.status,
    )
