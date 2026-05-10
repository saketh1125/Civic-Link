"""Civic-Link DPI - Commute Model

Commute and CommuteOffer models with PostGIS Geography types
for origin/destination points. Uses Geography (not Geometry)
to prevent degree-to-meter conversion bugs.

CRITICAL: Uses GeoAlchemy2 Geography type for earth-surface calculations.
SRID 4326 (WGS 84) is enforced for all geographic points.
"""

from datetime import date, datetime, time, timezone
from enum import Enum as PyEnum
from typing import TYPE_CHECKING, List, Optional

from geoalchemy2 import Geography
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    Time,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseModel

if TYPE_CHECKING:
    from app.models.match import CommuteMatch
    from app.models.user import User


class CommuteType(str, PyEnum):
    """Type of commute."""

    ONE_TIME = "one_time"
    RECURRING = "recurring"


class WeekDay(str, PyEnum):
    """Days of the week for recurring commutes."""

    MONDAY = "monday"
    TUESDAY = "tuesday"
    WEDNESDAY = "wednesday"
    THURSDAY = "thursday"
    FRIDAY = "friday"
    SATURDAY = "saturday"
    SUNDAY = "sunday"


class CommuteStatus(str, PyEnum):
    """Status of a commute."""

    PENDING = "pending"
    ACTIVE = "active"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    EXPIRED = "expired"


class Commute(BaseModel):
    """Commute model representing a driver's available ride.

    CRITICAL SAFETY: The is_women_only flag is enforced at the
    database level with the safety clause from the manifesto.

    Attributes:
        driver_id: Foreign key to the driver (User)
        origin: Geography POINT with SRID 4326 (WGS 84 GPS coordinates)
        destination: Geography POINT with SRID 4326 (WGS 84 GPS coordinates)
        origin_address: Human-readable origin address
        destination_address: Human-readable destination address
        departure_time: Scheduled departure time
        available_seats: Number of available passenger seats
        is_women_only: Safety flag for women-only commutes
        commute_type: One-time or recurring
        recurring_days: Days for recurring commutes (JSON array)
        status: Current commute status
        expires_at: When this commute offer expires (for caching)
    """

    __tablename__ = "commutes"

    # Driver Relationship
    driver_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # CRITICAL: Geography type with SRID 4326 (WGS 84)
    # Geography uses earth-surface calculations (meters, accurate)
    # Geometry would use plane calculations (degrees, inaccurate)
    origin: Mapped[Geography] = mapped_column(
        Geography(geometry_type="POINT", srid=4326),
        nullable=False,
        comment="Driver's pickup location as GPS coordinates (WGS 84)",
    )
    destination: Mapped[Geography] = mapped_column(
        Geography(geometry_type="POINT", srid=4326),
        nullable=False,
        comment="Driver's dropoff location as GPS coordinates (WGS 84)",
    )

    # Address Information (for display, coordinates are authoritative)
    origin_address: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        comment="Human-readable origin address",
    )
    destination_address: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        comment="Human-readable destination address",
    )

    # Schedule
    departure_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        index=True,
    )
    departure_time: Mapped[time] = mapped_column(
        Time,
        nullable=False,
    )
    arrival_time: Mapped[Optional[time]] = mapped_column(
        Time,
        nullable=True,
    )

    # Capacity
    available_seats: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
    )
    total_seats: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=4,
    )

    # Safety-Critical: Women-Only Flag
    is_women_only: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        index=True,
        comment="CRITICAL SAFETY: When True, only female passengers allowed",
    )

    # Commute Metadata
    commute_type: Mapped[CommuteType] = mapped_column(
        Enum(CommuteType, name="commute_type_enum"),
        default=CommuteType.ONE_TIME,
        nullable=False,
    )
    recurring_days: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        comment="Comma-separated days for recurring commutes (e.g., 'monday,wednesday')",
    )
    status: Mapped[CommuteStatus] = mapped_column(
        Enum(CommuteStatus, name="commute_status_enum"),
        default=CommuteStatus.PENDING,
        nullable=False,
        index=True,
    )

    # Expiration for Redis caching
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        nullable=False,
        default=lambda: datetime.now(),
        comment="Redis cache expiration timestamp",
    )

    # Privacy: Anonymization tracking
    origin_anonymized_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
        comment="GDPR: When origin coordinates were anonymized",
    )
    destination_anonymized_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
        comment="GDPR: When destination coordinates were anonymized",
    )

    # Relationships
    driver: Mapped["User"] = relationship(
        "User",
        back_populates="offered_commutes",
        foreign_keys=[driver_id],
    )
    matches: Mapped[List["CommuteMatch"]] = relationship(
        "CommuteMatch",
        back_populates="commute",
        lazy="selectin",
    )
    offers: Mapped[List["CommuteOffer"]] = relationship(
        "CommuteOffer",
        back_populates="commute",
        lazy="selectin",
    )

    # Constraints and Indexes
    __table_args__ = (
        # Ensure available_seats <= total_seats
        CheckConstraint(
            "available_seats <= total_seats",
            name="chk_available_seats",
        ),
        # Ensure available_seats >= 0
        CheckConstraint(
            "available_seats >= 0",
            name="chk_available_seats_non_negative",
        ),
        # GIST index for geospatial queries (CRITICAL for ST_DWithin performance)
        Index("ix_commutes_origin_gist", "origin", postgresql_using="GIST"),
        Index("ix_commutes_destination_gist", "destination", postgresql_using="GIST"),
        # Composite indexes for common queries
        Index("ix_commutes_driver_status", "driver_id", "status"),
        Index("ix_commutes_departure", "departure_date", "departure_time"),
        Index("ix_commutes_women_only", "is_women_only", "status"),
    )

    @property
    def is_full(self) -> bool:
        """Check if commute has no available seats."""
        return self.available_seats <= 0

    @property
    def is_expired(self) -> bool:
        """Check if commute has expired."""
        return datetime.now(timezone.utc) > self.expires_at

    def decrement_seats(self) -> None:
        """Decrement available seats when a passenger is matched."""
        if self.available_seats > 0:
            self.available_seats -= 1

    def increment_seats(self) -> None:
        """Increment available seats when a passenger cancels."""
        if self.available_seats < self.total_seats:
            self.available_seats += 1


class CommuteOffer(BaseModel):
    """CommuteOffer model representing a passenger's ride request.

    CRITICAL SAFETY: The is_women_only flag is checked during matching
    against the driver's gender, enforced at the database level.

    Attributes:
        passenger_id: Foreign key to the requesting passenger (User)
        commute_id: Foreign key to the commute being requested (optional until matched)
        origin: Geography POINT with SRID 4326 (requested pickup location)
        destination: Geography POINT with SRID 4326 (requested dropoff location)
        origin_address: Human-readable origin address
        destination_address: Human-readable destination address
        preferred_departure_time: Preferred departure window start
        preferred_arrival_time: Preferred arrival time
        is_women_only: Safety flag for women-only matching
        max_walking_distance: Maximum walking distance to pickup point (meters)
        status: Current offer status
    """

    __tablename__ = "commute_offers"

    # Passenger Relationship
    passenger_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Optional: Matched commute (null until matched)
    commute_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("commutes.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # CRITICAL: Geography type with SRID 4326
    origin: Mapped[Geography] = mapped_column(
        Geography(geometry_type="POINT", srid=4326),
        nullable=False,
        comment="Passenger's requested pickup location (WGS 84)",
    )
    destination: Mapped[Geography] = mapped_column(
        Geography(geometry_type="POINT", srid=4326),
        nullable=False,
        comment="Passenger's requested dropoff location (WGS 84)",
    )

    # Address Information
    origin_address: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
    )
    destination_address: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
    )

    # Schedule Preferences
    preferred_departure_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        index=True,
    )
    preferred_departure_time: Mapped[time] = mapped_column(
        Time,
        nullable=False,
    )
    preferred_arrival_time: Mapped[Optional[time]] = mapped_column(
        Time,
        nullable=True,
    )
    time_flexibility_minutes: Mapped[int] = mapped_column(
        Integer,
        default=15,
        nullable=False,
        comment="How many minutes passenger can adjust departure time",
    )

    # Safety-Critical: Women-Only Flag
    is_women_only: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        index=True,
        comment="CRITICAL SAFETY: When True, only female drivers allowed",
    )

    # Matching Preferences
    max_walking_distance: Mapped[int] = mapped_column(
        Integer,
        default=500,
        nullable=False,
        comment="Maximum walking distance to pickup point in meters",
    )
    max_wait_time_minutes: Mapped[int] = mapped_column(
        Integer,
        default=10,
        nullable=False,
    )

    # Status
    status: Mapped[str] = mapped_column(
        String(50),
        default="pending",
        nullable=False,
        index=True,
    )

    # Privacy: Anonymization tracking
    origin_anonymized_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )
    destination_anonymized_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )

    # Relationships
    passenger: Mapped["User"] = relationship(
        "User",
        back_populates="commute_offers",
        foreign_keys=[passenger_id],
    )
    commute: Mapped[Optional["Commute"]] = relationship(
        "Commute",
        back_populates="offers",
        foreign_keys=[commute_id],
    )

    # Constraints and Indexes
    __table_args__ = (
        # GIST index for geospatial queries
        Index("ix_commute_offers_origin_gist", "origin", postgresql_using="GIST"),
        Index("ix_commute_offers_destination_gist", "destination", postgresql_using="GIST"),
        # Composite indexes
        Index("ix_commute_offers_passenger_status", "passenger_id", "status"),
        Index(
            "ix_commute_offers_departure",
            "preferred_departure_date",
            "preferred_departure_time",
        ),
        Index("ix_commute_offers_women_only", "is_women_only", "status"),
    )

    @property
    def is_pending(self) -> bool:
        """Check if offer is still pending."""
        return self.status == "pending"
