"""Civic-Link DPI - Authentication API Endpoints

User registration and login with JWT token generation.
"""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_user, get_current_user_unverified
from app.core.config import get_settings
from app.core.database import get_db
from app.core.security import create_access_token, get_password_hash, verify_password
from app.models.user import Gender, User, UserRole, VerificationStatus

router = APIRouter()
settings = get_settings()


# Request/Response Schemas
class UserRegisterRequest(BaseModel):
    """Request model for user registration (Zero-Liability)."""
    
    email_hash: str = Field(
        ...,
        min_length=64,
        max_length=64,
        description="SHA-256 hash of corporate email",
        example="12b9adeb0dd75783f55efa7bedb52b448267daa7ad659dda992fe7621fe12ae4",
    )
    email_domain: str = Field(
        ...,
        description="Corporate email domain",
        example="police.gov.in",
    )
    password: str = Field(
        ...,
        min_length=8,
        description="Password (min 8 characters)",
        example="SecurePass123!",
    )
    full_name: str = Field(
        ...,
        min_length=2,
        max_length=255,
        description="Full name",
        example="John Doe",
    )
    phone_number: str = Field(
        ...,
        description="Phone number",
        example="+91-98765-43210",
    )
    gender: Gender = Field(
        ...,
        description="Gender for women-only safety matching",
        example="male",
    )
    company_name: str = Field(
        ...,
        description="Company or organization name",
        example="TechCorp India",
    )
    employee_id: Optional[str] = Field(
        None,
        description="Optional employee ID",
        example="EMP12345",
    )
    
    @field_validator("email_domain")
    @classmethod
    def validate_whitelisted_domain(cls, v: str) -> str:
        """Validate that email domain is whitelisted."""
        domain = v.lower()
        
        whitelisted = [d.lower() for d in settings.whitelisted_domains]
        
        if domain not in whitelisted:
            raise ValueError(
                f"Email domain '{domain}' is not authorized. "
                f"Allowed domains: {', '.join(settings.whitelisted_domains)}"
            )
        return v


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


class TokenResponse(BaseModel):
    """Response model for successful authentication."""
    
    access_token: str = Field(
        ...,
        description="JWT access token",
    )
    token_type: str = Field(
        default="bearer",
        description="Token type",
    )
    expires_in: int = Field(
        ...,
        description="Token expiration time in seconds",
    )


class UserResponse(BaseModel):
    """Response model for user data."""
    
    id: str
    email_domain: str
    full_name: str
    gender: Gender
    company_name: str
    role: UserRole
    is_verified: bool
    
    class Config:
        from_attributes = True


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
    description="""
    Register a new user with Zero-Liability privacy.
    
    The client hashes the email and provides the domain.
    Raw emails NEVER reach the server.
    
    Email domain must be in the whitelist:
    - cmrcet.ac.in
    - company.com
    - govt.in
    - hyderabadpolice.gov.in
    """,
)
async def register(
    request: UserRegisterRequest,
    session: AsyncSession = Depends(get_db),
) -> UserResponse:
    """Register a new user.
    
    Args:
        request: Registration details (Privacy-enhanced)
        session: Database session
        
    Returns:
        Created user data
        
    Raises:
        HTTPException: 400 if email or phone already exists
    """
    # Check if email already exists
    result = await session.execute(
        select(User).where(User.email_hash == request.email_hash)
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    
    # Check if phone number already exists
    result = await session.execute(
        select(User).where(User.phone_number == request.phone_number)
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered",
        )
    
    # Create new user
    password_hash = get_password_hash(request.password)
    
    user = User(
        email_hash=request.email_hash,
        email_domain=request.email_domain,
        phone_number=request.phone_number,
        full_name=request.full_name,
        gender=request.gender,
        company_name=request.company_name,
        employee_id=request.employee_id,
        password_hash=password_hash,
        verification_status=VerificationStatus.PENDING,
        role=UserRole.COMMUTER,
    )
    
    session.add(user)
    await session.commit()
    await session.refresh(user)
    
    return UserResponse(
        id=str(user.id),
        email_domain=user.email_domain,
        full_name=user.full_name,
        gender=user.gender,
        company_name=user.company_name,
        role=user.role,
        is_verified=user.is_verified,
    )


@router.post(
    "/login/access-token",
    response_model=TokenResponse,
    summary="Login and get JWT access token",
    description="""
    Zero-Liability login endpoint.
    
    The client transmits email_hash and email_domain.
    Raw emails NEVER reach the server.
    """,
)
async def login_access_token(
    request: UserLoginRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Authenticate user and issue JWT access token.
    
    Args:
        request: Login details (Privacy-enhanced)
        session: Database session
        
    Returns:
        JWT access token
        
    Raises:
        HTTPException: 401 if credentials are invalid
    """
    # Query user by email hash
    result = await session.execute(
        select(User).where(User.email_hash == request.email_hash)
    )
    user = result.scalar_one_or_none()
    
    # Verify user exists and password is correct
    if not user or not user.password_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    
    if not verify_password(request.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    
    # Update last login timestamp
    user.update_last_login()
    await session.commit()
    
    # Create access token
    access_token = create_access_token(subject=str(user.id))
    
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=settings.access_token_expire_minutes * 60,
    )


class VerifyAccountRequest(BaseModel):
    """Request model for account verification (placeholder)."""

    token: str = Field(
        ...,
        description="Verification token (currently: user ID as placeholder)",
    )


class VerifyAccountResponse(BaseModel):
    """Response model for successful verification."""

    id: str
    is_verified: bool
    message: str

    class Config:
        from_attributes = True


@router.post(
    "/verify",
    response_model=VerifyAccountResponse,
    summary="Verify user account",
    description="""
    Verify a user account using a verification token.

    NOTE: This is a placeholder implementation. In production, this should
    accept an email verification token sent via a real email service.
    Currently accepts the user's own ID as the token for development.
    """,
)
async def verify_account(
    request: VerifyAccountRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user_unverified),
) -> VerifyAccountResponse:
    """Verify user account.

    Placeholder: accepts user ID as token. Real email flow is a later task.

    Args:
        request: Verification token
        session: Database session
        current_user: Authenticated user (verified or not)

    Returns:
        Verification confirmation

    Raises:
        HTTPException: 400 if token is invalid
    """
    if request.token != str(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification token",
        )

    current_user.verification_status = VerificationStatus.VERIFIED
    await session.commit()

    return VerifyAccountResponse(
        id=str(current_user.id),
        is_verified=True,
        message="Account verified successfully",
    )


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get current user profile",
    description="Get the profile of the currently authenticated user.",
)
async def get_current_user_profile(
    current_user: User = Depends(get_current_active_user),
) -> UserResponse:
    """Get current authenticated user's profile.
    
    Args:
        current_user: User from auth dependency
        
    Returns:
        Current user data
    """
    return UserResponse(
        id=str(current_user.id),
        email_domain=current_user.email_domain,
        full_name=current_user.full_name,
        gender=current_user.gender,
        company_name=current_user.company_name,
        role=current_user.role,
        is_verified=current_user.is_verified,
    )
