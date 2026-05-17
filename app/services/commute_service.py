"""Civic-Link DPI - Commute Service

Commute lifecycle management: creation, listing, status updates.
"""

from datetime import date, time
from typing import List, Optional

from geoalchemy2 import Geography
from geoalchemy2.shape import from_shape
from shapely.geometry import Point
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import CommuteNotFoundError
from app.models.commute import (
    Commute,
    CommuteOffer,
    CommuteStatus,
    CommuteType,
)
from app.models.user import User


class CommuteService:
    """Service for commute management operations."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create_commute(
        self,
        driver_id: str,
        origin_lat: float,
        origin_lon: float,
        destination_lat: float,
        destination_lon: float,
        origin_address: str,
        destination_address: str,
        departure_date: date,
        departure_time: time,
        available_seats: int = 1,
        total_seats: int = 4,
        is_women_only: bool = False,
        commute_type: CommuteType = CommuteType.ONE_TIME,
        recurring_days: Optional[str] = None,
    ) -> Commute:
        """Create a new commute offer.

        Args:
            driver_id: UUID of the driver
            origin_lat: Origin latitude
            origin_lon: Origin longitude
            destination_lat: Destination latitude
            destination_lon: Destination longitude
            origin_address: Human-readable origin address
            destination_address: Human-readable destination address
            departure_date: Date of departure
            departure_time: Time of departure
            available_seats: Number of available seats
            total_seats: Total seat capacity
            is_women_only: Women-only safety flag
            commute_type: One-time or recurring
            recurring_days: Comma-separated days for recurring commutes

        Returns:
            Created Commute
        """
        origin = from_shape(Point(origin_lon, origin_lat), srid=4326)
        destination = from_shape(Point(destination_lon, destination_lat), srid=4326)

        commute = Commute(
            driver_id=driver_id,
            origin=origin,
            destination=destination,
            origin_address=origin_address,
            destination_address=destination_address,
            departure_date=departure_date,
            departure_time=departure_time,
            available_seats=available_seats,
            total_seats=total_seats,
            is_women_only=is_women_only,
            commute_type=commute_type,
            recurring_days=recurring_days,
            status=CommuteStatus.ACTIVE,
        )

        self.session.add(commute)
        await self.session.flush()
        return commute

    async def get_commute_by_id(self, commute_id: str) -> Commute:
        """Retrieve a commute by ID with driver loaded.

        Args:
            commute_id: The commute UUID

        Returns:
            Commute with driver relationship loaded

        Raises:
            CommuteNotFoundError: If commute not found
        """
        result = await self.session.execute(
            select(Commute)
            .where(Commute.id == commute_id)
            .options(selectinload(Commute.driver))
        )
        commute = result.scalar_one_or_none()
        if not commute:
            raise CommuteNotFoundError(commute_id)
        return commute

    async def get_active_commutes_for_driver(
        self,
        driver_id: str,
    ) -> List[Commute]:
        """Get all active commutes for a driver.

        Args:
            driver_id: The driver's UUID

        Returns:
            List of active Commutes
        """
        result = await self.session.execute(
            select(Commute)
            .where(
                (Commute.driver_id == driver_id)
                & (Commute.status == CommuteStatus.ACTIVE)
            )
            .options(selectinload(Commute.driver))
        )
        return list(result.scalars().all())

    async def cancel_commute(self, commute_id: str) -> Commute:
        """Cancel an active commute.

        Args:
            commute_id: The commute UUID

        Returns:
            Updated Commute

        Raises:
            CommuteNotFoundError: If commute not found
        """
        commute = await self.get_commute_by_id(commute_id)
        commute.status = CommuteStatus.CANCELLED
        await self.session.flush()
        return commute

    async def create_commute_offer(
        self,
        passenger_id: str,
        origin_lat: float,
        origin_lon: float,
        destination_lat: float,
        destination_lon: float,
        origin_address: str,
        destination_address: str,
        preferred_departure_date: date,
        preferred_departure_time: time,
        is_women_only: bool = False,
        max_walking_distance: int = 500,
        time_flexibility_minutes: int = 15,
    ) -> CommuteOffer:
        """Create a new commute offer (passenger ride request).

        Args:
            passenger_id: UUID of the passenger
            origin_lat: Origin latitude
            origin_lon: Origin longitude
            destination_lat: Destination latitude
            destination_lon: Destination longitude
            origin_address: Human-readable origin address
            destination_address: Human-readable destination address
            preferred_departure_date: Preferred departure date
            preferred_departure_time: Preferred departure time
            is_women_only: Women-only safety flag
            max_walking_distance: Maximum walking distance in meters
            time_flexibility_minutes: Time flexibility in minutes

        Returns:
            Created CommuteOffer
        """
        origin = from_shape(Point(origin_lon, origin_lat), srid=4326)
        destination = from_shape(Point(destination_lon, destination_lat), srid=4326)

        offer = CommuteOffer(
            passenger_id=passenger_id,
            origin=origin,
            destination=destination,
            origin_address=origin_address,
            destination_address=destination_address,
            preferred_departure_date=preferred_departure_date,
            preferred_departure_time=preferred_departure_time,
            is_women_only=is_women_only,
            max_walking_distance=max_walking_distance,
            time_flexibility_minutes=time_flexibility_minutes,
            status="pending",
        )

        self.session.add(offer)
        await self.session.flush()
        return offer

    async def get_pending_offers_for_passenger(
        self,
        passenger_id: str,
    ) -> List[CommuteOffer]:
        """Get all pending commute offers for a passenger.

        Args:
            passenger_id: The passenger's UUID

        Returns:
            List of pending CommuteOffers
        """
        result = await self.session.execute(
            select(CommuteOffer)
            .where(
                (CommuteOffer.passenger_id == passenger_id)
                & (CommuteOffer.status == "pending")
            )
        )
        return list(result.scalars().all())

    async def cancel_offer(self, offer_id: str) -> CommuteOffer:
        """Cancel a pending commute offer.

        Args:
            offer_id: The offer UUID

        Returns:
            Updated CommuteOffer
        """
        result = await self.session.execute(
            select(CommuteOffer).where(CommuteOffer.id == offer_id)
        )
        offer = result.scalar_one_or_none()
        if not offer:
            raise CommuteNotFoundError(offer_id)

        offer.status = "cancelled"
        await self.session.flush()
        return offer

    async def search_commutes(
        self,
        user_id: str,
        origin_query: Optional[str] = None,
        destination_query: Optional[str] = None,
        departure_date: Optional[date] = None,
        is_women_only: Optional[bool] = None,
        min_seats: Optional[int] = None,
    ) -> List[Commute]:
        """Search for active commutes matching criteria.

        Excludes the requester's own commutes and cancelled/completed ones.

        Args:
            user_id: UUID of the searching user (to exclude own commutes)
            origin_query: ILIKE search in origin address
            destination_query: ILIKE search in destination address
            departure_date: Filter by exact departure date
            is_women_only: Filter by women-only flag
            min_seats: Minimum available seats

        Returns:
            List of matching Commutes with driver loaded
        """
        query = (
            select(Commute)
            .where(Commute.driver_id != user_id)
            .where(Commute.status == CommuteStatus.ACTIVE)
            .options(selectinload(Commute.driver))
        )

        if origin_query:
            query = query.where(Commute.origin_address.ilike(f"%{origin_query}%"))
        if destination_query:
            query = query.where(
                Commute.destination_address.ilike(f"%{destination_query}%")
            )
        if departure_date:
            query = query.where(Commute.departure_date == departure_date)
        if is_women_only is not None:
            query = query.where(Commute.is_women_only == is_women_only)
        if min_seats is not None:
            query = query.where(Commute.available_seats >= min_seats)

        result = await self.session.execute(query)
        return list(result.scalars().all())
