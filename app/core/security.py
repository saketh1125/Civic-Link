"""Civic-Link DPI - Security Utilities

Password hashing using bcrypt and JWT token creation/verification.
"""

from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings

settings = get_settings()

# Password hashing context using bcrypt
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain password against a bcrypt hash.
    
    Bcrypt has a 72-byte limit. We truncate to 72 bytes (not chars)
    to handle multi-byte characters safely.
    
    Args:
        plain_password: The plain text password from user input
        hashed_password: The stored bcrypt hash
        
    Returns:
        True if password matches, False otherwise
    """
    # Bcrypt algorithm limit: 72 bytes maximum
    # Truncate by bytes to handle multi-byte UTF-8 characters safely
    truncated_password = plain_password.encode('utf-8')[:72].decode('utf-8', 'ignore')
    return pwd_context.verify(truncated_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Generate a bcrypt hash from a plain password.
    
    Bcrypt has a 72-byte limit. We truncate to 72 bytes (not chars)
    to handle multi-byte characters safely.
    
    Args:
        password: The plain text password to hash
        
    Returns:
        Bcrypt hashed password string
    """
    # Bcrypt algorithm limit: 72 bytes maximum
    # Truncate by bytes to handle multi-byte UTF-8 characters safely
    truncated_password = password.encode('utf-8')[:72].decode('utf-8', 'ignore')
    return pwd_context.hash(truncated_password)


def create_access_token(
    subject: str,
    expires_delta: Optional[timedelta] = None
) -> str:
    """Create a JWT access token.
    
    Args:
        subject: The user ID to encode in the token (sub claim)
        expires_delta: Optional custom expiration time. Defaults to 60 minutes.
        
    Returns:
        Encoded JWT token string
    """
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(
            minutes=settings.access_token_expire_minutes
        )
    
    to_encode = {
        "sub": subject,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "type": "access"
    }
    
    encoded_jwt = jwt.encode(
        to_encode,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm
    )
    return encoded_jwt


def decode_access_token(token: str) -> Optional[dict]:
    """Decode and validate a JWT access token.
    
    Args:
        token: The JWT token string to decode
        
    Returns:
        Decoded token payload dict if valid, None if invalid
    """
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm]
        )
        return payload
    except JWTError:
        return None
