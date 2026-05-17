"""Civic-Link DPI - Custom Exception Classes"""

from typing import Optional


class CivicLinkException(Exception):
    """Base exception for Civic-Link DPI."""

    def __init__(self, message: str, code: Optional[str] = None) -> None:
        self.message = message
        self.code = code
        super().__init__(message)


class CivicLinkSafetyException(CivicLinkException):
    """Exception for safety rule violations.

    Raised when safety logic (especially gender safety) is violated.
    This is a critical error that must halt execution.
    """

    def __init__(self, message: str = "Safety constraint violated") -> None:
        super().__init__(message, code="SAFETY_VIOLATION")


class GeospatialConflictError(CivicLinkException):
    """Exception for geospatial constraint violations."""

    def __init__(self, message: str = "Geospatial constraint violated") -> None:
        super().__init__(message, code="GEOSPATIAL_CONFLICT")


class AuditLogError(CivicLinkException):
    """Exception for audit logging failures."""

    def __init__(self, message: str = "Audit log operation failed") -> None:
        super().__init__(message, code="AUDIT_LOG_ERROR")


class UserNotFoundError(CivicLinkException):
    """Exception when user is not found."""

    def __init__(self, user_id: str) -> None:
        super().__init__(f"User {user_id} not found", code="USER_NOT_FOUND")


class CommuteNotFoundError(CivicLinkException):
    """Exception when commute is not found."""

    def __init__(self, commute_id: str) -> None:
        super().__init__(f"Commute {commute_id} not found", code="COMMUTE_NOT_FOUND")


class MatchNotFoundError(CivicLinkException):
    """Exception when match is not found."""

    def __init__(self, match_id: str) -> None:
        super().__init__(f"Match {match_id} not found", code="MATCH_NOT_FOUND")


class ValidationError(CivicLinkException):
    """Exception for validation failures."""

    def __init__(self, message: str, field: Optional[str] = None) -> None:
        self.field = field
        super().__init__(message, code="VALIDATION_ERROR")


class AuthenticationError(CivicLinkException):
    """Exception for authentication failures."""

    def __init__(self, message: str = "Authentication failed") -> None:
        super().__init__(message, code="AUTHENTICATION_ERROR")


class AuthorizationError(CivicLinkException):
    """Exception for authorization failures."""

    def __init__(self, message: str = "Not authorized") -> None:
        super().__init__(message, code="AUTHORIZATION_ERROR")


class RateLimitError(CivicLinkException):
    """Exception for rate limit violations."""

    def __init__(self, message: str = "Rate limit exceeded") -> None:
        super().__init__(message, code="RATE_LIMIT_ERROR")


class InvalidStateTransitionError(CivicLinkException):
    """Exception for invalid state machine transitions."""

    def __init__(self, current_state: str, attempted: str) -> None:
        self.current_state = current_state
        self.attempted = attempted
        super().__init__(
            f"Invalid state transition: {current_state} -> {attempted}",
            code="INVALID_STATE_TRANSITION",
        )
