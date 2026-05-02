"""Civic-Link DPI - SQLAlchemy Models

Exports all models for the application.
Uses SQLAlchemy 2.0 declarative mapping style.
"""

from app.models.audit import (
    AuditEventSeverity,
    AuditEventType,
    CommuteAuditLog,
    SafetyAlertLog,
)
from app.models.base import BaseModel
from app.models.civic_score import CivicScore, CivicScoreHistory
from app.models.commute import (
    Commute,
    CommuteOffer,
    CommuteStatus,
    CommuteType,
    WeekDay,
)
from app.models.match import (
    CommuteMatch,
    MatchStatus,
    PaymentStatus,
)
from app.models.user import (
    Gender,
    User,
    UserRole,
    VerificationStatus,
)

__all__ = [
    # Base
    "BaseModel",
    # User
    "User",
    "UserRole",
    "Gender",
    "VerificationStatus",
    # Commute
    "Commute",
    "CommuteOffer",
    "CommuteStatus",
    "CommuteType",
    "WeekDay",
    # Match
    "CommuteMatch",
    "MatchStatus",
    "PaymentStatus",
    # Audit
    "CommuteAuditLog",
    "SafetyAlertLog",
    "AuditEventType",
    "AuditEventSeverity",
    # Civic Score
    "CivicScore",
    "CivicScoreHistory",
]
