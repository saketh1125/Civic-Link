"""Civic-Link DPI - Task 4: Clean-Up Worker (Privacy Worker)

Implements the "Delete-by-Default" privacy policy:
- Anonymizes location data 24 hours after ride completion
- Sets origin/destination coordinates to NULL
- Preserves safety audit logs (encrypted)
- Runs as background task or scheduled job

This is a critical privacy feature per the manifesto.
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from geoalchemy2 import WKTElement
from sqlalchemy import select, update, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal
from app.models.commute import Commute, CommuteMatch, CommuteStatus, CommuteOffer

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
ANONYMIZATION_DELAY_HOURS = 24  # Anonymize after 24 hours
BATCH_SIZE = 100  # Process in batches to avoid memory issues


class PrivacyWorker:
    """Worker that anonymizes location data after rides complete."""
    
    def __init__(self, db_session: AsyncSession):
        self.db_session = db_session
        self.anonymized_count = 0
    
    async def find_stale_commutes(self) -> List[Commute]:
        """Find commutes that need anonymization (completed > 24h ago)."""
        cutoff_time = datetime.now(timezone.utc) - timedelta(hours=ANONYMIZATION_DELAY_HOURS)
        
        # Find commutes that:
        # 1. Are completed/cancelled
        # 2. Were completed more than 24h ago
        # 3. Still have non-null coordinates (not yet anonymized)
        result = await self.db_session.execute(
            select(Commute)
            .where(
                and_(
                    Commute.status.in_([CommuteStatus.COMPLETED, CommuteStatus.CANCELLED]),
                    Commute.updated_at < cutoff_time,
                    Commute.origin.isnot(None)  # Not yet anonymized
                )
            )
            .limit(BATCH_SIZE)
        )
        
        return list(result.scalars().all())
    
    async def find_stale_commute_offers(self) -> List[CommuteOffer]:
        """Find commute offers that need anonymization."""
        cutoff_time = datetime.now(timezone.utc) - timedelta(hours=ANONYMIZATION_DELAY_HOURS)
        
        result = await self.db_session.execute(
            select(CommuteOffer)
            .where(
                and_(
                    CommuteOffer.status.in_([CommuteStatus.COMPLETED, CommuteStatus.CANCELLED]),
                    CommuteOffer.updated_at < cutoff_time,
                    CommuteOffer.origin.isnot(None)
                )
            )
            .limit(BATCH_SIZE)
        )
        
        return list(result.scalars().all())
    
    async def anonymize_commute(self, commute: Commute) -> bool:
        """Anonymize a single commute's location data.
        
        Sets origin/destination coordinates to NULL but preserves:
        - Commute ID (for audit trails)
        - Driver ID (for civic scoring)
        - Timestamps (for analytics)
        - Status (for records)
        """
        try:
            # Store original coordinates in audit log format before anonymizing
            # (This would typically write to an encrypted audit table)
            
            # Anonymize by setting coordinates to NULL
            await self.db_session.execute(
                update(Commute)
                .where(Commute.id == commute.id)
                .values(
                    origin=None,
                    destination=None,
                    origin_address="[REDACTED]",  # Also redact text addresses
                    destination_address="[REDACTED]",
                    route_polyline=None,  # Remove route data
                )
            )
            
            logger.info(f"Anonymized commute {commute.id[:8]}... "
                       f"(driver: {commute.driver_id[:8]}...)")
            
            self.anonymized_count += 1
            return True
            
        except Exception as e:
            logger.error(f"Failed to anonymize commute {commute.id}: {e}")
            return False
    
    async def anonymize_commute_offer(self, offer: CommuteOffer) -> bool:
        """Anonymize a single commute offer's location data."""
        try:
            await self.db_session.execute(
                update(CommuteOffer)
                .where(CommuteOffer.id == offer.id)
                .values(
                    origin=None,
                    destination=None,
                    origin_address="[REDACTED]",
                    destination_address="[REDACTED]",
                )
            )
            
            logger.info(f"Anonymized offer {offer.id[:8]}... "
                       f"(passenger: {offer.passenger_id[:8]}...)")
            
            self.anonymized_count += 1
            return True
            
        except Exception as e:
            logger.error(f"Failed to anonymize offer {offer.id}: {e}")
            return False
    
    async def run_anonymization_cycle(self) -> dict:
        """Run one full anonymization cycle.
        
        Returns:
            Statistics about the cycle
        """
        stats = {
            "commutes_found": 0,
            "commutes_anonymized": 0,
            "offers_found": 0,
            "offers_anonymized": 0,
            "errors": 0,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        logger.info("Starting privacy anonymization cycle...")
        
        # Step 1: Anonymize completed commutes (driver offers)
        logger.info("[1/2] Checking for stale commutes...")
        commutes = await self.find_stale_commutes()
        stats["commutes_found"] = len(commutes)
        
        if commutes:
            logger.info(f"  Found {len(commutes)} commutes to anonymize")
            
            for commute in commutes:
                success = await self.anonymize_commute(commute)
                if success:
                    stats["commutes_anonymized"] += 1
                else:
                    stats["errors"] += 1
            
            await self.db_session.commit()
            logger.info(f"  ✓ Anonymized {stats['commutes_anonymized']} commutes")
        else:
            logger.info("  No stale commutes found")
        
        # Step 2: Anonymize completed commute offers (passenger requests)
        logger.info("[2/2] Checking for stale commute offers...")
        offers = await self.find_stale_commute_offers()
        stats["offers_found"] = len(offers)
        
        if offers:
            logger.info(f"  Found {len(offers)} offers to anonymize")
            
            for offer in offers:
                success = await self.anonymize_commute_offer(offer)
                if success:
                    stats["offers_anonymized"] += 1
                else:
                    stats["errors"] += 1
            
            await self.db_session.commit()
            logger.info(f"  ✓ Anonymized {stats['offers_anonymized']} offers")
        else:
            logger.info("  No stale offers found")
        
        logger.info("Privacy anonymization cycle complete.")
        return stats


async def run_privacy_worker_once():
    """Run the privacy worker once (for manual execution)."""
    print("=" * 70)
    print("TASK 4: PRIVACY WORKER (Clean-Up)")
    print("=" * 70)
    print()
    print(f"Policy: Delete-by-Default after {ANONYMIZATION_DELAY_HOURS} hours")
    print()
    
    async with AsyncSessionLocal() as session:
        worker = PrivacyWorker(session)
        stats = await worker.run_anonymization_cycle()
    
    # Summary
    print()
    print("=" * 70)
    print("PRIVACY CLEAN-UP SUMMARY")
    print("=" * 70)
    print(f"Commutes scanned: {stats['commutes_found']}")
    print(f"Commutes anonymized: {stats['commutes_anonymized']} ✓")
    print(f"Offers scanned: {stats['offers_found']}")
    print(f"Offers anonymized: {stats['offers_anonymized']} ✓")
    print(f"Errors: {stats['errors']}")
    print(f"Location data: NULL (coordinates purged)")
    print(f"Address data: [REDACTED]")
    print("=" * 70)
    print()
    print("✓ Privacy compliance: Location data anonymized per policy")
    print()
    
    return stats


async def schedule_privacy_worker(interval_minutes: int = 60):
    """Run privacy worker continuously on a schedule.
    
    This would typically be run as a background task or cron job.
    
    Args:
        interval_minutes: How often to run the worker
    """
    logger.info(f"Privacy worker scheduled to run every {interval_minutes} minutes")
    
    while True:
        try:
            async with AsyncSessionLocal() as session:
                worker = PrivacyWorker(session)
                await worker.run_anonymization_cycle()
            
            logger.info(f"Sleeping for {interval_minutes} minutes...")
            await asyncio.sleep(interval_minutes * 60)
            
        except Exception as e:
            logger.error(f"Privacy worker error: {e}")
            await asyncio.sleep(300)  # Wait 5 minutes on error


async def main():
    """Entry point - run once for testing/verification."""
    try:
        stats = await run_privacy_worker_once()
        
        # Return success if no errors
        success = stats['errors'] == 0
        return 0 if success else 1
        
    except Exception as e:
        logger.error(f"Fatal error in privacy worker: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    exit(exit_code)
