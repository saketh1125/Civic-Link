"""Civic-Link DPI - User Model

User entity with corporate email validation and gender fields
for the safety-critical women-only commute matching.
"""

from datetime import datetime, timezone
from enum import Enum as PyEnum
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import DateTime, Enum, Index, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseModel

if TYPE_CHECKING:
    from app.models.civic_score import CivicScore
    from app.models.commute import Commute, CommuteOffer
    from app.models.match import CommuteMatch


class UserRole(str, PyEnum):
    """User roles in the system."""

    COMMUTER = "commuter"
    ADMIN = "admin"
    MODERATOR = "moderator"


class Gender(str, PyEnum):
    """Gender options for safety-critical matching.

    CRITICAL: Only 'female' is checked for women-only safety logic.
    'undisclosed' is treated as non-female for safety purposes.
    """

    MALE = "male"
    FEMALE = "female"
    UNDISCLOSED = "undisclosed"


class VerificationStatus(str, PyEnum):
    """Corporate email verification status."""

    PENDING = "pending"
    VERIFIED = "verified"
    REJECTED = "rejected"


class User(BaseModel):
    """User model with corporate email and gender for safety matching.

    Attributes:
        email: Corporate email (hashed for privacy)
        email_domain: Domain for filtering (e.g., "company.com")
        email_hash: Hashed email for deduplication
        gender: Gender for women-only matching safety logic
        phone_number: Verified phone number
        full_name: User's full name
        employee_id: Optional corporate employee ID
        company_name: Corporate name
        is_verified: Email verification status
        last_login: Last successful login timestamp
        role: User role in the system
    """

    __tablename__ = "users"

    # Contact Information (Privacy-Enhanced)
    email_hash: Mapped[str] = mapped_column(
        String(64),
        unique=True,
        index=True,
        nullable=False,
        comment="SHA-256 hash of corporate email for deduplication",
    )
    email_domain: Mapped[str] = mapped_column(
        String(255),
        index=True,
        nullable=False,
        comment="Email domain for corporate filtering",
    )
    phone_number: Mapped[str] = mapped_column(
        String(20),
        unique=True,
        index=True,
        nullable=False,
    )

    # Personal Information
    full_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    gender: Mapped[Gender] = mapped_column(
        Enum(Gender, name="gender_enum"),
        nullable=False,
        index=True,
        comment="Gender for women-only commute safety matching",
    )

    # Corporate Information
    employee_id: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        comment="Optional corporate employee ID",
    )
    company_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
    )

    # Verification & Status
    verification_status: Mapped[VerificationStatus] = mapped_column(
        Enum(VerificationStatus, name="verification_status_enum"),
        default=VerificationStatus.PENDING,
        nullable=False,
    )
    last_login: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole, name="user_role_enum"),
        default=UserRole.COMMUTER,
        nullable=False,
    )

    # Security
    password_hash: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        comment="Bcrypt hashed password",
    )

    # Relationships
    offered_commutes: Mapped[List["Commute"]] = relationship(
        "Commute",
        back_populates="driver",
        foreign_keys="Commute.driver_id",
        lazy="selectin",
    )
    matched_commutes: Mapped[List["CommuteMatch"]] = relationship(
        "CommuteMatch",
        back_populates="passenger",
        foreign_keys="CommuteMatch.passenger_id",
        lazy="selectin",
    )
    drive_matches: Mapped[List["CommuteMatch"]] = relationship(
        "CommuteMatch",
        back_populates="driver",
        foreign_keys="CommuteMatch.driver_id",
        lazy="selectin",
    )
    commute_offers: Mapped[List["CommuteOffer"]] = relationship(
        "CommuteOffer",
        back_populates="passenger",
        lazy="selectin",
    )
    civic_scores: Mapped[List["CivicScore"]] = relationship(
        "CivicScore",
        back_populates="user",
        lazy="selectin",
    )

    # Indexes
    __table_args__ = (
        Index("ix_users_company_gender", "company_name", "gender"),
        Index("ix_users_verified_domain", "verification_status", "email_domain"),
    )

    @property
    def is_female(self) -> bool:
        """Convenience property for safety logic."""
        return self.gender == Gender.FEMALE

    @property
    def is_verified(self) -> bool:
        """Check if user email is verified."""
        return self.verification_status == VerificationStatus.VERIFIED

    def update_last_login(self) -> None:
        """Update last login timestamp."""
        self.last_login = datetime.now(timezone.utc)
