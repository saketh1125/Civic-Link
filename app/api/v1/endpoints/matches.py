"""Civic-Link DPI - Match API Endpoints

Match creation, confirmation, and management.
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_user
from app.core.database import get_db
from app.core.exceptions import CivicLinkSafetyException
from app.models.user import User
from app.schemas.match import (
    CancelMatchRequest,
    MatchDetailResponse,
    MatchListResponse,
    MatchResponse,
    RateMatchRequest,
)
from app.services.match_service import MatchingService

router = APIRouter()


@router.post(
    "/{commute_id}/request",
    response_model=MatchResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Request to join a commute",
)
async def request_match(
    commute_id: str,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> MatchResponse:
    """Request to join a commute as a passenger.

    Args:
        commute_id: Commute UUID to join
        session: Database session
        current_user: Authenticated user

    Returns:
        Created match

    Raises:
        HTTPException: 400 if commute is full, 403 if safety check fails
    """
    service = MatchingService(session)

    try:
        match = await service.create_match(
            commute_id=commute_id,
            passenger_id=str(current_user.id),
        )
    except CivicLinkSafetyException as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    return MatchResponse(
        id=str(match.id),
        commute_id=match.commute_id,
        driver_id=match.driver_id,
        passenger_id=match.passenger_id,
        status=match.status,
        pickup_radius_meters=match.pickup_radius_meters,
        fare_amount=float(match.fare_amount) if match.fare_amount else None,
        payment_status=match.payment_status,
        commute_was_women_only=match.commute_was_women_only,
        offer_was_women_only=match.offer_was_women_only,
        confirmed_at=match.confirmed_at,
        started_at=match.started_at,
        completed_at=match.completed_at,
    )


@router.post(
    "/{match_id}/confirm",
    response_model=MatchResponse,
    summary="Confirm a pending match",
)
async def confirm_match(
    match_id: str,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> MatchResponse:
    """Confirm a pending match (driver action).

    Args:
        match_id: Match UUID
        session: Database session
        current_user: Authenticated user

    Returns:
        Confirmed match
    """
    service = MatchingService(session)
    match = await service.confirm_match(match_id)

    return MatchResponse(
        id=str(match.id),
        commute_id=match.commute_id,
        driver_id=match.driver_id,
        passenger_id=match.passenger_id,
        status=match.status,
        pickup_radius_meters=match.pickup_radius_meters,
        fare_amount=float(match.fare_amount) if match.fare_amount else None,
        payment_status=match.payment_status,
        commute_was_women_only=match.commute_was_women_only,
        offer_was_women_only=match.offer_was_women_only,
        confirmed_at=match.confirmed_at,
        started_at=match.started_at,
        completed_at=match.completed_at,
    )


@router.post(
    "/{match_id}/start",
    response_model=MatchResponse,
    summary="Start a confirmed match",
)
async def start_match(
    match_id: str,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> MatchResponse:
    """Start a confirmed match (driver action).

    Args:
        match_id: Match UUID
        session: Database session
        current_user: Authenticated user

    Returns:
        Started match
    """
    service = MatchingService(session)
    match = await service.start_match(match_id)

    return MatchResponse(
        id=str(match.id),
        commute_id=match.commute_id,
        driver_id=match.driver_id,
        passenger_id=match.passenger_id,
        status=match.status,
        pickup_radius_meters=match.pickup_radius_meters,
        fare_amount=float(match.fare_amount) if match.fare_amount else None,
        payment_status=match.payment_status,
        commute_was_women_only=match.commute_was_women_only,
        offer_was_women_only=match.offer_was_women_only,
        confirmed_at=match.confirmed_at,
        started_at=match.started_at,
        completed_at=match.completed_at,
    )


@router.post(
    "/{match_id}/cancel",
    response_model=MatchResponse,
    summary="Cancel a match",
)
async def cancel_match(
    match_id: str,
    request: CancelMatchRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> MatchResponse:
    """Cancel a pending or confirmed match.

    Args:
        match_id: Match UUID
        request: Cancellation details
        session: Database session
        current_user: Authenticated user

    Returns:
        Cancelled match
    """
    from sqlalchemy import select
    from sqlalchemy.orm import selectinload

    from app.models.match import CommuteMatch

    result = await session.execute(
        select(CommuteMatch)
        .where(CommuteMatch.id == match_id)
        .options(selectinload(CommuteMatch.commute))
    )
    match = result.scalar_one_or_none()

    if not match:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Match not found",
        )

    if (
        match.driver_id != str(current_user.id)
        and match.passenger_id != str(current_user.id)
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to cancel this match",
        )

    service = MatchingService(session)
    match = await service.cancel_match(match_id)

    return MatchResponse(
        id=str(match.id),
        commute_id=match.commute_id,
        driver_id=match.driver_id,
        passenger_id=match.passenger_id,
        status=match.status,
        pickup_radius_meters=match.pickup_radius_meters,
        fare_amount=float(match.fare_amount) if match.fare_amount else None,
        payment_status=match.payment_status,
        commute_was_women_only=match.commute_was_women_only,
        offer_was_women_only=match.offer_was_women_only,
        confirmed_at=match.confirmed_at,
        started_at=match.started_at,
        completed_at=match.completed_at,
    )


@router.post(
    "/{match_id}/complete",
    response_model=MatchResponse,
    summary="Complete a match",
)
async def complete_match(
    match_id: str,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> MatchResponse:
    """Complete an in-progress match (driver action).

    Args:
        match_id: Match UUID
        session: Database session
        current_user: Authenticated user

    Returns:
        Completed match
    """
    service = MatchingService(session)
    match = await service.complete_match(match_id)

    return MatchResponse(
        id=str(match.id),
        commute_id=match.commute_id,
        driver_id=match.driver_id,
        passenger_id=match.passenger_id,
        status=match.status,
        pickup_radius_meters=match.pickup_radius_meters,
        fare_amount=float(match.fare_amount) if match.fare_amount else None,
        payment_status=match.payment_status,
        commute_was_women_only=match.commute_was_women_only,
        offer_was_women_only=match.offer_was_women_only,
        confirmed_at=match.confirmed_at,
        started_at=match.started_at,
        completed_at=match.completed_at,
    )


@router.get(
    "/my",
    response_model=MatchListResponse,
    summary="Get my matches",
)
async def get_my_matches(
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> MatchListResponse:
    """Get all active matches for the current user.

    Args:
        session: Database session
        current_user: Authenticated user

    Returns:
        List of matches
    """
    service = MatchingService(session)
    matches = await service.get_active_matches_for_user(
        user_id=str(current_user.id)
    )

    items = [
        MatchResponse(
            id=str(m.id),
            commute_id=m.commute_id,
            driver_id=m.driver_id,
            passenger_id=m.passenger_id,
            status=m.status,
            pickup_radius_meters=m.pickup_radius_meters,
            fare_amount=float(m.fare_amount) if m.fare_amount else None,
            payment_status=m.payment_status,
            commute_was_women_only=m.commute_was_women_only,
            offer_was_women_only=m.offer_was_women_only,
            confirmed_at=m.confirmed_at,
            started_at=m.started_at,
            completed_at=m.completed_at,
        )
        for m in matches
    ]

    return MatchListResponse(items=items, total=len(items))


@router.get(
    "/{match_id}",
    response_model=MatchDetailResponse,
    summary="Get match details",
)
async def get_match(
    match_id: str,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> MatchDetailResponse:
    """Get details of a specific match.

    Args:
        match_id: Match UUID
        session: Database session
        current_user: Authenticated user

    Returns:
        Match details
    """
    from sqlalchemy import select
    from sqlalchemy.orm import selectinload

    from app.models.match import CommuteMatch

    result = await session.execute(
        select(CommuteMatch)
        .where(CommuteMatch.id == match_id)
        .options(
            selectinload(CommuteMatch.commute),
            selectinload(CommuteMatch.driver),
            selectinload(CommuteMatch.passenger),
        )
    )
    match = result.scalar_one_or_none()

    if not match:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Match not found",
        )

    if (
        match.driver_id != str(current_user.id)
        and match.passenger_id != str(current_user.id)
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this match",
        )

    return MatchDetailResponse(
        id=str(match.id),
        commute_id=match.commute_id,
        driver_id=match.driver_id,
        passenger_id=match.passenger_id,
        status=match.status,
        pickup_radius_meters=match.pickup_radius_meters,
        fare_amount=float(match.fare_amount) if match.fare_amount else None,
        payment_status=match.payment_status,
        commute_was_women_only=match.commute_was_women_only,
        offer_was_women_only=match.offer_was_women_only,
        confirmed_at=match.confirmed_at,
        started_at=match.started_at,
        completed_at=match.completed_at,
        driver_name=match.driver.full_name if match.driver else "Unknown",
        passenger_name=match.passenger.full_name if match.passenger else "Unknown",
        origin_address=match.commute.origin_address if match.commute else "",
        destination_address=match.commute.destination_address if match.commute else "",
    )


@router.post(
    "/{match_id}/rate",
    response_model=MatchResponse,
    summary="Rate a completed match",
)
async def rate_match(
    match_id: str,
    request: RateMatchRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> MatchResponse:
    """Rate a completed match.

    Args:
        match_id: Match UUID
        request: Rating details
        session: Database session
        current_user: Authenticated user

    Returns:
        Updated match
    """
    from sqlalchemy import select

    from app.models.match import CommuteMatch

    result = await session.execute(
        select(CommuteMatch).where(CommuteMatch.id == match_id)
    )
    match = result.scalar_one_or_none()

    if not match:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Match not found",
        )

    if match.status.value != "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Can only rate completed matches",
        )

    if request.driver_rating is not None:
        match.driver_rating = request.driver_rating
    if request.driver_review is not None:
        match.driver_review = request.driver_review
    if request.passenger_rating is not None:
        match.passenger_rating = request.passenger_rating
    if request.passenger_review is not None:
        match.passenger_review = request.passenger_review

    await session.flush()

    return MatchResponse(
        id=str(match.id),
        commute_id=match.commute_id,
        driver_id=match.driver_id,
        passenger_id=match.passenger_id,
        status=match.status,
        pickup_radius_meters=match.pickup_radius_meters,
        fare_amount=float(match.fare_amount) if match.fare_amount else None,
        payment_status=match.payment_status,
        commute_was_women_only=match.commute_was_women_only,
        offer_was_women_only=match.offer_was_women_only,
        confirmed_at=match.confirmed_at,
        started_at=match.started_at,
        completed_at=match.completed_at,
    )
