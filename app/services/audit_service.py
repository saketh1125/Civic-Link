"""Civic-Link DPI - Audit Service

Encrypted audit logging for commute matches and safety events.
"""

import base64
import json
import os
from datetime import datetime, timedelta, timezone
from typing import Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AuditLogError
from app.models.audit import (
    AuditEventType,
    AuditEventSeverity,
    CommuteAuditLog,
    SafetyAlertLog,
)

settings = get_settings()


class AuditService:
    """Service for encrypted audit logging."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self._encryption_key = self._get_encryption_key()

    def _get_encryption_key(self) -> bytes:
        """Get or generate the audit log encryption key.

        Returns:
            32-byte key for AES-256-GCM
        """
        key_hex = settings.audit_log_encryption_key
        if key_hex == "change-me-in-production":
            return os.urandom(32)
        return bytes.fromhex(key_hex)

    def _encrypt_payload(self, data: dict) -> tuple[str, str]:
        """Encrypt a dictionary using AES-256-GCM.

        Args:
            data: Dictionary to encrypt

        Returns:
            Tuple of (base64_encoded_ciphertext, hex_encoded_iv)
        """
        aesgcm = AESGCM(self._encryption_key)
        iv = os.urandom(12)
        plaintext = json.dumps(data).encode("utf-8")
        ciphertext = aesgcm.encrypt(iv, plaintext, None)
        return base64.b64encode(ciphertext).decode("utf-8"), iv.hex()

    def decrypt_payload(self, encrypted_payload: str, iv_hex: str) -> dict:
        """Decrypt an audit log payload.

        Args:
            encrypted_payload: Base64-encoded ciphertext
            iv_hex: Hex-encoded initialization vector

        Returns:
            Decrypted dictionary

        Raises:
            AuditLogError: If decryption fails
        """
        try:
            aesgcm = AESGCM(self._encryption_key)
            iv = bytes.fromhex(iv_hex)
            ciphertext = base64.b64decode(encrypted_payload)
            plaintext = aesgcm.decrypt(iv, ciphertext, None)
            return json.loads(plaintext.decode("utf-8"))
        except Exception as e:
            raise AuditLogError(f"Failed to decrypt audit payload: {e}")

    async def log_match_event(
        self,
        match_id: str,
        driver_id: str,
        passenger_id: str,
        event_type: AuditEventType,
        severity: AuditEventSeverity = AuditEventSeverity.INFO,
        driver_gender: Optional[str] = None,
        passenger_gender: Optional[str] = None,
        commute_women_only: bool = False,
        offer_women_only: bool = False,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> CommuteAuditLog:
        """Log an audit event for a commute match.

        Args:
            match_id: The match UUID
            driver_id: Driver UUID
            passenger_id: Passenger UUID
            event_type: Type of audit event
            severity: Event severity level
            driver_gender: Driver gender at event time
            passenger_gender: Passenger gender at event time
            commute_women_only: Whether commute was women-only
            offer_women_only: Whether offer was women-only
            ip_address: Request IP address
            user_agent: Request user agent

        Returns:
            Created CommuteAuditLog
        """
        payload = {
            "match_id": match_id,
            "event_type": event_type.value,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        encrypted_payload, iv = self._encrypt_payload(payload)

        retention_days = settings.audit_log_retention_days
        retention_until = datetime.now(timezone.utc) + timedelta(
            days=retention_days
        )

        audit_log = CommuteAuditLog(
            match_id=match_id,
            driver_id=driver_id,
            passenger_id=passenger_id,
            event_type=event_type,
            severity=severity,
            encrypted_payload=encrypted_payload,
            encryption_iv=iv,
            occurred_at=datetime.now(timezone.utc),
            ip_address=ip_address,
            user_agent=user_agent,
            driver_gender_at_time=driver_gender,
            passenger_gender_at_time=passenger_gender,
            commute_women_only_at_time=commute_women_only,
            offer_women_only_at_time=offer_women_only,
            retention_until=retention_until,
        )

        self.session.add(audit_log)
        await self.session.flush()
        return audit_log

    async def log_safety_alert(
        self,
        audit_log_id: str,
        alert_type: str,
        description: str,
        severity: str = "critical",
        match_id: Optional[str] = None,
        reporter_id: Optional[str] = None,
        reported_user_id: Optional[str] = None,
    ) -> SafetyAlertLog:
        """Log a safety alert.

        Args:
            audit_log_id: Reference to the parent audit log
            alert_type: Type of safety alert
            description: Alert description
            severity: Alert severity
            match_id: Associated match ID
            reporter_id: User who reported
            reported_user_id: User who was reported

        Returns:
            Created SafetyAlertLog
        """
        alert = SafetyAlertLog(
            audit_log_id=audit_log_id,
            match_id=match_id,
            reporter_id=reporter_id,
            reported_user_id=reported_user_id,
            alert_type=alert_type,
            description=description,
            severity=severity,
            status="open",
        )

        self.session.add(alert)
        await self.session.flush()
        return alert

    async def get_audit_logs_for_match(
        self,
        match_id: str,
    ) -> list[CommuteAuditLog]:
        """Retrieve all audit logs for a specific match.

        Args:
            match_id: The match UUID

        Returns:
            List of CommuteAuditLog entries
        """
        result = await self.session.execute(
            select(CommuteAuditLog)
            .where(CommuteAuditLog.match_id == match_id)
            .order_by(CommuteAuditLog.occurred_at.asc())
        )
        return list(result.scalars().all())

    async def get_pending_safety_alerts(self) -> list[SafetyAlertLog]:
        """Retrieve all open safety alerts.

        Returns:
            List of open SafetyAlertLog entries
        """
        result = await self.session.execute(
            select(SafetyAlertLog)
            .where(SafetyAlertLog.status == "open")
            .order_by(SafetyAlertLog.created_at.desc())
        )
        return list(result.scalars().all())

    async def resolve_safety_alert(
        self,
        alert_id: str,
        resolved_by: str,
        notes: Optional[str] = None,
    ) -> SafetyAlertLog:
        """Mark a safety alert as resolved.

        Args:
            alert_id: The alert UUID
            resolved_by: User who resolved the alert
            notes: Resolution notes

        Returns:
            Updated SafetyAlertLog
        """
        result = await self.session.execute(
            select(SafetyAlertLog).where(SafetyAlertLog.id == alert_id)
        )
        alert = result.scalar_one_or_none()
        if not alert:
            raise AuditLogError(f"Safety alert {alert_id} not found")

        alert.status = "resolved"
        alert.resolved_at = datetime.now(timezone.utc)
        alert.resolved_by = resolved_by
        alert.resolution_notes = notes
        await self.session.flush()
        return alert
