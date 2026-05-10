"""Civic-Link DPI - KPHB Test Data Seeding & Hard-Reject Validation

This script:
1. Creates 20 users (10 Female, 10 Male) with @company.com emails
2. Seeds commutes clustered around KPHB Phase 3 -> Mindspace/HITEC City
3. Runs a Women-Only passenger search
4. Verifies: ZERO male drivers returned (Hard-Reject Safety Logic)
"""

import asyncio
import hashlib
import random
import sys
from datetime import date, time, timedelta

from geoalchemy2 import WKTElement
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal, init_db
from app.core.exceptions import CivicLinkSafetyException
from app.core.security import get_password_hash
from app.models.commute import Commute, CommuteOffer, CommuteStatus
from app.models.user import Gender, User, UserRole, VerificationStatus
from app.services.match_service import MatchingService

# KPHB Phase 3 coordinates (approximate center)
KPHB_LAT, KPHB_LON = 17.4930, 78.4020

# Mindspace/HITEC City coordinates (approximate center)
HITEC_LAT, HITEC_LON = 17.4430, 78.3770

# Cluster variance (in degrees, roughly ~100m-500m)
CLUSTER_VARIANCE = 0.003


def generate_coordinate_cluster(center_lat: float, center_lon: float, count: int) -> list:
    """Generate clustered coordinates around a center point."""
    coords = []
    for _ in range(count):
        lat = center_lat + random.uniform(-CLUSTER_VARIANCE, CLUSTER_VARIANCE)
        lon = center_lon + random.uniform(-CLUSTER_VARIANCE, CLUSTER_VARIANCE)
        coords.append((lat, lon))
    return coords


def create_geography_point(lat: float, lon: float) -> WKTElement:
    """Create a Geography POINT with SRID 4326."""
    return WKTElement(f"POINT({lon} {lat})", srid=4326)


async def seed_users(session: AsyncSession) -> list[User]:
    """Create 50 users: 25 Female, 25 Male, all @company.com."""
    users = []
    
    # Default password for seeded users (hashed with bcrypt)
    default_password_hash = get_password_hash("SeedPass123!")
    
    # 25 Female users
    for i in range(25):
        email = f"female{i+1}@company.com"
        email_hash = hashlib.sha256(email.lower().encode()).hexdigest()
        email_domain = email.split('@')[-1]
        
        user = User(
            email_hash=email_hash,
            email_domain=email_domain,
            phone_number=f"+91-98765-{43210 + i}",
            full_name=f"Female User {i+1}",
            gender=Gender.FEMALE,
            role=UserRole.COMMUTER,
            verification_status=VerificationStatus.VERIFIED,
            is_active=True,
            password_hash=default_password_hash,
            company_name="Civic-Link Corp",
            employee_id=f"EMP-{1000 + i}",
        )
        users.append(user)
    
    # 25 Male users
    for i in range(25):
        email = f"male{i+1}@company.com"
        email_hash = hashlib.sha256(email.lower().encode()).hexdigest()
        email_domain = email.split('@')[-1]
        
        user = User(
            email_hash=email_hash,
            email_domain=email_domain,
            phone_number=f"+91-98765-{54321 + i}",
            full_name=f"Male User {i+1}",
            gender=Gender.MALE,
            role=UserRole.COMMUTER,
            verification_status=VerificationStatus.VERIFIED,
            is_active=True,
            password_hash=default_password_hash,
            company_name="Civic-Link Corp",
            employee_id=f"EMP-{2000 + i}",
        )
        users.append(user)
    
    for user in users:
        session.add(user)
    
    await session.commit()
    return users


async def seed_commutes(session: AsyncSession, users: list[User]) -> list[Commute]:
    """Create commutes for all users: KPHB -> HITEC City."""
    # Get origins around KPHB (10 origins for variety)
    kphb_origins = generate_coordinate_cluster(KPHB_LAT, KPHB_LON, 10)
    
    # Get destinations around HITEC City (10 destinations for variety)
    hitec_dests = generate_coordinate_cluster(HITEC_LAT, HITEC_LON, 10)
    
    commutes = []
    tomorrow = date.today() + timedelta(days=1)
    base_time = time(hour=9, minute=0)  # 9:00 AM
    
    for i, user in enumerate(users):
        # Cycle through origin/dest pairs
        origin_lat, origin_lon = kphb_origins[i % 10]
        dest_lat, dest_lon = hitec_dests[i % 10]
        
        # Vary departure time slightly (8:30 - 9:30 AM)
        dep_hour = 8 + (i % 2)
        dep_minute = (i * 5) % 60
        dep_time = time(hour=dep_hour, minute=dep_minute)
        
        # 50% of female users create women-only commutes
        is_women_only = (user.gender == Gender.FEMALE and i < 5)
        
        commute = Commute(
            driver_id=user.id,
            origin=create_geography_point(origin_lat, origin_lon),
            destination=create_geography_point(dest_lat, dest_lon),
            origin_address=f"KPHB Phase 3, Block {i+1}, Hyderabad",
            destination_address=f"Mindspace/HITEC City, Building {i+1}, Hyderabad",
            departure_date=tomorrow,
            departure_time=dep_time,
            available_seats=random.randint(1, 3),
            total_seats=4,
            is_women_only=is_women_only,
            status=CommuteStatus.ACTIVE,
        )
        session.add(commute)
        commutes.append(commute)
    
    await session.commit()
    return commutes


async def run_women_only_safety_test(session: AsyncSession) -> dict:
    """
    CRITICAL TEST: Women-Only passenger searches for rides.
    
    Assertion: MatchingService returns ZERO male drivers.
    
    This validates the Hard-Reject Safety Logic is working at the DB level.
    """
    results = {
        "test_name": "Hard-Reject Safety Logic Validation",
        "passed": False,
        "female_passenger_id": None,
        "women_only_offer_id": None,
        "total_matches_found": 0,
        "male_drivers_found": 0,
        "female_drivers_found": 0,
        "women_only_commutes_found": 0,
        "errors": [],
    }
    
    try:
        # Find a female user to act as passenger
        female_result = await session.execute(
            select(User).where(User.gender == Gender.FEMALE).limit(1)
        )
        female_passenger = female_result.scalar_one()
        results["female_passenger_id"] = str(female_passenger.id)
        
        # Create a Women-Only commute offer from this passenger
        hitec_dests = generate_coordinate_cluster(HITEC_LAT, HITEC_LON, 1)
        dest_lat, dest_lon = hitec_dests[0]
        
        tomorrow = date.today() + timedelta(days=1)
        
        offer = CommuteOffer(
            passenger_id=female_passenger.id,
            origin=create_geography_point(KPHB_LAT, KPHB_LON),
            destination=create_geography_point(dest_lat, dest_lon),
            origin_address="KPHB Phase 3, Passenger Pickup Point",
            destination_address="Mindspace, Office Complex",
            preferred_departure_date=tomorrow,
            preferred_departure_time=time(hour=9, minute=0),
            is_women_only=True,  # CRITICAL: Women-only request
            max_walking_distance=500,
        )
        session.add(offer)
        await session.commit()
        
        results["women_only_offer_id"] = str(offer.id)
        
        # Run matching query via MatchingService
        matching_service = MatchingService(session)
        matches = await matching_service.find_matching_commutes(offer, radius_meters=1000)
        
        results["total_matches_found"] = len(matches)
        
        # Count driver genders in results
        for commute, distance in matches:
            driver_result = await session.execute(
                select(User).where(User.id == commute.driver_id)
            )
            driver = driver_result.scalar_one()
            
            if driver.gender == Gender.MALE:
                results["male_drivers_found"] += 1
            elif driver.gender == Gender.FEMALE:
                results["female_drivers_found"] += 1
            
            if commute.is_women_only:
                results["women_only_commutes_found"] += 1
        
        # CRITICAL ASSERTION: ZERO male drivers
        if results["male_drivers_found"] == 0:
            results["passed"] = True
        else:
            results["errors"].append(
                f"SAFETY VIOLATION: Found {results['male_drivers_found']} male drivers "
                f"in Women-Only search results!"
            )
        
        # Additional assertion: All results should be from female drivers
        if results["female_drivers_found"] != len(matches) and len(matches) > 0:
            results["errors"].append(
                f"INCONSISTENCY: {results['female_drivers_found']} female drivers "
                f"but {len(matches)} total matches"
            )
            
    except Exception as e:
        results["errors"].append(f"Test execution error: {str(e)}")
    
    return results


async def verify_database_state(session: AsyncSession) -> dict:
    """Verify overall database state after seeding."""
    stats = {}
    
    # Count users by gender
    for gender in [Gender.MALE, Gender.FEMALE, Gender.UNDISCLOSED]:
        result = await session.execute(
            select(User).where(User.gender == gender)
        )
        stats[f"users_{gender.value}"] = len(result.scalars().all())
    
    # Count commutes
    result = await session.execute(select(Commute))
    stats["total_commutes"] = len(result.scalars().all())
    
    # Count women-only commutes
    result = await session.execute(
        select(Commute).where(Commute.is_women_only == True)
    )
    stats["women_only_commutes"] = len(result.scalars().all())
    
    # Count offers
    result = await session.execute(select(CommuteOffer))
    stats["total_offers"] = len(result.scalars().all())
    
    return stats


async def main():
    """Main seeding and validation orchestrator."""
    print("=" * 70)
    print("CIVIC-LINK DPI: KPHB Seeding & Hard-Reject Safety Validation")
    print("=" * 70)
    
    report_lines = []
    report_lines.append("=" * 70)
    report_lines.append("CIVIC-LINK DPI: Verification Results")
    report_lines.append("=" * 70)
    report_lines.append("")
    
    async with AsyncSessionLocal() as session:
        try:
            # Step 1: Seed Users
            print("\n[1/4] Seeding 50 users (25 Female, 25 Male)...")
            users = await seed_users(session)
            print(f"      ✓ Created {len(users)} users")
            report_lines.append(f"USERS CREATED: {len(users)}")
            
            female_count = sum(1 for u in users if u.gender == Gender.FEMALE)
            male_count = sum(1 for u in users if u.gender == Gender.MALE)
            report_lines.append(f"  - Female: {female_count}")
            report_lines.append(f"  - Male: {male_count}")
            report_lines.append("")
            
            # Step 2: Seed Commutes (limit to 30 as per Task 1)
            print("\n[2/4] Seeding 30 commutes (KPHB Phase 3 -> Mindspace/HITEC City)...")
            commutes = await seed_commutes(session, users[:30])  # Only first 30 users get commutes
            print(f"      ✓ Created {len(commutes)} commutes")
            report_lines.append(f"COMMUTES CREATED: {len(commutes)}")
            
            women_only_count = sum(1 for c in commutes if c.is_women_only)
            report_lines.append(f"  - Women-Only: {women_only_count}")
            report_lines.append(f"  - Regular: {len(commutes) - women_only_count}")
            report_lines.append("")
            
            # Step 3: Run Women-Only Safety Test
            print("\n[3/4] Running Hard-Reject Safety Logic Test...")
            print("      Creating Women-Only passenger offer...")
            print("      Querying for matching commutes...")
            
            test_results = await run_women_only_safety_test(session)
            
            report_lines.append("HARD-REJECT SAFETY TEST RESULTS:")
            report_lines.append(f"  Test Name: {test_results['test_name']}")
            report_lines.append(f"  Female Passenger ID: {test_results['female_passenger_id']}")
            report_lines.append(f"  Women-Only Offer ID: {test_results['women_only_offer_id']}")
            report_lines.append(f"  Total Matches Found: {test_results['total_matches_found']}")
            report_lines.append(f"  Male Drivers Found: {test_results['male_drivers_found']}")
            report_lines.append(f"  Female Drivers Found: {test_results['female_drivers_found']}")
            report_lines.append(f"  Women-Only Commutes Found: {test_results['women_only_commutes_found']}")
            report_lines.append("")
            
            if test_results["passed"]:
                print("      ✓✓✓ TEST PASSED: ZERO male drivers found!")
                print("      Hard-Reject Safety Logic is working correctly.")
                report_lines.append("STATUS: ✓✓✓ PASSED")
                report_lines.append("Hard-Reject Safety Logic verified at database level.")
            else:
                print("      ✗✗✗ TEST FAILED: Safety violation detected!")
                for error in test_results["errors"]:
                    print(f"      ERROR: {error}")
                    report_lines.append(f"ERROR: {error}")
                report_lines.append("STATUS: ✗✗✗ FAILED")
            
            report_lines.append("")
            
            # Step 4: Verify Database State
            print("\n[4/4] Verifying database state...")
            stats = await verify_database_state(session)
            
            report_lines.append("DATABASE STATISTICS:")
            for key, value in stats.items():
                report_lines.append(f"  {key}: {value}")
            
            print(f"      Total Users: {stats['users_male'] + stats['users_female']}")
            print(f"      Total Commutes: {stats['total_commutes']}")
            print(f"      Women-Only Commutes: {stats['women_only_commutes']}")
            
            # Final Summary
            report_lines.append("")
            report_lines.append("=" * 70)
            if test_results["passed"]:
                report_lines.append("OVERALL STATUS: BACKEND CORE & SAFETY VERIFIED")
                report_lines.append("Ready for Flutter UI Shell.")
            else:
                report_lines.append("OVERALL STATUS: SAFETY VALIDATION FAILED")
                report_lines.append("DO NOT PROCEED until Hard-Reject Logic is fixed.")
            report_lines.append("=" * 70)
            
        except Exception as e:
            print(f"\n✗ Fatal error during seeding: {e}")
            report_lines.append(f"FATAL ERROR: {e}")
            report_lines.append("STATUS: ABORTED")
    
    # Write verification results to file
    with open("verification_results.txt", "w") as f:
        f.write("\n".join(report_lines))
    
    print("\n" + "=" * 70)
    print("Verification results written to: verification_results.txt")
    print("=" * 70)
    
    return test_results.get("passed", False) if 'test_results' in dir() else False


if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)
