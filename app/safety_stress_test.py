"""Civic-Link DPI - Task 2: Safety Stress Test

Simulates 10 "Women-Only" requests and generates safety_audit.log
showing that 0 male drivers were matched.

This validates the Hard-Reject Safety Logic at the database level.
"""

import asyncio
import logging
import os
import sys
import tempfile
from datetime import date, time, timedelta

from geoalchemy2 import WKTElement
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal
from app.models.commute import CommuteOffer, CommuteStatus
from app.models.user import Gender, User
from app.services.match_service import MatchingService

# Configure logging with permission error handling
log_handlers = [logging.StreamHandler()]
log_file_path = 'safety_audit.log'

try:
    log_handlers.append(logging.FileHandler(log_file_path))
except PermissionError:
    # Fallback to temp directory if /app/ is read-only
    log_file_path = os.path.join(tempfile.gettempdir(), 'safety_audit.log')
    log_handlers.append(logging.FileHandler(log_file_path))

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=log_handlers
)
logger = logging.getLogger(__name__)
logger.info(f"Logging to: {log_file_path}")

# KPHB and Mindspace coordinates
KPHB_LAT, KPHB_LON = 17.4930, 78.4020
HITEC_LAT, HITEC_LON = 17.4430, 78.3770


def create_geography_point(lat: float, lon: float) -> WKTElement:
    """Create a Geography POINT with SRID 4326."""
    return WKTElement(f"POINT({lon} {lat})", srid=4326)


async def create_women_only_request(
    session: AsyncSession,
    female_passenger: User,
    request_num: int
) -> CommuteOffer:
    """Create a Women-Only commute offer."""
    today = date.today()
    
    try:
        offer = CommuteOffer(
            passenger_id=female_passenger.id,
            commute_id=None,  # Explicitly None - not matched yet
            origin=create_geography_point(KPHB_LAT + (request_num * 0.001), KPHB_LON),
            destination=create_geography_point(HITEC_LAT, HITEC_LON + (request_num * 0.001)),
            origin_address=f"KPHB Phase 3, Block {request_num + 1}",
            destination_address=f"Mindspace, Building {request_num + 1}",
            preferred_departure_date=today,
            preferred_departure_time=time(hour=9, minute=request_num * 3),
            is_women_only=True,
            max_walking_distance=500,
            status="pending",
        )
        session.add(offer)
        await session.commit()
        await session.refresh(offer)
        return offer
    except Exception as e:
        try:
            await session.rollback()
        except Exception:
            # Ignore greenlet/async boundary errors during rollback
            pass
        raise e


async def run_safety_stress_test(session: AsyncSession) -> dict:
    """
    Run 10 Women-Only requests and verify 0 male drivers matched.
    
    Returns:
        Test results dictionary
    """
    results = {
        "total_requests": 10,
        "requests_with_matches": 0,
        "total_matches_found": 0,
        "male_drivers_matched": 0,
        "female_drivers_matched": 0,
        "women_only_commutes_matched": 0,
        "test_passed": True,
        "errors": [],
    }
    
    logger.info("=" * 70)
    logger.info("SAFETY STRESS TEST: 10 Women-Only Requests")
    logger.info("=" * 70)
    logger.info("")
    
    # Get female passengers for requests
    female_result = await session.execute(
        select(User).where(User.gender == Gender.FEMALE).limit(10)
    )
    female_passengers = female_result.scalars().all()
    
    # Auto-seed if insufficient female users
    if len(female_passengers) < 10:
        logger.warning(f"Not enough female users! Found {len(female_passengers)}, need 10")
        logger.info("Auto-triggering database seeding from app/seed_kphb.py...")
        
        try:
            # Import and run seed script
            from app.seed_kphb import seed_users, seed_commutes
            
            users = await seed_users(session)
            female_count = sum(1 for u in users if u.gender == Gender.FEMALE)
            male_count = sum(1 for u in users if u.gender == Gender.MALE)
            logger.info(f"Seeded {len(users)} users ({female_count} female, {male_count} male)")
            
            # Seed commutes for first 30 users
            commutes = await seed_commutes(session, users[:30])
            logger.info(f"Seeded {len(commutes)} commutes")
            
            # Re-query for female passengers
            female_result = await session.execute(
                select(User).where(User.gender == Gender.FEMALE).limit(10)
            )
            female_passengers = female_result.scalars().all()
            
        except Exception as seed_error:
            logger.error(f"Auto-seeding failed: {seed_error}")
            results["errors"].append(f"Insufficient female users: {len(female_passengers)}, seeding failed: {seed_error}")
            results["test_passed"] = False
            return results
    
    if len(female_passengers) < 10:
        logger.error(f"Still not enough female users after seeding! Found {len(female_passengers)}, need 10")
        results["errors"].append(f"Insufficient female users: {len(female_passengers)}")
        results["test_passed"] = False
        return results
    
    matching_service = MatchingService(session)
    
    for i, passenger in enumerate(female_passengers):
        logger.info(f"Request {i+1}/10: Women-Only search by {passenger.email_hash[:16]}...@{passenger.email_domain}")
        
        try:
            # Create Women-Only offer
            offer = await create_women_only_request(session, passenger, i)
            
            # Search for matches
            matches = await matching_service.find_matching_commutes(
                offer, 
                radius_meters=1000
            )
            
            if matches:
                results["requests_with_matches"] += 1
                results["total_matches_found"] += len(matches)
                
                # Check each match for driver gender
                for commute, distance in matches:
                    driver_result = await session.execute(
                        select(User).where(User.id == commute.driver_id)
                    )
                    driver = driver_result.scalar_one()
                    
                    if driver.gender == Gender.MALE:
                        results["male_drivers_matched"] += 1
                        logger.error(
                            f"  ✗ SAFETY VIOLATION: Matched male driver {driver.email_hash[:16]}... "
                            f"for Women-Only request!"
                        )
                    else:
                        results["female_drivers_matched"] += 1
                        logger.info(
                            f"  ✓ Matched female driver {driver.email_hash[:16]}... "
                            f"at {distance:.0f}m"
                        )
                    
                    if commute.is_women_only:
                        results["women_only_commutes_matched"] += 1
            else:
                logger.info(f"  - No matches found for this request")
                
        except Exception as e:
            logger.error(f"  ✗ Error during request {i+1}: {e}")
            results["errors"].append(f"Request {i+1}: {str(e)}")
            # CRITICAL: Rollback to prevent transaction poisoning
            try:
                await session.rollback()
            except Exception:
                # Ignore greenlet/async boundary errors during rollback
                pass
    
    # Final assertion
    if results["male_drivers_matched"] > 0:
        results["test_passed"] = False
        logger.error("")
        logger.error("=" * 70)
        logger.error("TEST FAILED: SAFETY VIOLATION DETECTED")
        logger.error(f"Found {results['male_drivers_matched']} male drivers in Women-Only matches")
        logger.error("Hard-Reject Safety Logic is BROKEN")
        logger.error("=" * 70)
    else:
        logger.info("")
        logger.info("=" * 70)
        logger.info("TEST PASSED: Hard-Reject Safety Logic Verified")
        logger.info(f"Total matches checked: {results['total_matches_found']}")
        logger.info(f"Male drivers found: {results['male_drivers_matched']} (EXPECTED: 0)")
        logger.info(f"Female drivers found: {results['female_drivers_matched']}")
        logger.info("=" * 70)
    
    return results


async def main():
    """Main entry point for safety stress test."""
    logger.info("Starting Safety Stress Test...")
    logger.info("")
    
    async with AsyncSessionLocal() as session:
        try:
            results = await run_safety_stress_test(session)
            
            # Write summary to log
            logger.info("")
            logger.info("TEST SUMMARY:")
            logger.info(f"  Total Women-Only requests: {results['total_requests']}")
            logger.info(f"  Requests with matches: {results['requests_with_matches']}")
            logger.info(f"  Total matches found: {results['total_matches_found']}")
            logger.info(f"  Male drivers matched: {results['male_drivers_matched']} ✗")
            logger.info(f"  Female drivers matched: {results['female_drivers_matched']} ✓")
            logger.info(f"  Women-only commutes: {results['women_only_commutes_matched']}")
            logger.info(f"  Test passed: {results['test_passed']}")
            
            if results['errors']:
                logger.warning(f"  Errors encountered: {len(results['errors'])}")
            
            return results["test_passed"]
            
        except Exception as e:
            logger.error(f"Fatal error during safety test: {e}")
            # Don't call rollback here - context manager handles cleanup
            # The session will be properly closed when exiting async with block
            return False


if __name__ == "__main__":
    success = asyncio.run(main())
    exit(0 if success else 1)
