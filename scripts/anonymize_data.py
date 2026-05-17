"""Civic-Link DPI - GDPR Data Anonymization Script

Anonymizes user PII and purges old audit logs for GDPR/RTI compliance.

Usage:
    python -m scripts.anonymize_data --user-id <uuid> --reason <string>
    python -m scripts.anonymize_data --user-id <uuid> --reason <string> --dry-run
"""

import argparse
import hashlib
import sys
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal, close_db, init_db
from app.models.audit import AuditEventType, AuditEventSeverity, CommuteAuditLog
from app.models.commute import Commute, CommuteOffer
from app.models.user import User


async def anonymize_user(
    session: AsyncSession,
    user_id: str,
    reason: str,
    dry_run: bool = False,
) -> dict:
    """Anonymize all PII fields for a user without deleting the record.

    Args:
        session: Database session
        user_id: UUID of the user to anonymize
        reason: Reason for anonymization (logged)
        dry_run: If True, only print what would be changed

    Returns:
        Dictionary of changes made (or would be made)
    """
    result = await session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise ValueError(f"User {user_id} not found")

    changes = {
        "user_id": str(user.id),
        "full_name_before": user.full_name,
        "email_hash_before": user.email_hash[:16] + "...",
        "phone_number_before": user.phone_number,
        "employee_id_before": user.employee_id,
        "company_name_before": user.company_name,
    }

    random_uuid = str(uuid.uuid4())
    anonymized_email_hash = hashlib.sha256(random_uuid.encode()).hexdigest()

    if dry_run:
        print(f"[DRY RUN] Would anonymize user {user_id}:")
        print(f"  full_name: '{user.full_name}' -> 'Anonymized User'")
        print(f"  email_hash: '{user.email_hash[:16]}...' -> '{anonymized_email_hash[:16]}...'")
        # TODO: Phone number is stored in plaintext — this is a known gap.
        # Flagged for hashing in a future sprint.
        print(f"  phone_number: '{user.phone_number}' -> NULL")
        print(f"  employee_id: '{user.employee_id}' -> NULL")
        print(f"  company_name: '{user.company_name}' -> NULL")
        print(f"  anonymized_at: -> {datetime.now(timezone.utc).isoformat()}")
        print(f"  reason: {reason}")
        return changes

    user.full_name = "Anonymized User"
    user.email_hash = anonymized_email_hash
    user.phone_number = None  # type: ignore[assignment]
    # TODO: Phone number plaintext storage is a known gap — flagged for hashing
    # in a future sprint. Setting to NULL here removes the PII.
    user.employee_id = None
    user.company_name = "ANONYMIZED"

    await session.flush()

    changes["anonymized_at"] = datetime.now(timezone.utc).isoformat()
    changes["reason"] = reason
    return changes


async def anonymize_audit_logs(
    session: AsyncSession,
    user_id: str,
    retention_days: int,
    dry_run: bool = False,
) -> int:
    """Delete audit log entries older than retention_days for a user.

    Args:
        session: Database session
        user_id: UUID of the user
        retention_days: Number of days to retain
        dry_run: If True, only print count without deleting

    Returns:
        Number of entries deleted (or would be deleted)
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)

    stmt = (
        select(CommuteAuditLog)
        .where(
            (
                (CommuteAuditLog.driver_id == user_id)
                | (CommuteAuditLog.passenger_id == user_id)
            )
            & (CommuteAuditLog.occurred_at < cutoff)
        )
    )

    result = await session.execute(stmt)
    logs = list(result.scalars().all())
    count = len(logs)

    if dry_run:
        print(f"[DRY RUN] Would delete {count} audit log entries for user {user_id}")
        print(f"  Cutoff date: {cutoff.isoformat()}")
        return count

    if count > 0:
        delete_stmt = (
            delete(CommuteAuditLog)
            .where(
                (
                    (CommuteAuditLog.driver_id == user_id)
                    | (CommuteAuditLog.passenger_id == user_id)
                )
                & (CommuteAuditLog.occurred_at < cutoff)
            )
        )
        await session.execute(delete_stmt)

    return count


async def anonymize_commute_coordinates(
    session: AsyncSession,
    user_id: str,
    dry_run: bool = False,
) -> int:
    """Anonymize origin/destination coordinates for a user's commutes.

    Args:
        session: Database session
        user_id: UUID of the user
        dry_run: If True, only print count without modifying

    Returns:
        Number of commutes anonymized
    """
    result = await session.execute(
        select(Commute).where(Commute.driver_id == user_id)
    )
    commutes = list(result.scalars().all())

    result_offers = await session.execute(
        select(CommuteOffer).where(CommuteOffer.passenger_id == user_id)
    )
    offers = list(result_offers.scalars().all())

    total = len(commutes) + len(offers)

    if dry_run:
        print(f"[DRY RUN] Would anonymize coordinates for {len(commutes)} commutes and {len(offers)} offers")
        return total

    now = datetime.now()
    for commute in commutes:
        commute.origin_anonymized_at = now
        commute.destination_anonymized_at = now

    for offer in offers:
        offer.origin_anonymized_at = now
        offer.destination_anonymized_at = now

    return total


async def log_anonymization_action(
    session: AsyncSession,
    user_id: str,
    reason: str,
) -> None:
    """Log the anonymization action itself as a final audit entry.

    Args:
        session: Database session
        user_id: UUID of the user
        reason: Reason for anonymization
    """
    from app.services.audit_service import AuditService

    audit = AuditService(session)
    await audit.log_match_event(
        driver_id=user_id,
        event_type=AuditEventType.DATA_ANONYMIZED,
        severity=AuditEventSeverity.INFO,
    )


async def main(user_id: str, reason: str, dry_run: bool) -> None:
    """Main entrypoint for anonymization."""
    await init_db()

    async with AsyncSessionLocal() as session:
        try:
            print(f"{'[DRY RUN] ' if dry_run else ''}Anonymizing user {user_id}...")
            print(f"Reason: {reason}")
            print()

            changes = await anonymize_user(session, user_id, reason, dry_run)
            print()

            audit_count = await anonymize_audit_logs(
                session, user_id, retention_days=90, dry_run=dry_run
            )
            print()

            coord_count = await anonymize_commute_coordinates(
                session, user_id, dry_run=dry_run
            )
            print()

            if not dry_run:
                await log_anonymization_action(session, user_id, reason)
                await session.commit()
                print("Anonymization committed successfully.")
            else:
                print("[DRY RUN] No changes committed.")

        except ValueError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            await session.rollback()
            print(f"Fatal error during anonymization: {e}", file=sys.stderr)
            sys.exit(1)
        finally:
            await session.close()

    await close_db()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Anonymize user PII for GDPR/RTI compliance"
    )
    parser.add_argument(
        "--user-id",
        required=True,
        help="UUID of the user to anonymize",
    )
    parser.add_argument(
        "--reason",
        required=True,
        help="Reason for anonymization (logged in audit trail)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be anonymized without committing changes",
    )

    args = parser.parse_args()

    import asyncio

    asyncio.run(main(args.user_id, args.reason, args.dry_run))
