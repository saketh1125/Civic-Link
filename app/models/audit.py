"""Civic-Link DPI - Audit Log Models

Encrypted audit logging for all matches between drivers and passengers.
Required for safety compliance and regulatory reporting.
"""

from datetime import datetime, timezone
from enum import Enum as PyEnum
from typing import TYPE_CHECKING, Optional

from sqlalchemy import (
    DateTime,
    Enum,
    ForeignKey,
    Index,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseModel

if TYPE_CHECKING:
    from app.models.user import User


class AuditEventType(str, PyEnum):
    """Types of audit events."""

    MATCH_CREATED = "match_created"
    MATCH_CONFIRMED = "match_confirmed"
    MATCH_STARTED = "match_started"
    MATCH_COMPLETED = "match_completed"
    MATCH_CANCELLED = "match_cancelled"
    SAFETY_ALERT = "safety_alert"
    GENDER_MISMATCH_BLOCKED = "gender_mismatch_blocked"
    DATA_ANONYMIZED = "data_anonymized"
    TELEMETRY_SWERVE = "telemetry_swerve"
    TELEMETRY_SPEEDING = "telemetry_speeding"
    USER_REPORTED = "user_reported"
    COMMUTE_CREATED = "commute_created"
    COMMUTE_CANCELLED = "commute_cancelled"
    OFFER_CREATED = "offer_created"
    OFFER_CANCELLED = "offer_cancelled"
    ADMIN_PROMOTED = "admin_promoted"
    USER_VERIFIED = "user_verified"
    SCORE_UPDATED = "score_updated"
    TRIP_COMPLETED = "trip_completed"
    SCORE_INITIALIZED = "score_initialized"


class AuditEventSeverity(str, PyEnum):
    """Severity levels for audit events."""

    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


class CommuteAuditLog(BaseModel):
    """Encrypted audit log for commute matches.

    CRITICAL: Every match between a driver and passenger MUST generate
    an encrypted audit log entry. This is mandatory per the manifesto.

    The encrypted_payload field contains sensitive match data encrypted
    with AES-256-GCM using the AUDIT_LOG_ENCRYPTION_KEY.

    Attributes:
        match_id: Reference to the CommuteMatch (if applicable)
        driver_id: Foreign key to the driver (User)
        passenger_id: Foreign key to the passenger (User)
        event_type: Type of audit event
        severity: Event severity level
        encrypted_payload: AES-256-GCM encrypted event data
        encryption_iv: Initialization vector for decryption
        occurred_at: When the event occurred
        ip_address: IP address of the triggering action (optional)
        user_agent: User agent of the triggering action (optional)
    """

    __tablename__ = "commute_audit_logs"

    # References (nullable for events not tied to a specific match)
    match_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        nullable=True,
        index=True,
    )
    driver_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    passenger_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Event Details
    event_type: Mapped[AuditEventType] = mapped_column(
        Enum(AuditEventType, name="audit_event_type_enum"),
        nullable=False,
        index=True,
    )
    severity: Mapped[AuditEventSeverity] = mapped_column(
        Enum(AuditEventSeverity, name="audit_event_severity_enum"),
        default=AuditEventSeverity.INFO,
        nullable=False,
        index=True,
    )

    # Encrypted Payload
    encrypted_payload: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="AES-256-GCM encrypted JSON event data (Base64 encoded)",
    )
    encryption_iv: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        comment="Initialization vector for AES decryption (hex encoded)",
    )
    encryption_version: Mapped[str] = mapped_column(
        String(10),
        default="v1",
        nullable=False,
        comment="Encryption scheme version for future migrations",
    )

    # Context
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )
    ip_address: Mapped[Optional[str]] = mapped_column(
        String(45),  # IPv6 max length
        nullable=True,
    )
    user_agent: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
    )

    # Safety-critical flags logged at event time
    driver_gender_at_time: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="Driver gender at time of event (for safety audit)",
    )
    passenger_gender_at_time: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="Passenger gender at time of event (for safety audit)",
    )
    commute_women_only_at_time: Mapped[bool] = mapped_column(
        default=False,
        nullable=False,
    )
    offer_women_only_at_time: Mapped[bool] = mapped_column(
        default=False,
        nullable=False,
    )

    # Compliance
    retention_until: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="GDPR/RTI: When this log can be purged",
    )
    purged_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    driver: Mapped[Optional["User"]] = relationship(
        "User",
        foreign_keys=[driver_id],
    )
    passenger: Mapped[Optional["User"]] = relationship(
        "User",
        foreign_keys=[passenger_id],
    )

    # Indexes for compliance queries
    __table_args__ = (
        Index("ix_audit_logs_event_occurred", "event_type", "occurred_at"),
        Index("ix_audit_logs_severity_occurred", "severity", "occurred_at"),
        Index("ix_audit_logs_retention", "retention_until", "purged_at"),
        Index("ix_audit_logs_match_event", "match_id", "event_type"),
    )


class SafetyAlertLog(BaseModel):
    """Specific audit log for safety-related alerts.

    Separate table for faster querying of safety incidents.
    """

    __tablename__ = "safety_alert_logs"

    # References
    audit_log_id: Mapped[str] = mapped_column(
        ForeignKey("commute_audit_logs.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    match_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        nullable=True,
        index=True,
    )
    reporter_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    reported_user_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Alert Details
    alert_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
    )
    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    severity: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        index=True,
    )

    # Resolution
    status: Mapped[str] = mapped_column(
        String(20),
        default="open",
        nullable=False,
    )
    resolved_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    resolved_by: Mapped[Optional[str]] = mapped_column(
        String(36),
        nullable=True,
    )
    resolution_notes: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )

    # Indexes
    __table_args__ = (
        Index("ix_safety_alerts_status_type", "status", "alert_type"),
        Index("ix_safety_alerts_reported_user", "reported_user_id", "status"),
    )
