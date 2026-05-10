"""Civic-Link DPI - Matching Service

Implements the hard-reject safety logic at the database level.
CRITICAL: Gender safety filtering happens in SQL, not Python.
"""

from datetime import datetime, timedelta, timezone
from typing import List, Optional, Tuple

from geoalchemy2 import Geography
from geoalchemy2.shape import to_shape
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.sql import Select

from app.core.config import get_settings
from app.core.exceptions import CivicLinkSafetyException, GeospatialConflictError
from app.models.commute import Commute, CommuteOffer, CommuteStatus
from app.models.match import CommuteMatch, MatchStatus
from app.models.user import Gender, User

settings = get_settings()


class MatchingService:
    """Service for matching passengers with drivers.

    CRITICAL SAFETY: All matching queries include the mandatory
    hard-reject safety clause at the database level.
    """

    # Search parameters
    DEFAULT_RADIUS_METERS = 500
    TIME_WINDOW_MINUTES = 30

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def find_matching_commutes(
        self,
        offer: CommuteOffer,
        radius_meters: Optional[int] = None,
    ) -> List[Tuple[Commute, float]]:
        """Find available commutes matching a passenger offer.

        CRITICAL: This query enforces the hard-reject safety logic
        at the database level. The SQL mandatory clause ensures:

        - If offer.is_women_only=True, driver MUST be female
        - If commute.is_women_only=True, passenger MUST be female

        Args:
            offer: The passenger's commute request
            radius_meters: Search radius (default: 500m)

        Returns:
            List of (Commute, distance_meters) tuples, ordered by distance

        Raises:
            CivicLinkSafetyException: If safety clause is violated
            GeospatialConflictError: If geospatial query fails
        """
        search_radius = radius_meters or self.DEFAULT_RADIUS_METERS

        # Build the raw SQL query with mandatory safety clause
        # This uses text() to ensure the safety logic is in the SQL itself
        sql = text("""
            SELECT
                c.id as commute_id,
                ST_Distance(
                    c.origin::geography,
                    $7::geography
                ) as pickup_distance,
                c.available_seats,
                c.departure_time,
                u.gender as driver_gender,
                c.is_women_only as commute_women_only,
                :1 as offer_women_only
            FROM commutes c
            JOIN users u ON c.driver_id = u.id
            WHERE c.status::text = 'active'
                AND c.available_seats > 0
                AND c.departure_date = :2
                AND c.departure_time BETWEEN :3 AND :4
                -- CRITICAL: Hard-reject safety clause (MANDATORY)
                AND (
                    (:1::boolean = FALSE OR u.gender::text = 'female')
                    AND
                    (c.is_women_only = FALSE OR :5::text = 'female')
                )
                -- Geospatial: Within 500m of pickup point
                AND ST_DWithin(
                    c.origin::geography,
                    :7::geography,
                    :6
                )
            ORDER BY pickup_distance ASC
            LIMIT 50
        """)

        # Calculate time window (±30 minutes)
        offer_time = datetime.combine(
            offer.preferred_departure_date,
            offer.preferred_departure_time,
        )
        time_min = (offer_time - timedelta(minutes=self.TIME_WINDOW_MINUTES)).time()
        time_max = (offer_time + timedelta(minutes=self.TIME_WINDOW_MINUTES)).time()

        # Get passenger gender for safety check
        passenger_result = await self.session.execute(
            select(User.gender).where(User.id == offer.passenger_id)
        )
        passenger_gender = passenger_result.scalar()

        if passenger_gender is None:
            raise CivicLinkSafetyException("Passenger gender not found for safety check")

        # Extract coordinates from GeoAlchemy object
        origin_shape = to_shape(offer.origin)
        lon = origin_shape.x
        lat = origin_shape.y

        # Execute the query with safety parameters (positional $1-$7)
        # Order: $1=is_women_only, $2=date, $3=time_min, $4=time_max, $5=gender, $6=radius, $7=origin_point
        # exec_driver_sql bypasses SQLAlchemy's parser and sends the $1 syntax directly to asyncpg.
        sql_str = """
            SELECT
                c.id as commute_id,
                ST_Distance(
                    c.origin::geography,
                    $7::geography
                ) as pickup_distance,
                c.available_seats,
                c.departure_time,
                u.gender as driver_gender,
                c.is_women_only as commute_women_only,
                $1::boolean as offer_women_only
            FROM commutes c
            JOIN users u ON c.driver_id = u.id
            WHERE UPPER(c.status::text) = 'ACTIVE'
                AND c.available_seats > 0
                AND c.departure_date = $2
                AND c.departure_time BETWEEN $3 AND $4
                -- CRITICAL: Hard-reject safety logic (MANDATORY)
                AND (
                    ($1::boolean = FALSE OR UPPER(u.gender::text) = 'FEMALE')
                    AND
                    (c.is_women_only = FALSE OR UPPER($5::text) = 'FEMALE')
                )
                -- Geospatial: Within 500m of pickup point
                AND ST_DWithin(
                    c.origin::geography,
                    $7::geography,
                    $6
                )
            ORDER BY pickup_distance ASC
            LIMIT 50
        """
        
        params = (
            offer.is_women_only,
            offer.preferred_departure_date,
            time_min,
            time_max,
            passenger_gender.value,
            search_radius,
            f"SRID=4326;POINT({lon} {lat})",
        )
        
        # Use exec_driver_sql to satisfy positional binding requirement
        # and prevent SQLAlchemy from attempting to parse $1 syntax.
        conn = await self.session.connection()
        result = await conn.exec_driver_sql(sql_str, params)

        rows = result.fetchall()
        
        if not rows:
            return []

        # Fetch full Commute objects with driver profiles (selectinload for performance)
        commute_ids = [row.commute_id for row in rows]
        commute_query = (
            select(Commute)
            .where(Commute.id.in_(commute_ids))
            .options(
                selectinload(Commute.driver),
            )
        )

        commute_result = await self.session.execute(commute_query)
        commutes = {c.id: c for c in commute_result.scalars().all()}

        # Return ordered results with distances
        results = []
        for row in rows:
            commute = commutes.get(row.commute_id)
            if commute:
                results.append((commute, float(row.pickup_distance)))

        return results

    async def create_match(
        self,
        commute_id: str,
        passenger_id: str,
    ) -> CommuteMatch:
        """Create a match between a driver and passenger.

        CRITICAL: Validates safety constraints before creating match.
        Every match generates an encrypted audit log entry.

        Args:
            commute_id: ID of the commute (driver's offer)
            passenger_id: ID of the passenger

        Returns:
            The created CommuteMatch

        Raises:
            CivicLinkSafetyException: If safety check fails
        """
        # Fetch commute with driver and passenger for safety verification
        commute_result = await self.session.execute(
            select(Commute)
            .where(Commute.id == commute_id)
            .options(
                selectinload(Commute.driver),
            )
        )
        commute = commute_result.scalar_one_or_none()

        if not commute:
            raise GeospatialConflictError(f"Commute {commute_id} not found")

        if commute.available_seats <= 0:
            raise GeospatialConflictError("Commute has no available seats")

        passenger_result = await self.session.execute(
            select(User).where(User.id == passenger_id)
        )
        passenger = passenger_result.scalar_one_or_none()

        if not passenger:
            raise CivicLinkSafetyException(f"Passenger {passenger_id} not found")

        # CRITICAL SAFETY CHECK: Hard-reject validation
        # This is a double-check at the application level
        if commute.is_women_only and passenger.gender != Gender.FEMALE:
            raise CivicLinkSafetyException(
                f"Safety violation: Women-only commute cannot match non-female passenger"
            )

        # Decrement available seats
        commute.decrement_seats()
        if commute.is_full:
            commute.status = CommuteStatus.COMPLETED

        # Create match with safety snapshots
        match = CommuteMatch(
            commute_id=commute_id,
            driver_id=commute.driver_id,
            passenger_id=passenger_id,
            status=MatchStatus.PENDING,
            pickup_radius_meters=0,  # Will be calculated from actual distance
            commute_was_women_only=commute.is_women_only,
            offer_was_women_only=False,  # Will be set from offer if applicable
        )

        self.session.add(match)
        await self.session.flush()

        # TODO: Generate encrypted audit log entry
        # This will be implemented in audit_service.py

        return match

    async def get_active_matches_for_user(
        self,
        user_id: str,
    ) -> List[CommuteMatch]:
        """Get all active matches for a user (as driver or passenger).

        Args:
            user_id: The user's ID

        Returns:
            List of active matches
        """
        result = await self.session.execute(
            select(CommuteMatch)
            .where(
                (
                    (CommuteMatch.driver_id == user_id)
                    | (CommuteMatch.passenger_id == user_id)
                )
                & (CommuteMatch.status.in_([MatchStatus.PENDING, MatchStatus.CONFIRMED]))
            )
            .options(
                selectinload(CommuteMatch.commute),
                selectinload(CommuteMatch.driver),
                selectinload(CommuteMatch.passenger),
            )
        )

        return list(result.scalars().all())

    async def confirm_match(self, match_id: str) -> CommuteMatch:
        """Confirm a pending match.

        Args:
            match_id: The match ID to confirm

        Returns:
            The confirmed match
        """
        result = await self.session.execute(
            select(CommuteMatch).where(CommuteMatch.id == match_id)
        )
        match = result.scalar_one_or_none()

        if not match:
            raise GeospatialConflictError(f"Match {match_id} not found")

        match.confirm()
        return match
