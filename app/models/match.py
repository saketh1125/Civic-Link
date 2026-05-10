"""Civic-Link DPI - CommuteMatch Model

Match model representing a successful pairing between a driver and passenger.
CRITICAL: Every match must generate an encrypted CommuteAuditLog entry.
"""

from datetime import datetime, timezone
from enum import Enum as PyEnum
from typing import TYPE_CHECKING, Optional

from sqlalchemy import (
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseModel

if TYPE_CHECKING:
    from app.models.commute import Commute
    from app.models.user import User


class MatchStatus(str, PyEnum):
    """Status of a commute match."""

    PENDING = "pending"
    CONFIRMED = "confirmed"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    NO_SHOW = "no_show"


class PaymentStatus(str, PyEnum):
    """Status of payment for the match."""

    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"
    REFUNDED = "refunded"


class CommuteMatch(BaseModel):
    """Match model for driver-passenger pairing.

    CRITICAL SAFETY: The match respects the women-only flags from both
    Commute and CommuteOffer, enforced at the database level.

    Attributes:
        commute_id: Foreign key to the matched Commute
        driver_id: Foreign key to the driver (User) - denormalized for safety queries
        passenger_id: Foreign key to the passenger (User)
        status: Current match status
        confirmed_at: When the match was confirmed
        completed_at: When the commute was completed
        pickup_radius: Distance from passenger origin to driver pickup (meters)
        fare_amount: Calculated fare for the ride
        payment_status: Payment processing status
        driver_rating: Passenger's rating of the driver
        passenger_rating: Driver's rating of the passenger
    """

    __tablename__ = "commute_matches"

    # Primary References
    commute_id: Mapped[str] = mapped_column(
        ForeignKey("commutes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Denormalized for safety queries (avoids joins for gender safety clause)
    driver_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    passenger_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Match Status
    status: Mapped[MatchStatus] = mapped_column(
        Enum(MatchStatus, name="match_status_enum"),
        default=MatchStatus.PENDING,
        nullable=False,
        index=True,
    )

    # Timestamps
    confirmed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )
    started_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )
    completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )

    # Geospatial Data (snapshot at match time)
    pickup_radius_meters: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="Distance from passenger to driver pickup point",
    )
    dropoff_radius_meters: Mapped[Optional[int]] = mapped_column(
        Integer,
        nullable=True,
        comment="Distance from driver dropoff to passenger destination",
    )

    # Financial
    fare_amount: Mapped[Optional[float]] = mapped_column(
        Numeric(10, 2),
        nullable=True,
        comment="Calculated ride fare in local currency",
    )
    payment_status: Mapped[PaymentStatus] = mapped_column(
        Enum(PaymentStatus, name="payment_status_enum"),
        default=PaymentStatus.PENDING,
        nullable=False,
    )

    # Ratings (collected post-ride)
    driver_rating: Mapped[Optional[int]] = mapped_column(
        Integer,
        nullable=True,
        comment="Passenger's rating of driver (1-5)",
    )
    driver_review: Mapped[Optional[str]] = mapped_column(
        String(1000),
        nullable=True,
    )
    passenger_rating: Mapped[Optional[int]] = mapped_column(
        Integer,
        nullable=True,
        comment="Driver's rating of passenger (1-5)",
    )
    passenger_review: Mapped[Optional[str]] = mapped_column(
        String(1000),
        nullable=True,
    )

    # Safety flags at match time (for audit trail)
    commute_was_women_only: Mapped[bool] = mapped_column(
        default=False,
        nullable=False,
        comment="Snapshot of Commute.is_women_only at match time",
    )
    offer_was_women_only: Mapped[bool] = mapped_column(
        default=False,
        nullable=False,
        comment="Snapshot of CommuteOffer.is_women_only at match time",
    )

    # Audit trail reference
    audit_log_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        nullable=True,
        comment="Reference to encrypted CommuteAuditLog entry",
    )

    # Privacy: Anonymization tracking
    anonymized_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
        comment="GDPR: When PII in this match was anonymized",
    )

    # Relationships
    commute: Mapped["Commute"] = relationship(
        "Commute",
        back_populates="matches",
        foreign_keys=[commute_id],
    )
    driver: Mapped["User"] = relationship(
        "User",
        back_populates="drive_matches",
        foreign_keys=[driver_id],
    )
    passenger: Mapped["User"] = relationship(
        "User",
        back_populates="matched_commutes",
        foreign_keys=[passenger_id],
    )

    # Indexes
    __table_args__ = (
        Index("ix_matches_commute_status", "commute_id", "status"),
        Index("ix_matches_driver_status", "driver_id", "status"),
        Index("ix_matches_passenger_status", "passenger_id", "status"),
        Index("ix_matches_completed", "completed_at", "status"),
    )

    def confirm(self) -> None:
        """Mark match as confirmed."""
        self.status = MatchStatus.CONFIRMED
        self.confirmed_at = datetime.now()

    def start(self) -> None:
        """Mark match as in progress."""
        self.status = MatchStatus.IN_PROGRESS
        self.started_at = datetime.now()

    def complete(self) -> None:
        """Mark match as completed."""
        self.status = MatchStatus.COMPLETED
        self.completed_at = datetime.now()

    def cancel(self) -> None:
        """Mark match as cancelled."""
        self.status = MatchStatus.CANCELLED
        self.cancelled_at = datetime.now()
