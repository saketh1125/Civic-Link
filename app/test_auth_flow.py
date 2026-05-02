"""Civic-Link DPI - Authentication Flow Test

Test script that:
1. Registers a new user
2. Obtains a JWT token via login
3. Successfully hits the secured /telemetry endpoint
4. Outputs results to auth_test_results.log
"""

import asyncio
import logging
import sys
from datetime import datetime, timezone
from typing import Optional

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal
from app.models.user import User

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('auth_test_results.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Test configuration
API_BASE_URL = "http://localhost:8000/api/v1"
TEST_EMAIL = "test.user@company.com"
TEST_PASSWORD = "TestPass123!"
TEST_PHONE = "+91-98765-99999"


async def cleanup_test_user(session: AsyncSession, email: str) -> None:
    """Remove test user if exists to allow re-runs."""
    import hashlib
    email_hash = hashlib.sha256(email.lower().encode()).hexdigest()
    
    result = await session.execute(
        select(User).where(User.email_hash == email_hash)
    )
    user = result.scalar_one_or_none()
    
    if user:
        await session.delete(user)
        await session.commit()
        logger.info(f"Cleaned up existing test user: {email}")


async def test_register_user() -> bool:
    """Test user registration endpoint."""
    logger.info("=" * 70)
    logger.info("TEST 1: User Registration")
    logger.info("=" * 70)
    
    async with httpx.AsyncClient() as client:
        register_data = {
            "email": TEST_EMAIL,
            "password": TEST_PASSWORD,
            "full_name": "Test User",
            "phone_number": TEST_PHONE,
            "gender": "male",
            "company_name": "TestCorp",
            "employee_id": "TEST123"
        }
        
        try:
            response = await client.post(
                f"{API_BASE_URL}/auth/register",
                json=register_data
            )
            
            if response.status_code == 201:
                data = response.json()
                logger.info(f"✓ Registration successful")
                logger.info(f"  User ID: {data['id']}")
                logger.info(f"  Name: {data['full_name']}")
                logger.info(f"  Domain: {data['email_domain']}")
                logger.info(f"  Gender: {data['gender']}")
                return True
            else:
                logger.error(f"✗ Registration failed: HTTP {response.status_code}")
                logger.error(f"  Response: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"✗ Registration error: {e}")
            return False


async def test_login_and_get_token() -> Optional[str]:
    """Test login endpoint and return JWT token."""
    logger.info("")
    logger.info("=" * 70)
    logger.info("TEST 2: User Login (OAuth2 Password Flow)")
    logger.info("=" * 70)
    
    async with httpx.AsyncClient() as client:
        try:
            # OAuth2 password form data
            form_data = {
                "username": TEST_EMAIL,
                "password": TEST_PASSWORD,
                "grant_type": "password"
            }
            
            response = await client.post(
                f"{API_BASE_URL}/auth/login/access-token",
                data=form_data
            )
            
            if response.status_code == 200:
                data = response.json()
                token = data['access_token']
                logger.info(f"✓ Login successful")
                logger.info(f"  Token type: {data['token_type']}")
                logger.info(f"  Expires in: {data['expires_in']} seconds")
                logger.info(f"  Token preview: {token[:50]}...")
                return token
            else:
                logger.error(f"✗ Login failed: HTTP {response.status_code}")
                logger.error(f"  Response: {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"✗ Login error: {e}")
            return None


async def test_secured_telemetry_endpoint(token: str) -> bool:
    """Test that telemetry endpoint requires and accepts valid JWT."""
    logger.info("")
    logger.info("=" * 70)
    logger.info("TEST 3: Secured Telemetry Endpoint")
    logger.info("=" * 70)
    
    async with httpx.AsyncClient() as client:
        # First, test without token (should fail)
        logger.info("[3.1] Testing WITHOUT authentication (should fail)...")
        try:
            response = await client.post(
                f"{API_BASE_URL}/telemetry",
                json={
                    "user_id": "test-user-id",
                    "match_id": None,
                    "readings": []
                }
            )
            
            if response.status_code == 401:
                logger.info(f"✓ Correctly rejected without token (HTTP 401)")
            else:
                logger.warning(f"⚠ Unexpected response: HTTP {response.status_code}")
                
        except Exception as e:
            logger.error(f"✗ Error testing without auth: {e}")
        
        # Now test with valid token (should succeed)
        logger.info("")
        logger.info("[3.2] Testing WITH valid JWT token (should succeed)...")
        
        # Get the user ID from the database for the telemetry request
        async with AsyncSessionLocal() as session:
            import hashlib
            email_hash = hashlib.sha256(TEST_EMAIL.lower().encode()).hexdigest()
            result = await session.execute(
                select(User).where(User.email_hash == email_hash)
            )
            user = result.scalar_one_or_none()
            
            if not user:
                logger.error("✗ Test user not found in database")
                return False
            
            user_id = str(user.id)
        
        # Create sample IMU readings
        import time
        current_time_ms = int(time.time() * 1000)
        readings = [
            {
                "timestamp_ms": current_time_ms + (i * 20),
                "gyro_x": 0.05,
                "gyro_y": 0.02,
                "gyro_z": 0.1,
                "accel_x": 0.1,
                "accel_y": -0.2,
                "accel_z": 9.8
            }
            for i in range(10)  # 10 readings = 0.2 seconds at 50Hz
        ]
        
        telemetry_data = {
            "user_id": user_id,
            "match_id": None,
            "readings": readings
        }
        
        headers = {
            "Authorization": f"Bearer {token}"
        }
        
        try:
            response = await client.post(
                f"{API_BASE_URL}/telemetry",
                json=telemetry_data,
                headers=headers
            )
            
            if response.status_code == 202:
                data = response.json()
                logger.info(f"✓ Telemetry accepted (HTTP 202)")
                logger.info(f"  User ID: {data['user_id']}")
                logger.info(f"  Readings processed: {data['processed_readings']}")
                logger.info(f"  Message: {data['message']}")
                return True
            else:
                logger.error(f"✗ Telemetry failed: HTTP {response.status_code}")
                logger.error(f"  Response: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"✗ Telemetry error: {e}")
            return False


async def test_me_endpoint(token: str) -> bool:
    """Test the /auth/me endpoint that requires authentication."""
    logger.info("")
    logger.info("=" * 70)
    logger.info("TEST 4: Get Current User Profile (/auth/me)")
    logger.info("=" * 70)
    
    async with httpx.AsyncClient() as client:
        headers = {
            "Authorization": f"Bearer {token}"
        }
        
        try:
            response = await client.get(
                f"{API_BASE_URL}/auth/me",
                headers=headers
            )
            
            if response.status_code == 200:
                data = response.json()
                logger.info(f"✓ Profile retrieved successfully")
                logger.info(f"  Name: {data['full_name']}")
                logger.info(f"  Domain: {data['email_domain']}")
                logger.info(f"  Company: {data['company_name']}")
                logger.info(f"  Role: {data['role']}")
                return True
            else:
                logger.error(f"✗ Profile retrieval failed: HTTP {response.status_code}")
                logger.error(f"  Response: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"✗ Profile error: {e}")
            return False


async def run_auth_flow_test():
    """Run the complete authentication flow test."""
    logger.info("=" * 70)
    logger.info("CIVIC-LINK DPI - AUTHENTICATION FLOW TEST")
    logger.info(f"Started at: {datetime.now(timezone.utc).isoformat()}")
    logger.info("=" * 70)
    logger.info("")
    
    # Clean up any existing test user
    async with AsyncSessionLocal() as session:
        await cleanup_test_user(session, TEST_EMAIL)
    
    results = {
        "registration": False,
        "login": False,
        "telemetry": False,
        "profile": False
    }
    
    # Test 1: Register
    results["registration"] = await test_register_user()
    
    # Test 2: Login
    token = None
    if results["registration"]:
        token = await test_login_and_get_token()
        results["login"] = token is not None
    
    # Test 3: Secured endpoint
    if token:
        results["telemetry"] = await test_secured_telemetry_endpoint(token)
        results["profile"] = await test_me_endpoint(token)
    
    # Summary
    logger.info("")
    logger.info("=" * 70)
    logger.info("TEST SUMMARY")
    logger.info("=" * 70)
    
    for test_name, passed in results.items():
        status = "PASSED ✓" if passed else "FAILED ✗"
        logger.info(f"  {test_name.upper()}: {status}")
    
    all_passed = all(results.values())
    
    logger.info("")
    if all_passed:
        logger.info("✓ ALL TESTS PASSED")
        logger.info("  Authentication system is working correctly!")
    else:
        logger.error("✗ SOME TESTS FAILED")
        logger.error("  Please check the logs above for details.")
    
    logger.info("")
    logger.info(f"Finished at: {datetime.now(timezone.utc).isoformat()}")
    logger.info("=" * 70)
    
    return all_passed


async def main():
    """Entry point."""
    try:
        success = await run_auth_flow_test()
        return 0 if success else 1
    except Exception as e:
        logger.critical(f"Fatal error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    exit(exit_code)
