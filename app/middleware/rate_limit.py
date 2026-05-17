"""Civic-Link DPI - Rate Limiting Middleware

Sliding window rate limiter backed by Redis.
Limits are applied per-IP for auth endpoints and per-user for authenticated endpoints.

If Redis is unavailable, rate limiting is skipped and a warning is logged.
Health check endpoints are never rate limited.
"""

import logging
import time
from typing import Optional

from fastapi import Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint

from app.core.redis import get_redis_client

logger = logging.getLogger(__name__)

# Rate limit configuration: (endpoint_prefix, max_requests, window_seconds)
RATE_LIMITS = [
    # Auth endpoints: 10 requests/minute per IP
    ("/api/v1/auth/login", 10, 60),
    ("/api/v1/auth/register", 5, 60),
    # Telemetry ingestion: 30 requests/minute per user
    ("/api/v1/civic-score/ingest", 30, 60),
    # All other authenticated endpoints: 120 requests/minute per user
    ("/api/v1/", 120, 60),
]

# Paths that are never rate limited
EXEMPT_PATHS = {"/health", "/docs", "/redoc", "/openapi.json", "/"}


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Sliding window rate limiting middleware using Redis."""

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        path = request.url.path

        # Skip rate limiting for exempt paths
        if path in EXEMPT_PATHS:
            return await call_next(request)

        # Find matching rate limit rule
        rule = self._find_rule(path)
        if rule is None:
            return await call_next(request)

        endpoint_prefix, max_requests, window = rule

        # Determine the rate limit key (user ID for authenticated, IP for others)
        client_id = self._get_client_id(request)
        key = f"ratelimit:{client_id}:{endpoint_prefix}"

        redis_client = get_redis_client()

        # If Redis is unavailable, skip rate limiting
        if redis_client is None:
            logger.warning("Redis unavailable — skipping rate limit for %s", path)
            return await call_next(request)

        try:
            # Sliding window: use sorted set with timestamp as score
            now = time.time()
            window_start = now - window

            pipe = redis_client.pipeline()
            # Remove expired entries
            pipe.zremrangebyscore(key, 0, window_start)
            # Count current entries in window
            pipe.zcard(key)
            # Add current request
            pipe.zadd(key, {f"{now}:{id(request)}": now})
            # Set expiry on the key
            pipe.expire(key, window)
            results = await pipe.execute()

            current_count = results[1]

            if current_count > max_requests:
                # Rate limit exceeded
                retry_after = int(window - (now - window_start))
                return JSONResponse(
                    status_code=429,
                    content={
                        "error": "RATE_LIMIT_EXCEEDED",
                        "retry_after_seconds": max(1, retry_after),
                    },
                    headers={"Retry-After": str(max(1, retry_after))},
                )

        except Exception as e:
            logger.warning("Rate limit check failed for %s: %s", path, e)
            # On error, allow the request through
            return await call_next(request)

        return await call_next(request)

    def _find_rule(self, path: str) -> Optional[tuple]:
        """Find the most specific matching rate limit rule."""
        # Sort by prefix length descending to match most specific rule first
        sorted_rules = sorted(RATE_LIMITS, key=lambda r: len(r[0]), reverse=True)
        for prefix, max_req, window in sorted_rules:
            if path.startswith(prefix):
                return (prefix, max_req, window)
        return None

    def _get_client_id(self, request: Request) -> str:
        """Get client identifier: user ID from auth header, or IP address."""
        auth = request.headers.get("authorization", "")
        if auth.startswith("Bearer "):
            # Extract user ID from token (simplified — in production, decode JWT)
            token = auth[7:]
            # Use token hash as identifier to avoid decoding here
            return f"user:{hash(token) % 1000000}"
        # Fall back to IP address
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return f"ip:{forwarded.split(',')[0].strip()}"
        return f"ip:{request.client.host if request.client else 'unknown'}"
