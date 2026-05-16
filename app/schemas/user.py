"""Civic-Link DPI - User Schemas

Pydantic models for user API request/response validation.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.models.user import Gender, UserRole, VerificationStatus


# =============================================================================
# REQUEST SCHEMAS
# =============================================================================


class UserRegisterRequest(BaseModel):
    """Request model for user registration (Zero-Liability)."""

    email_hash: str = Field(
        ...,
        min_length=64,
        max_length=64,
        description="SHA-256 hash of corporate email",
    )
    email_domain: str = Field(
        ...,
        description="Corporate email domain",
    )
    password: str = Field(
        ...,
        min_length=8,
        description="Password (min 8 characters)",
    )
    full_name: str = Field(
        ...,
        min_length=2,
        max_length=255,
        description="Full name",
    )
    phone_number: str = Field(
        ...,
        description="Phone number",
    )
    gender: Gender = Field(
        ...,
        description="Gender for women-only safety matching",
    )
    company_name: str = Field(
        ...,
        description="Company or organization name",
    )
    employee_id: Optional[str] = Field(
        None,
        description="Optional employee ID",
    )


class UserLoginRequest(BaseModel):
    """Request model for user login (Zero-Liability)."""

    email_hash: str = Field(
        ...,
        min_length=64,
        max_length=64,
        description="SHA-256 hash of corporate email",
    )
    email_domain: str = Field(
        ...,
        description="Corporate email domain",
    )
    password: str = Field(
        ...,
        description="Password",
    )


class UserProfileUpdate(BaseModel):
    """Request model for updating user profile."""

    full_name: Optional[str] = Field(
        None,
        min_length=2,
        max_length=255,
    )
    phone_number: Optional[str] = None
    employee_id: Optional[str] = None
    company_name: Optional[str] = None


# =============================================================================
# RESPONSE SCHEMAS
# =============================================================================


class TokenResponse(BaseModel):
    """Response model for successful authentication."""

    access_token: str = Field(..., description="JWT access token")
    token_type: str = Field(default="bearer", description="Token type")
    expires_in: int = Field(..., description="Token expiration time in seconds")


class UserResponse(BaseModel):
    """Response model for user data."""

    id: str
    email_domain: str
    full_name: str
    gender: Gender
    company_name: str
    role: UserRole
    is_verified: bool
    last_login: Optional[datetime] = None

    class Config:
        from_attributes = True


class CivicScoreResponse(BaseModel):
    """Response model for civic score embedded in user profile."""

    score: float
    score_tier: str
    total_trips: int
    swerve_count: int
    speeding_count: int
    hard_braking_count: int

    class Config:
        from_attributes = True


class UserProfileResponse(UserResponse):
    """Extended user profile with civic score."""

    civic_score: Optional[CivicScoreResponse] = None
