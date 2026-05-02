"""Civic-Link DPI - FastAPI Application Entry Point"""

from contextlib import asynccontextmanager

from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.api import api_router
from app.core.config import get_settings
from app.core.database import close_db, init_db

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan context manager.

    Handles startup and shutdown events.
    """
    # Startup
    await init_db()
    yield
    # Shutdown
    await close_db()


app = FastAPI(
    title=settings.project_name,
    version="0.1.0",
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

# Include API routers
app.include_router(api_router, prefix=settings.api_v1_prefix)


@app.get("/health", status_code=status.HTTP_200_OK)
async def health_check() -> dict:
    """Health check endpoint for container orchestration."""
    return {
        "status": "healthy",
        "service": settings.project_name,
        "version": "0.1.0",
    }


@app.get("/")
async def root() -> dict:
    """Root endpoint with API information."""
    return {
        "name": settings.project_name,
        "version": "0.1.0",
        "docs": "/docs" if settings.debug else None,
        "api_prefix": settings.api_v1_prefix,
    }
