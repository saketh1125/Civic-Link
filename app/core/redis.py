"""Civic-Link DPI - Async Redis Client

Provides a lifespan-managed async Redis connection pool with utility functions.
Redis failure degrades gracefully — if Redis is unreachable, operations log
a warning and return None/False rather than crashing the API.
"""

import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator, Optional

import redis.asyncio as aioredis

from app.core.config import get_settings

logger = logging.getLogger(__name__)

settings = get_settings()

# Module-level Redis client instance
_redis_client: Optional[aioredis.Redis] = None


async def init_redis() -> aioredis.Redis:
    """Initialize the async Redis connection pool.

    Returns the Redis client instance. If Redis is unreachable,
    logs a critical error but returns None (graceful degradation).
    """
    global _redis_client

    try:
        _redis_client = aioredis.from_url(
            settings.redis_url,
            decode_responses=True,
            health_check_interval=10,
            socket_connect_timeout=5,
            socket_timeout=5,
            retry_on_timeout=True,
        )

        # Health check: set a key with TTL to verify connectivity
        await _redis_client.set("redis:health", "ok", ex=60)
        logger.info("Redis connection established: %s", settings.redis_url)

    except Exception as e:
        logger.critical("Redis connection failed — operating without cache: %s", e)
        _redis_client = None

    return _redis_client


async def close_redis() -> None:
    """Close the Redis connection pool."""
    global _redis_client
    if _redis_client:
        await _redis_client.close()
        _redis_client = None
        logger.info("Redis connection closed")


def get_redis_client() -> Optional[aioredis.Redis]:
    """Get the current Redis client instance (may be None if not initialized)."""
    return _redis_client


async def get_redis() -> AsyncGenerator[Optional[aioredis.Redis], None]:
    """FastAPI dependency for getting the Redis client."""
    yield _redis_client


# =============================================================================
# Utility Functions (all degrade gracefully if Redis is unavailable)
# =============================================================================


async def set_with_ttl(key: str, value: str, ttl_seconds: int) -> bool:
    """Set a key with expiration TTL.

    Returns True on success, False if Redis is unavailable.
    """
    try:
        if _redis_client is None:
            return False
        await _redis_client.set(key, value, ex=ttl_seconds)
        return True
    except Exception as e:
        logger.warning("Redis SET failed for key '%s': %s", key, e)
        return False


async def get(key: str) -> Optional[str]:
    """Get a value by key.

    Returns the value, or None if key doesn't exist or Redis is unavailable.
    """
    try:
        if _redis_client is None:
            return None
        return await _redis_client.get(key)
    except Exception as e:
        logger.warning("Redis GET failed for key '%s': %s", key, e)
        return None


async def delete(key: str) -> bool:
    """Delete a key.

    Returns True on success, False if Redis is unavailable.
    """
    try:
        if _redis_client is None:
            return False
        await _redis_client.delete(key)
        return True
    except Exception as e:
        logger.warning("Redis DELETE failed for key '%s': %s", key, e)
        return False


async def exists(key: str) -> bool:
    """Check if a key exists.

    Returns True if key exists, False otherwise or if Redis is unavailable.
    """
    try:
        if _redis_client is None:
            return False
        return bool(await _redis_client.exists(key))
    except Exception as e:
        logger.warning("Redis EXISTS failed for key '%s': %s", key, e)
        return False


async def increment(key: str, ttl_seconds: Optional[int] = None) -> Optional[int]:
    """Atomically increment a key's value.

    Optionally sets TTL on first increment.
    Returns the new value, or None if Redis is unavailable.
    """
    try:
        if _redis_client is None:
            return None
        pipe = _redis_client.pipeline()
        pipe.incr(key)
        if ttl_seconds:
            pipe.expire(key, ttl_seconds)
        results = await pipe.execute()
        return results[0]
    except Exception as e:
        logger.warning("Redis INCR failed for key '%s': %s", key, e)
        return None
