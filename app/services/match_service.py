"""Civic-Link DPI - Matching Service

Implements the hard-reject safety logic at the database level.
CRITICAL: Gender safety filtering happens in SQL, not Python.
Every match state transition generates an encrypted audit log entry.
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Tuple

from geoalchemy2 import Geography
from geoalchemy2.shape import to_shape
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.sql import Select

from app.core.config import get_settings
from app.core.exceptions import CivicLinkSafetyException, GeospatialConflictError, InvalidStateTransitionError
from app.models.audit import AuditEventType, AuditEventSeverity
from app.models.commute import Commute, CommuteOffer, CommuteStatus
from app.models.match import CommuteMatch, MatchStatus
from app.models.user import Gender, User, VerificationStatus
from app.services.audit_service import AuditService

logger = logging.getLogger(__name__)
settings = get_settings()


class MatchingService:
    """Service for matching passengers with drivers.

    CRITICAL SAFETY: All matching queries include the mandatory
    hard-reject safety clause at the database level.
    """

    DEFAULT_RADIUS_METERS = 500
    TIME_WINDOW_MINUTES = 30

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def find_matching_commutes(
        self,
        offer: CommuteOffer,
        radius_meters: Optional[int] = None,
    ) -> List[Tuple[Commute, float]]:
        search_radius = radius_meters or self.DEFAULT_RADIUS_METERS

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
                AND (
                    ($1::boolean = FALSE OR UPPER(u.gender::text) = 'FEMALE')
                    AND
                    (c.is_women_only = FALSE OR UPPER($5::text) = 'FEMALE')
                )
                AND ST_DWithin(
                    c.origin::geography,
                    $7::geography,
                    $6
                )
            ORDER BY pickup_distance ASC
            LIMIT 50
        """

        offer_time = datetime.combine(
            offer.preferred_departure_date,
            offer.preferred_departure_time,
        )
        time_min = (offer_time - timedelta(minutes=self.TIME_WINDOW_MINUTES)).time()
        time_max = (offer_time + timedelta(minutes=self.TIME_WINDOW_MINUTES)).time()

        passenger_result = await self.session.execute(
            select(User.gender).where(User.id == offer.passenger_id)
        )
        passenger_gender = passenger_result.scalar()

        if passenger_gender is None:
            raise CivicLinkSafetyException("Passenger gender not found for safety check")

        origin_shape = to_shape(offer.origin)
        lon = origin_shape.x
        lat = origin_shape.y

        params = (
            offer.is_women_only,
            offer.preferred_departure_date,
            time_min,
            time_max,
            passenger_gender.value,
            search_radius,
            f"SRID=4326;POINT({lon} {lat})",
        )

        conn = await self.session.connection()
        result = await conn.exec_driver_sql(sql_str, params)

        rows = result.fetchall()

        if not rows:
            return []

        commute_ids = [row.commute_id for row in rows]
        commute_query = (
            select(Commute)
            .where(Commute.id.in_(commute_ids))
            .options(selectinload(Commute.driver))
        )

        commute_result = await self.session.execute(commute_query)
        commutes = {c.id: c for c in commute_result.scalars().all()}

        results = []
        for row in rows:
            commute = commutes.get(row.commute_id)
            if commute:
                results.append((commute, float(row.pickup_distance)))

        return results

    async def _check_safety_alert_needed(
        self,
        driver: User,
        passenger: User,
    ) -> Optional[Tuple[str, str]]:
        """Check if a safety alert should be logged for this match.

        Returns:
            Tuple of (alert_type, description) if alert needed, None otherwise.
        """
        from app.models.civic_score import CivicScore

        for user, role in [(driver, "driver"), (passenger, "passenger")]:
            if user.verification_status != VerificationStatus.VERIFIED:
                return (
                    "unverified_user_in_match",
                    f"{role.capitalize()} {user.id} is not verified (status: {user.verification_status.value})",
                )

            score_result = await self.session.execute(
                select(CivicScore).where(CivicScore.user_id == user.id)
            )
            score = score_result.scalar_one_or_none()
            if score and score.score < 40:
                return (
                    "low_civic_score",
                    f"{role.capitalize()} {user.id} has civic score {score.score} (threshold: 40)",
                )

        return None

    async def _log_audit(
        self,
        match: CommuteMatch,
        driver: User,
        passenger: User,
        event_type: AuditEventType,
        severity: AuditEventSeverity = AuditEventSeverity.INFO,
    ) -> None:
        """Log an audit entry for a match event. Non-blocking — failures are logged but do not roll back."""
        try:
            audit_service = AuditService(self.session)
            await audit_service.log_match_event(
                match_id=str(match.id),
                driver_id=driver.id if hasattr(driver, "id") else str(driver),
                passenger_id=passenger.id if hasattr(passenger, "id") else str(passenger),
                event_type=event_type,
                severity=severity,
                driver_gender=driver.gender.value if hasattr(driver, "gender") else None,
                passenger_gender=passenger.gender.value if hasattr(passenger, "gender") else None,
                commute_women_only=match.commute_was_women_only,
                offer_was_women_only=match.offer_was_women_only,
            )
        except Exception as e:
            logger.error("Audit log failed for match %s (%s): %s", match.id, event_type.value, e)

    async def _log_safety_alert(
        self,
        match: CommuteMatch,
        driver: User,
        passenger: User,
        alert_type: str,
        description: str,
    ) -> None:
        """Log a safety alert for a match. Non-blocking."""
        try:
            audit_service = AuditService(self.session)
            alert = await audit_service.log_safety_alert(
                audit_log_id=str(match.id),
                alert_type=alert_type,
                description=description,
                severity="warning",
                match_id=str(match.id),
                reported_user_id=None,
            )
            logger.info(
                "Safety alert logged for match %s: %s — %s",
                match.id,
                alert_type,
                description,
            )
        except Exception as e:
            logger.error("Safety alert log failed for match %s: %s", match.id, e)

    async def create_match(
        self,
        commute_id: str,
        passenger_id: str,
    ) -> CommuteMatch:
        commute_result = await self.session.execute(
            select(Commute)
            .where(Commute.id == commute_id)
            .options(selectinload(Commute.driver))
            .with_for_update()
        )
        commute = commute_result.scalar_one_or_none()

        if not commute:
            raise GeospatialConflictError(f"Commute {commute_id} not found")

        if commute.available_seats <= 0:
            raise GeospatialConflictError("Commute has no available seats")

        existing_match = await self.session.execute(
            select(CommuteMatch).where(
                (CommuteMatch.commute_id == commute_id)
                & (CommuteMatch.passenger_id == passenger_id)
                & (CommuteMatch.status.in_([MatchStatus.PENDING, MatchStatus.CONFIRMED]))
            )
        )
        if existing_match.scalar_one_or_none():
            raise GeospatialConflictError(
                f"Passenger {passenger_id} already has an active match for commute {commute_id}"
            )

        passenger_result = await self.session.execute(
            select(User).where(User.id == passenger_id)
        )
        passenger = passenger_result.scalar_one_or_none()

        if not passenger:
            raise CivicLinkSafetyException(f"Passenger {passenger_id} not found")

        if commute.is_women_only and passenger.gender != Gender.FEMALE:
            raise CivicLinkSafetyException(
                f"Safety violation: Women-only commute cannot match non-female passenger"
            )

        commute.decrement_seats()
        if commute.is_full:
            commute.status = CommuteStatus.COMPLETED

        match = CommuteMatch(
            commute_id=commute_id,
            driver_id=commute.driver_id,
            passenger_id=passenger_id,
            status=MatchStatus.PENDING,
            pickup_radius_meters=0,
            commute_was_women_only=commute.is_women_only,
            offer_was_women_only=False,
        )

        self.session.add(match)
        await self.session.flush()

        await self._log_audit(
            match=match,
            driver=commute.driver,
            passenger=passenger,
            event_type=AuditEventType.MATCH_CREATED,
        )

        safety_check = await self._check_safety_alert_needed(commute.driver, passenger)
        if safety_check:
            await self._log_safety_alert(
                match=match,
                driver=commute.driver,
                passenger=passenger,
                alert_type=safety_check[0],
                description=safety_check[1],
            )

        return match

    async def confirm_match(self, match_id: str) -> CommuteMatch:
        result = await self.session.execute(
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
            raise GeospatialConflictError(f"Match {match_id} not found")

        if match.status != MatchStatus.PENDING:
            raise InvalidStateTransitionError(
                current_state=match.status.value,
                attempted="confirm",
            )

        match.confirm()
        await self.session.flush()

        await self._log_audit(
            match=match,
            driver=match.driver,
            passenger=match.passenger,
            event_type=AuditEventType.MATCH_CONFIRMED,
        )

        return match

    async def start_match(self, match_id: str) -> CommuteMatch:
        result = await self.session.execute(
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
            raise GeospatialConflictError(f"Match {match_id} not found")

        if match.status != MatchStatus.CONFIRMED:
            raise InvalidStateTransitionError(
                current_state=match.status.value,
                attempted="start",
            )

        match.start()
        await self.session.flush()

        await self._log_audit(
            match=match,
            driver=match.driver,
            passenger=match.passenger,
            event_type=AuditEventType.MATCH_STARTED,
        )

        return match

    async def cancel_match(self, match_id: str) -> CommuteMatch:
        result = await self.session.execute(
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
            raise GeospatialConflictError(f"Match {match_id} not found")

        if match.status not in (MatchStatus.PENDING, MatchStatus.CONFIRMED):
            raise InvalidStateTransitionError(
                current_state=match.status.value,
                attempted="cancel",
            )

        match.cancel()

        if match.commute:
            match.commute.increment_seats()
            if match.commute.status == CommuteStatus.COMPLETED:
                match.commute.status = CommuteStatus.ACTIVE

        await self.session.flush()

        await self._log_audit(
            match=match,
            driver=match.driver,
            passenger=match.passenger,
            event_type=AuditEventType.MATCH_CANCELLED,
            severity=AuditEventSeverity.WARNING,
        )

        return match

    async def complete_match(self, match_id: str) -> CommuteMatch:
        result = await self.session.execute(
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
            raise GeospatialConflictError(f"Match {match_id} not found")

        if match.status != MatchStatus.IN_PROGRESS:
            raise InvalidStateTransitionError(
                current_state=match.status.value,
                attempted="complete",
            )

        match.complete()

        await self.session.flush()

        await self._log_audit(
            match=match,
            driver=match.driver,
            passenger=match.passenger,
            event_type=AuditEventType.MATCH_COMPLETED,
        )

        return match

    async def get_active_matches_for_user(
        self,
        user_id: str,
    ) -> List[CommuteMatch]:
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
