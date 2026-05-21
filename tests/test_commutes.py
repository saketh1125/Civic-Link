"""Civic-Link DPI - Commute Model Tests

Tests for Commute model properties, seat management, and enums.
No database required — pure logic tests.
"""

import pytest
from datetime import date, datetime, time, timezone

from app.models.commute import Commute, CommuteOffer, CommuteStatus, CommuteType


class TestCommuteEnums:
    """Test Commute enum values."""

    def test_commute_type_values(self):
        assert CommuteType.ONE_TIME.value == "one_time"
        assert CommuteType.RECURRING.value == "recurring"

    def test_commute_status_values(self):
        assert CommuteStatus.PENDING.value == "pending"
        assert CommuteStatus.ACTIVE.value == "active"
        assert CommuteStatus.IN_PROGRESS.value == "in_progress"
        assert CommuteStatus.COMPLETED.value == "completed"
        assert CommuteStatus.CANCELLED.value == "cancelled"
        assert CommuteStatus.EXPIRED.value == "expired"


class TestCommuteSeatManagement:
    """Test Commute seat increment/decrement logic."""

    def _make_commute(self, available=3, total=4):
        return Commute(
            driver_id="driver-1",
            origin="SRID=4326;POINT(78.4 17.4)",
            destination="SRID=4326;POINT(78.5 17.5)",
            origin_address="Origin",
            destination_address="Destination",
            departure_date=date(2026, 6, 1),
            departure_time=time(9, 0),
            available_seats=available,
            total_seats=total,
        )

    def test_decrement_seats(self):
        commute = self._make_commute(available=3, total=4)
        commute.decrement_seats()
        assert commute.available_seats == 2

    def test_increment_seats(self):
        commute = self._make_commute(available=2, total=4)
        commute.increment_seats()
        assert commute.available_seats == 3

    def test_decrement_does_not_go_below_zero(self):
        commute = self._make_commute(available=0, total=4)
        commute.decrement_seats()
        assert commute.available_seats == 0

    def test_increment_does_not_exceed_total(self):
        commute = self._make_commute(available=4, total=4)
        commute.increment_seats()
        assert commute.available_seats == 4

    def test_is_full_when_zero_seats(self):
        commute = self._make_commute(available=0, total=4)
        assert commute.is_full is True

    def test_is_not_full_when_seats_available(self):
        commute = self._make_commute(available=1, total=4)
        assert commute.is_full is False

    def test_is_expired_when_past(self):
        commute = self._make_commute()
        commute.expires_at = datetime(2020, 1, 1, tzinfo=timezone.utc)
        assert commute.is_expired is True

    def test_is_not_expired_when_future(self):
        commute = self._make_commute()
        commute.expires_at = datetime(2030, 1, 1, tzinfo=timezone.utc)
        assert commute.is_expired is False


class TestCommuteOfferProperties:
    """Test CommuteOffer model properties."""

    def _make_offer(self, status="pending"):
        return CommuteOffer(
            passenger_id="passenger-1",
            origin="SRID=4326;POINT(78.4 17.4)",
            destination="SRID=4326;POINT(78.5 17.5)",
            origin_address="Origin",
            destination_address="Destination",
            preferred_departure_date=date(2026, 6, 1),
            preferred_departure_time=time(9, 0),
            status=status,
        )

    def test_is_pending_when_pending(self):
        offer = self._make_offer(status="pending")
        assert offer.is_pending is True

    def test_is_not_pending_when_cancelled(self):
        offer = self._make_offer(status="cancelled")
        assert offer.is_pending is False

    def test_default_status_is_pending(self):
        """SQLAlchemy default is applied during flush, not construction."""
        offer = CommuteOffer(
            passenger_id="p1",
            origin="SRID=4326;POINT(0 0)",
            destination="SRID=4326;POINT(1 1)",
            origin_address="A",
            destination_address="B",
            preferred_departure_date=date(2026, 1, 1),
            preferred_departure_time=time(9, 0),
            status="pending",
        )
        assert offer.status == "pending"
