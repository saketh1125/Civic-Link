"""Civic-Link DPI - User Service

User management operations: profile retrieval, updates, and verification.
"""

from typing import Optional

import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import UserNotFoundError
from app.models.audit import AuditEventType, AuditEventSeverity
from app.models.user import User, UserRole, VerificationStatus
from app.services.audit_service import AuditService

logger = structlog.get_logger()


class UserService:
    """Service for user management operations."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_user_by_id(self, user_id: str) -> Optional[User]:
        """Retrieve a user by their ID.

        Args:
            user_id: The user's UUID

        Returns:
            User if found, None otherwise
        """
        result = await self.session.execute(
            select(User)
            .where(User.id == user_id)
            .options(
                selectinload(User.civic_scores),
                selectinload(User.offered_commutes),
            )
        )
        return result.scalar_one_or_none()

    async def get_user_by_email_hash(self, email_hash: str) -> Optional[User]:
        """Retrieve a user by their hashed email.

        Args:
            email_hash: SHA-256 hash of the user's email

        Returns:
            User if found, None otherwise
        """
        result = await self.session.execute(
            select(User).where(User.email_hash == email_hash)
        )
        return result.scalar_one_or_none()

    async def get_user_by_phone(self, phone_number: str) -> Optional[User]:
        """Retrieve a user by their phone number.

        Args:
            phone_number: The user's phone number

        Returns:
            User if found, None otherwise
        """
        result = await self.session.execute(
            select(User).where(User.phone_number == phone_number)
        )
        return result.scalar_one_or_none()

    async def update_user_profile(
        self,
        user_id: str,
        **kwargs,
    ) -> User:
        """Update user profile fields.

        Args:
            user_id: The user's UUID
            **kwargs: Fields to update (full_name, phone_number, employee_id, etc.)

        Returns:
            Updated User

        Raises:
            ResourceNotFoundError: If user not found
        """
        user = await self.get_user_by_id(user_id)
        if not user:
            raise UserNotFoundError(user_id)

        allowed_fields = {
            "full_name",
            "phone_number",
            "employee_id",
            "company_name",
        }

        for field, value in kwargs.items():
            if field in allowed_fields and value is not None:
                setattr(user, field, value)

        await self.session.flush()
        return user

    async def verify_user(self, user_id: str) -> User:
        """Mark a user as verified.

        Args:
            user_id: The user's UUID

        Returns:
            Updated User

        Raises:
            ResourceNotFoundError: If user not found
        """
        user = await self.get_user_by_id(user_id)
        if not user:
            raise UserNotFoundError(user_id)

        user.verification_status = VerificationStatus.VERIFIED
        await self.session.flush()

        try:
            audit = AuditService(self.session)
            await audit.log_match_event(
                driver_id=user_id,
                event_type=AuditEventType.USER_VERIFIED,
                severity=AuditEventSeverity.INFO,
            )
        except Exception as audit_err:
            logger.error("Audit logging failed for user verification", error=str(audit_err))

        return user

    async def promote_to_admin(self, user_id: str) -> User:
        """Promote a user to admin role.

        Args:
            user_id: The user's UUID

        Returns:
            Updated User

        Raises:
            ResourceNotFoundError: If user not found
        """
        user = await self.get_user_by_id(user_id)
        if not user:
            raise UserNotFoundError(user_id)

        user.role = UserRole.ADMIN
        await self.session.flush()

        try:
            audit = AuditService(self.session)
            await audit.log_match_event(
                driver_id=user_id,
                event_type=AuditEventType.ADMIN_PROMOTED,
                severity=AuditEventSeverity.WARNING,
            )
        except Exception as audit_err:
            logger.error("Audit logging failed for admin promotion", error=str(audit_err))

        return user
