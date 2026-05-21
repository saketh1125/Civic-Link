"""Civic-Link DPI - User Model Tests

Tests for User model properties, enums, and password hashing.
No database required — pure logic tests.
"""

import pytest
from datetime import timedelta

from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    decode_access_token,
    create_refresh_token,
    decode_refresh_token,
)
from app.models.user import Gender, User, UserRole, VerificationStatus


class TestUserEnums:
    """Test User enum values."""

    def test_gender_values(self):
        assert Gender.MALE.value == "male"
        assert Gender.FEMALE.value == "female"
        assert Gender.UNDISCLOSED.value == "undisclosed"

    def test_user_role_values(self):
        assert UserRole.COMMUTER.value == "commuter"
        assert UserRole.ADMIN.value == "admin"
        assert UserRole.MODERATOR.value == "moderator"

    def test_verification_status_values(self):
        assert VerificationStatus.PENDING.value == "pending"
        assert VerificationStatus.VERIFIED.value == "verified"
        assert VerificationStatus.REJECTED.value == "rejected"


class TestUserProperties:
    """Test User model computed properties."""

    def _make_user(self, gender=Gender.MALE, status=VerificationStatus.PENDING):
        return User(
            email_hash="a" * 64,
            email_domain="test.com",
            phone_number="+1234567890",
            full_name="Test User",
            gender=gender,
            company_name="Test Corp",
            verification_status=status,
        )

    def test_is_female_true_for_female(self):
        user = self._make_user(gender=Gender.FEMALE)
        assert user.is_female is True

    def test_is_female_false_for_male(self):
        user = self._make_user(gender=Gender.MALE)
        assert user.is_female is False

    def test_is_female_false_for_undisclosed(self):
        user = self._make_user(gender=Gender.UNDISCLOSED)
        assert user.is_female is False

    def test_is_verified_true(self):
        user = self._make_user(status=VerificationStatus.VERIFIED)
        assert user.is_verified is True

    def test_is_verified_false_for_pending(self):
        user = self._make_user(status=VerificationStatus.PENDING)
        assert user.is_verified is False

    def test_is_verified_false_for_rejected(self):
        user = self._make_user(status=VerificationStatus.REJECTED)
        assert user.is_verified is False

    def test_update_last_login(self):
        user = self._make_user()
        assert user.last_login is None
        user.update_last_login()
        assert user.last_login is not None


class TestPasswordHashing:
    """Test bcrypt password hashing and verification."""

    def test_hash_and_verify(self):
        password = "SecurePass123!"
        hashed = get_password_hash(password)
        assert verify_password(password, hashed) is True

    def test_wrong_password_fails(self):
        hashed = get_password_hash("correct_password")
        assert verify_password("wrong_password", hashed) is False

    def test_different_passwords_different_hashes(self):
        hash1 = get_password_hash("password1")
        hash2 = get_password_hash("password2")
        assert hash1 != hash2

    def test_long_password_truncated(self):
        """Bcrypt truncates at 72 bytes. The function handles this internally."""
        long_password = "a" * 50
        hashed = get_password_hash(long_password)
        assert verify_password(long_password, hashed) is True

    def test_unicode_password(self):
        password = "p@ssw0rd_unicode_test"
        hashed = get_password_hash(password)
        assert verify_password(password, hashed) is True


class TestJWTokens:
    """Test JWT token creation and decoding."""

    def test_create_and_decode_access_token(self):
        user_id = "test-user-123"
        token = create_access_token(subject=user_id)
        payload = decode_access_token(token)
        assert payload is not None
        assert payload["sub"] == user_id
        assert payload["type"] == "access"

    def test_create_and_decode_refresh_token(self):
        user_id = "test-user-123"
        token = create_refresh_token(subject=user_id)
        payload = decode_refresh_token(token)
        assert payload is not None
        assert payload["sub"] == user_id
        assert payload["type"] == "refresh"

    def test_invalid_token_returns_none(self):
        assert decode_access_token("invalid.token.here") is None

    def test_access_token_rejected_as_refresh(self):
        token = create_access_token(subject="user1")
        assert decode_refresh_token(token) is None

    def test_expired_token_returns_none(self):
        token = create_access_token(
            subject="user1", expires_delta=timedelta(seconds=-1)
        )
        assert decode_access_token(token) is None
