"""Civic-Link DPI - Test Configuration

Pytest fixtures for database, async session, and test data.
"""

import asyncio
from typing import AsyncGenerator, Generator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import get_settings
from app.main import app

TEST_DATABASE_URL = "postgresql+asyncpg://civic:civic_secret@localhost:5432/civic_link_test"


@pytest.fixture(scope="session")
def event_loop() -> Generator:
    """Create an event loop for async tests."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Create a fresh database session for each test."""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        yield session

    await engine.dispose()


@pytest_asyncio.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    """Create an async HTTP client for API testing."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


@pytest.fixture
def test_user_data() -> dict:
    """Standard test user data."""
    return {
        "email_hash": "a" * 64,
        "email_domain": "cmrcet.ac.in",
        "password": "SecurePass123!",
        "full_name": "Test User",
        "phone_number": "+91-99999-00001",
        "gender": "male",
        "company_name": "Test Corp",
    }


@pytest.fixture
def test_female_user_data() -> dict:
    """Test female user data for safety logic tests."""
    return {
        "email_hash": "b" * 64,
        "email_domain": "cmrcet.ac.in",
        "password": "SecurePass123!",
        "full_name": "Female User",
        "phone_number": "+91-99999-00002",
        "gender": "female",
        "company_name": "Test Corp",
    }
