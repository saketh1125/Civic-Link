"""Civic-Link DPI - Application Configuration"""

from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings with environment variable support."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Application
    debug: bool = True
    environment: str = "development"
    secret_key: str
    api_v1_prefix: str = "/api/v1"
    project_name: str = "Civic-Link DPI"

    # Database
    database_url: str = "postgresql+asyncpg://civic:civic_secret@localhost:5432/civic_link"
    postgis_srid: int = 4326

    # Redis
    redis_url: str = "redis://localhost:6379/0"
    redis_password: Optional[str] = None

    # Security — no defaults; must be provided via environment
    audit_log_encryption_key: str
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 7

    # Geospatial
    default_search_radius: int = 500  # meters
    max_search_radius: int = 2000  # meters

    # Cache TTL (seconds)
    commute_cache_ttl: int = 900  # 15 minutes
    user_cache_ttl: int = 3600  # 1 hour

    # Telemetry
    gyroscope_threshold: float = 1.5  # rad/s
    swerve_cooldown_ms: int = 60000  # 1 minute

    # GDPR/RTI Compliance
    anonymization_delay_hours: int = 24
    audit_log_retention_days: int = 90

    # Whitelisted Email Domains for Registration
    whitelisted_domains: list[str] = [
        "cmrcet.ac.in",
        "company.com",
        "govt.in",
        "hyderabadpolice.gov.in",
    ]

    @property
    def is_development(self) -> bool:
        return self.environment == "development"

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
