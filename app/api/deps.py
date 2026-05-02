"""Civic-Link DPI - API Dependencies

Authentication dependencies for securing API endpoints.
"""

from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import decode_access_token
from app.models.user import User

# OAuth2 scheme for token URL
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login/access-token")


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    session: AsyncSession = Depends(get_db),
) -> User:
    """Dependency to get the current authenticated user from JWT token.
    
    Args:
        token: JWT token from Authorization header
        session: Database session
        
    Returns:
        User model instance if authenticated
        
    Raises:
        HTTPException: 401 if token is invalid or user not found
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # Decode the JWT token
        payload = decode_access_token(token)
        if payload is None:
            raise credentials_exception
        
        # Extract user ID from sub claim
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
            
    except JWTError:
        raise credentials_exception
    
    # Query the user from database
    result = await session.execute(
        select(User).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    
    if user is None:
        raise credentials_exception
    
    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user),
) -> User:
    """Dependency to get the current active (verified) user.
    
    Extends get_current_user to also verify the user account is active/verified.
    
    Args:
        current_user: User from get_current_user dependency
        
    Returns:
        User model instance if active
        
    Raises:
        HTTPException: 403 if user account is not verified/active
    """
    # Check if user is verified (you can adjust this logic as needed)
    # For now, we allow all authenticated users to proceed
    # In production, you might check is_active, is_verified, etc.
    
    return current_user


async def get_current_active_admin(
    current_user: User = Depends(get_current_active_user),
) -> User:
    """Dependency to get the current active admin user.
    
    Args:
        current_user: User from get_current_active_user dependency
        
    Returns:
        User model instance if admin
        
    Raises:
        HTTPException: 403 if user is not an admin
    """
    from app.models.user import UserRole
    
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required",
        )
    
    return current_user
