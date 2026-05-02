"""Civic-Link DPI - Civic Score Model

Civic scoring for drivers based on telemetry data.
Tracks lane-cutting (gyro_z > 1.5 rad/s) and other driving behaviors.
"""

from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional

from sqlalchemy import (
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseModel

if TYPE_CHECKING:
    from app.models.user import User


class CivicScore(BaseModel):
    """Civic score tracking for driver behavior.

    Implements the Civic Engine telemetry logic from the manifesto:
    - Tracks gyro_z for lane-cutting detection
    - Trigger: abs(gyro_z) > 1.5 rad/s
    - Cooldown: 60,000ms (1 minute) debounce
    - Scoring Formula:
      S_new = (S_old × 0.85) + (max(0, 100 - (n_swerves × 5) - P_speeding) × 0.15)

    Attributes:
        user_id: Foreign key to the driver (User)
        score: Current civic score (0-100)
        total_trips: Total number of completed trips
        total_distance_km: Total distance driven
        swerve_count: Count of lane-cutting events
        speeding_count: Count of speeding events
        hard_braking_count: Count of hard braking events
        last_swerve_at: Timestamp of last detected lane-cut
    """

    __tablename__ = "civic_scores"

    # User Relationship
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )

    # Current Score
    score: Mapped[float] = mapped_column(
        Float,
        default=100.0,
        nullable=False,
        comment="Current civic score 0-100, calculated from telemetry",
    )

    # Trip Statistics
    total_trips: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    total_distance_km: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
    )
    total_driving_hours: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
    )

    # Telemetry Event Counts
    swerve_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
        comment="Lane-cutting events (gyro_z > 1.5 rad/s)",
    )
    speeding_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    hard_braking_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    rapid_acceleration_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    # Last Event Timestamps (for cooldown logic)
    last_swerve_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    last_speeding_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    last_hard_brake_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Score Components (stored for transparency)
    swerve_penalty: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
        comment="Penalty points from swerve events",
    )
    speeding_penalty: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
        comment="Penalty points from speeding events",
    )

    # Score History (last calculated values)
    last_calculated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    calculation_version: Mapped[str] = mapped_column(
        String(10),
        default="1.0",
        nullable=False,
        comment="Version of scoring formula used",
    )

    # Relationship
    user: Mapped["User"] = relationship(
        "User",
        back_populates="civic_scores",
        foreign_keys=[user_id],
    )

    # Indexes
    __table_args__ = (
        Index("ix_civic_scores_score", "score"),
        Index("ix_civic_scores_swerves", "swerve_count", "score"),
    )

    def calculate_score(self, new_swerves: int = 0, new_speeding: int = 0) -> float:
        """Calculate new civic score using the manifesto formula.

        Formula: S_new = (S_old × 0.85) + (max(0, 100 - (n_swerves × 5) - P_speeding) × 0.15)

        Args:
            new_swerves: Number of new swerve events to factor in
            new_speeding: Number of new speeding events to factor in

        Returns:
            New calculated score (0-100)
        """
        old_score = self.score

        # Update counts
        total_swerves = self.swerve_count + new_swerves
        total_speeding = self.speeding_count + new_speeding

        # Calculate penalties
        swerve_penalty = total_swerves * 5.0
        speeding_penalty = total_speeding * 10.0  # Speeding penalized more

        # Calculate new base score
        base_score = max(0.0, 100.0 - swerve_penalty - speeding_penalty)

        # Apply weighted formula
        new_score = (old_score * 0.85) + (base_score * 0.15)

        # Clamp to valid range
        return max(0.0, min(100.0, new_score))

    def update_from_telemetry(
        self,
        swerve_detected: bool = False,
        speeding_detected: bool = False,
        hard_brake_detected: bool = False,
        rapid_accel_detected: bool = False,
    ) -> None:
        """Update score from telemetry data with debounce logic.

        Args:
            swerve_detected: Whether a swerve was detected this reading
            speeding_detected: Whether speeding was detected
            hard_brake_detected: Whether hard braking was detected
            rapid_accel_detected: Whether rapid acceleration was detected
        """
        now = datetime.now(timezone.utc)
        cooldown_ms = 60000  # 1 minute debounce per manifesto

        # Check cooldown before counting swerve
        if swerve_detected:
            if self.last_swerve_at is None:
                can_count_swerve = True
            else:
                elapsed_ms = (now - self.last_swerve_at).total_seconds() * 1000
                can_count_swerve = elapsed_ms >= cooldown_ms

            if can_count_swerve:
                self.swerve_count += 1
                self.last_swerve_at = now
                self.swerve_penalty = self.swerve_count * 5.0

        if speeding_detected:
            self.speeding_count += 1
            self.last_speeding_at = now
            self.speeding_penalty = self.speeding_count * 10.0

        if hard_brake_detected:
            self.hard_braking_count += 1
            self.last_hard_brake_at = now

        if rapid_accel_detected:
            self.rapid_acceleration_count += 1

        # Recalculate score
        self.score = self.calculate_score()
        self.last_calculated_at = now

    def record_trip(self, distance_km: float, duration_hours: float) -> None:
        """Record a completed trip."""
        self.total_trips += 1
        self.total_distance_km += distance_km
        self.total_driving_hours += duration_hours

    @property
    def score_tier(self) -> str:
        """Get score tier for display/matching priority."""
        if self.score >= 90:
            return "excellent"
        elif self.score >= 75:
            return "good"
        elif self.score >= 60:
            return "fair"
        elif self.score >= 40:
            return "poor"
        else:
            return "critical"


class CivicScoreHistory(BaseModel):
    """Historical record of civic score changes.

    Maintains audit trail of score calculations.
    """

    __tablename__ = "civic_score_history"

    civic_score_id: Mapped[str] = mapped_column(
        ForeignKey("civic_scores.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    old_score: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )
    new_score: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # What triggered the change
    trigger_event: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="Event type that triggered recalculation",
    )
    match_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        nullable=True,
        comment="Associated match if triggered by trip completion",
    )

    # Component values at calculation time
    swerve_count_at_time: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    speeding_count_at_time: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    calculation_version: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
    )

    # Indexes
    __table_args__ = (
        Index("ix_civic_history_score_change", "civic_score_id", "created_at"),
    )
