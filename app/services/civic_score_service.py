"""Civic-Link DPI - Civic Score Service

Civic score retrieval, calculation, and history tracking.
"""

from datetime import datetime
from typing import List, Optional

import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.audit import AuditEventType, AuditEventSeverity
from app.models.civic_score import CivicScore, CivicScoreHistory
from app.services.audit_service import AuditService

logger = structlog.get_logger()


class CivicScoreService:
    """Service for civic score management."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_score_for_user(self, user_id: str) -> Optional[CivicScore]:
        """Retrieve the civic score for a user.

        Args:
            user_id: The user's UUID

        Returns:
            CivicScore if found, None otherwise
        """
        result = await self.session.execute(
            select(CivicScore).where(CivicScore.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def create_score_for_user(self, user_id: str) -> CivicScore:
        """Create a new civic score record for a user.

        Args:
            user_id: The user's UUID

        Returns:
            Created CivicScore (starts at 100.0)
        """
        score = CivicScore(user_id=user_id, score=100.0)
        self.session.add(score)
        await self.session.flush()
        return score

    async def get_or_create_score(self, user_id: str) -> CivicScore:
        """Get existing score or create one if not found.

        Args:
            user_id: The user's UUID

        Returns:
            Existing or newly created CivicScore
        """
        score = await self.get_score_for_user(user_id)
        if score is None:
            score = await self.create_score_for_user(user_id)
            try:
                audit = AuditService(self.session)
                await audit.log_match_event(
                    driver_id=user_id,
                    event_type=AuditEventType.SCORE_INITIALIZED,
                    severity=AuditEventSeverity.INFO,
                )
            except Exception as audit_err:
                logger.error("Audit logging failed for score initialization", error=str(audit_err))
        return score

    async def update_score_from_telemetry(
        self,
        user_id: str,
        swerve_detected: bool = False,
        speeding_detected: bool = False,
        hard_brake_detected: bool = False,
        rapid_accel_detected: bool = False,
    ) -> CivicScore:
        """Update civic score based on telemetry events.

        Args:
            user_id: The user's UUID
            swerve_detected: Whether a swerve was detected
            speeding_detected: Whether speeding was detected
            hard_brake_detected: Whether hard braking was detected
            rapid_accel_detected: Whether rapid acceleration was detected

        Returns:
            Updated CivicScore
        """
        score = await self.get_or_create_score(user_id)

        old_score = score.score

        score.update_from_telemetry(
            swerve_detected=swerve_detected,
            speeding_detected=speeding_detected,
            hard_brake_detected=hard_brake_detected,
            rapid_accel_detected=rapid_accel_detected,
        )

        await self.session.flush()

        await self._record_history(
            civic_score_id=score.id,
            old_score=old_score,
            new_score=score.score,
            trigger_event="telemetry_update",
            swerve_count=score.swerve_count,
            speeding_count=score.speeding_count,
        )

        return score

    async def ingest_telemetry_samples(
        self,
        user_id: str,
        samples: list[dict],
        trip_id: str | None = None,
    ) -> tuple[CivicScore, float]:
        """Ingest raw telemetry samples and calculate weighted penalty score.

        Args:
            user_id: The user's UUID
            samples: List of telemetry sample dicts
            trip_id: Optional trip identifier

        Returns:
            Tuple of (updated CivicScore, score_delta)
        """
        score = await self.get_or_create_score(user_id)
        old_score = score.score

        new_score = score.calculate_weighted_score(samples)
        delta = new_score - old_score
        score.score = new_score
        score.last_calculated_at = datetime.now()

        await self.session.flush()

        await self._record_history(
            civic_score_id=score.id,
            old_score=old_score,
            new_score=score.score,
            trigger_event="sample_ingestion",
            swerve_count=score.swerve_count,
            speeding_count=score.speeding_count,
            match_id=trip_id,
        )

        try:
            audit = AuditService(self.session)
            await audit.log_match_event(
                driver_id=user_id,
                event_type=AuditEventType.SCORE_UPDATED,
                severity=AuditEventSeverity.INFO,
            )
        except Exception as audit_err:
            logger.error("Audit logging failed for score update", error=str(audit_err))

        return score, delta

    async def record_trip_completion(
        self,
        user_id: str,
        distance_km: float,
        duration_hours: float,
    ) -> CivicScore:
        """Record a completed trip and update statistics.

        Args:
            user_id: The user's UUID
            distance_km: Distance driven in kilometers
            duration_hours: Trip duration in hours

        Returns:
            Updated CivicScore
        """
        score = await self.get_or_create_score(user_id)
        old_score = score.score

        score.record_trip(distance_km=distance_km, duration_hours=duration_hours)

        await self.session.flush()

        await self._record_history(
            civic_score_id=score.id,
            old_score=old_score,
            new_score=score.score,
            trigger_event="trip_completion",
            swerve_count=score.swerve_count,
            speeding_count=score.speeding_count,
        )

        try:
            audit = AuditService(self.session)
            await audit.log_match_event(
                driver_id=user_id,
                event_type=AuditEventType.TRIP_COMPLETED,
                severity=AuditEventSeverity.INFO,
            )
        except Exception as audit_err:
            logger.error("Audit logging failed for trip completion", error=str(audit_err))

        return score

    async def get_score_history(
        self,
        user_id: str,
        limit: int = 50,
    ) -> List[CivicScoreHistory]:
        """Retrieve score change history for a user.

        Args:
            user_id: The user's UUID
            limit: Maximum number of history entries to return

        Returns:
            List of CivicScoreHistory entries, newest first
        """
        result = await self.session.execute(
            select(CivicScoreHistory)
            .join(CivicScore, CivicScoreHistory.civic_score_id == CivicScore.id)
            .where(CivicScore.user_id == user_id)
            .order_by(CivicScoreHistory.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def _record_history(
        self,
        civic_score_id: str,
        old_score: float,
        new_score: float,
        trigger_event: str,
        swerve_count: int,
        speeding_count: int,
        match_id: Optional[str] = None,
    ) -> None:
        """Record a score change in the history table.

        Args:
            civic_score_id: The civic score UUID
            old_score: Score before change
            new_score: Score after change
            trigger_event: What triggered the change
            swerve_count: Swerve count at time of change
            speeding_count: Speeding count at time of change
            match_id: Optional associated match ID
        """
        history = CivicScoreHistory(
            civic_score_id=civic_score_id,
            old_score=old_score,
            new_score=new_score,
            trigger_event=trigger_event,
            match_id=match_id,
            swerve_count_at_time=swerve_count,
            speeding_count_at_time=speeding_count,
            calculation_version="1.0",
        )
        self.session.add(history)
