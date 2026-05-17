"""Civic-Link DPI - FastAPI Application Entry Point"""

import logging
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from app.api.v1.api import api_router
from app.core.config import get_settings
from app.core.database import close_db, init_db
from app.core.exceptions import (
    AuditLogError,
    AuthenticationError,
    AuthorizationError,
    CivicLinkException,
    CivicLinkSafetyException,
    CommuteNotFoundError,
    GeospatialConflictError,
    InvalidStateTransitionError,
    MatchNotFoundError,
    RateLimitError,
    UserNotFoundError,
    ValidationError as CivicValidationError,
)
from app.core.redis import close_redis, init_redis
from app.middleware.rate_limit import RateLimitMiddleware

settings = get_settings()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan context manager.

    Handles startup and shutdown events:
    - Database initialization (create_all only in development)
    - Redis connection pool initialization
    """
    # Startup
    await init_db()

    # Gate create_all() to development only — production uses Alembic
    if settings.is_development:
        logger.info("Development mode: database tables ensured via create_all()")
    else:
        logger.info("Production mode: database managed by Alembic migrations")

    await init_redis()

    yield

    # Shutdown
    await close_redis()
    await close_db()


app = FastAPI(
    title=settings.project_name,
    version="0.2.1",
    description="Civic-Link DPI - Carpooling Digital Public Infrastructure",
    lifespan=lifespan,
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.is_development else [],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Rate limiting middleware (gracefully degrades if Redis unavailable)
app.add_middleware(RateLimitMiddleware)

# Include API routers
app.include_router(api_router, prefix=settings.api_v1_prefix)


# =============================================================================
# EXCEPTION HANDLERS
# =============================================================================


def _build_error_response(
    error: str,
    code: str,
    status_code: int,
    detail: str | None = None,
    request: Request | None = None,
) -> JSONResponse:
    """Build a structured JSON error response."""
    request_id = str(uuid.uuid4())
    if request:
        request_id = request.headers.get("x-request-id", request_id)

    body = {
        "error": error,
        "code": code,
        "request_id": request_id,
    }
    if detail:
        body["detail"] = detail

    return JSONResponse(status_code=status_code, content=body)


@app.exception_handler(CivicLinkSafetyException)
async def safety_exception_handler(
    request: Request, exc: CivicLinkSafetyException
) -> JSONResponse:
    logger.error("Safety violation: %s", exc.message, exc_info=False)
    return _build_error_response(
        error=exc.message,
        code=exc.code or "SAFETY_VIOLATION",
        status_code=status.HTTP_400_BAD_REQUEST,
        request=request,
    )


@app.exception_handler(GeospatialConflictError)
async def geospatial_exception_handler(
    request: Request, exc: GeospatialConflictError
) -> JSONResponse:
    return _build_error_response(
        error=exc.message,
        code=exc.code or "GEOSPATIAL_CONFLICT",
        status_code=status.HTTP_409_CONFLICT,
        request=request,
    )


@app.exception_handler(AuditLogError)
async def audit_error_handler(request: Request, exc: AuditLogError) -> JSONResponse:
    logger.error("Audit log error: %s", exc.message)
    return _build_error_response(
        error=exc.message,
        code=exc.code or "AUDIT_LOG_ERROR",
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        request=request,
    )


@app.exception_handler(UserNotFoundError)
async def user_not_found_handler(request: Request, exc: UserNotFoundError) -> JSONResponse:
    return _build_error_response(
        error=exc.message,
        code=exc.code or "USER_NOT_FOUND",
        status_code=status.HTTP_404_NOT_FOUND,
        request=request,
    )


@app.exception_handler(CommuteNotFoundError)
async def commute_not_found_handler(
    request: Request, exc: CommuteNotFoundError
) -> JSONResponse:
    return _build_error_response(
        error=exc.message,
        code=exc.code or "COMMUTE_NOT_FOUND",
        status_code=status.HTTP_404_NOT_FOUND,
        request=request,
    )


@app.exception_handler(MatchNotFoundError)
async def match_not_found_handler(request: Request, exc: MatchNotFoundError) -> JSONResponse:
    return _build_error_response(
        error=exc.message,
        code=exc.code or "MATCH_NOT_FOUND",
        status_code=status.HTTP_404_NOT_FOUND,
        request=request,
    )


@app.exception_handler(CivicValidationError)
async def civic_validation_handler(
    request: Request, exc: CivicValidationError
) -> JSONResponse:
    return _build_error_response(
        error=exc.message,
        code=exc.code or "VALIDATION_ERROR",
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail=exc.field,
        request=request,
    )


@app.exception_handler(AuthenticationError)
async def auth_error_handler(request: Request, exc: AuthenticationError) -> JSONResponse:
    return _build_error_response(
        error=exc.message,
        code=exc.code or "AUTHENTICATION_ERROR",
        status_code=status.HTTP_401_UNAUTHORIZED,
        request=request,
    )


@app.exception_handler(AuthorizationError)
async def authorization_handler(request: Request, exc: AuthorizationError) -> JSONResponse:
    return _build_error_response(
        error=exc.message,
        code=exc.code or "AUTHORIZATION_ERROR",
        status_code=status.HTTP_403_FORBIDDEN,
        request=request,
    )


@app.exception_handler(RateLimitError)
async def rate_limit_handler(request: Request, exc: RateLimitError) -> JSONResponse:
    return _build_error_response(
        error=exc.message,
        code=exc.code or "RATE_LIMIT_EXCEEDED",
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        request=request,
    )


@app.exception_handler(InvalidStateTransitionError)
async def invalid_state_transition_handler(
    request: Request, exc: InvalidStateTransitionError
) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={
            "error": "INVALID_STATE_TRANSITION",
            "current_state": exc.current_state,
            "attempted": exc.attempted,
        },
    )


@app.exception_handler(CivicLinkException)
async def civic_link_exception_handler(
    request: Request, exc: CivicLinkException
) -> JSONResponse:
    """Catch-all for any CivicLinkException not handled by a more specific handler."""
    return _build_error_response(
        error=exc.message,
        code=exc.code or "INTERNAL_ERROR",
        status_code=status.HTTP_400_BAD_REQUEST,
        request=request,
    )


@app.exception_handler(RequestValidationError)
async def request_validation_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    """Handle Pydantic/FastAPI request validation errors."""
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": "Validation error",
            "code": "REQUEST_VALIDATION_ERROR",
            "detail": exc.errors(),
        },
    )


@app.exception_handler(ValidationError)
async def pydantic_validation_handler(
    request: Request, exc: ValidationError
) -> JSONResponse:
    """Handle Pydantic model validation errors."""
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": "Validation error",
            "code": "MODEL_VALIDATION_ERROR",
            "detail": exc.errors(),
        },
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Fallback handler for unhandled exceptions.

    Never exposes internal stack traces or raw exception messages to clients.
    Logs the full traceback via structlog for debugging.
    """
    request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
    logger.exception(
        "Unhandled exception",
        extra={
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
        },
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "Internal server error",
            "code": "INTERNAL_ERROR",
            "request_id": request_id,
        },
    )


# =============================================================================
# ENDPOINTS
# =============================================================================


@app.get("/health", status_code=status.HTTP_200_OK)
async def health_check() -> dict:
    """Health check endpoint for container orchestration."""
    return {
        "status": "healthy",
        "service": settings.project_name,
        "version": "0.2.1",
    }


@app.get("/")
async def root() -> dict:
    """Root endpoint with API information."""
    return {
        "name": settings.project_name,
        "version": "0.2.1",
        "docs": "/docs" if settings.debug else None,
        "api_prefix": settings.api_v1_prefix,
    }
