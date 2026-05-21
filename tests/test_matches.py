"""Civic-Link DPI - Match Model Tests

Tests for CommuteMatch status transitions, properties, and safety flags.
No database required — pure logic tests.
"""

import pytest

from app.models.match import CommuteMatch, MatchStatus, PaymentStatus


class TestMatchEnums:
    """Test Match enum values."""

    def test_match_status_values(self):
        assert MatchStatus.PENDING.value == "pending"
        assert MatchStatus.CONFIRMED.value == "confirmed"
        assert MatchStatus.IN_PROGRESS.value == "in_progress"
        assert MatchStatus.COMPLETED.value == "completed"
        assert MatchStatus.CANCELLED.value == "cancelled"
        assert MatchStatus.NO_SHOW.value == "no_show"

    def test_payment_status_values(self):
        assert PaymentStatus.PENDING.value == "pending"
        assert PaymentStatus.COMPLETED.value == "completed"
        assert PaymentStatus.FAILED.value == "failed"
        assert PaymentStatus.REFUNDED.value == "refunded"


class TestMatchStatusTransitions:
    """Test CommuteMatch status transition methods."""

    def _make_match(self, status=MatchStatus.PENDING):
        return CommuteMatch(
            commute_id="commute-1",
            driver_id="driver-1",
            passenger_id="passenger-1",
            status=status,
            pickup_radius_meters=100,
        )

    def test_confirm_sets_status(self):
        match = self._make_match(MatchStatus.PENDING)
        match.confirm()
        assert match.status == MatchStatus.CONFIRMED
        assert match.confirmed_at is not None

    def test_start_sets_status(self):
        match = self._make_match(MatchStatus.CONFIRMED)
        match.start()
        assert match.status == MatchStatus.IN_PROGRESS
        assert match.started_at is not None

    def test_complete_sets_status(self):
        match = self._make_match(MatchStatus.IN_PROGRESS)
        match.complete()
        assert match.status == MatchStatus.COMPLETED
        assert match.completed_at is not None

    def test_cancel_sets_status(self):
        match = self._make_match(MatchStatus.PENDING)
        match.cancel()
        assert match.status == MatchStatus.CANCELLED
        assert match.cancelled_at is not None

    def test_cancel_from_confirmed(self):
        match = self._make_match(MatchStatus.CONFIRMED)
        match.cancel()
        assert match.status == MatchStatus.CANCELLED


class TestMatchDefaults:
    """Test CommuteMatch default values."""

    def test_default_status_is_pending(self):
        """SQLAlchemy default is applied during flush, not construction."""
        match = CommuteMatch(
            commute_id="c1",
            driver_id="d1",
            passenger_id="p1",
            pickup_radius_meters=100,
            status=MatchStatus.PENDING,
        )
        assert match.status == MatchStatus.PENDING

    def test_default_payment_status_is_pending(self):
        match = CommuteMatch(
            commute_id="c1",
            driver_id="d1",
            passenger_id="p1",
            pickup_radius_meters=100,
            payment_status=PaymentStatus.PENDING,
        )
        assert match.payment_status == PaymentStatus.PENDING

    def test_default_women_only_flags_false(self):
        match = CommuteMatch(
            commute_id="c1",
            driver_id="d1",
            passenger_id="p1",
            pickup_radius_meters=100,
            commute_was_women_only=False,
            offer_was_women_only=False,
        )
        assert match.commute_was_women_only is False
        assert match.offer_was_women_only is False

    def test_timestamps_initially_none(self):
        match = CommuteMatch(
            commute_id="c1",
            driver_id="d1",
            passenger_id="p1",
            pickup_radius_meters=100,
            status=MatchStatus.PENDING,
        )
        assert match.confirmed_at is None
        assert match.started_at is None
        assert match.completed_at is None
        assert match.cancelled_at is None

    def test_ratings_initially_none(self):
        match = CommuteMatch(
            commute_id="c1",
            driver_id="d1",
            passenger_id="p1",
            pickup_radius_meters=100,
            status=MatchStatus.PENDING,
        )
        assert match.driver_rating is None
        assert match.passenger_rating is None
        assert match.driver_review is None
        assert match.passenger_review is None


class TestMatchSafetyFlags:
    """Test safety flag snapshot behavior."""

    def test_women_only_flags_preserved(self):
        match = CommuteMatch(
            commute_id="c1",
            driver_id="d1",
            passenger_id="p1",
            pickup_radius_meters=100,
            commute_was_women_only=True,
            offer_was_women_only=True,
        )
        assert match.commute_was_women_only is True
        assert match.offer_was_women_only is True

    def test_mixed_safety_flags(self):
        match = CommuteMatch(
            commute_id="c1",
            driver_id="d1",
            passenger_id="p1",
            pickup_radius_meters=100,
            commute_was_women_only=True,
            offer_was_women_only=False,
        )
        assert match.commute_was_women_only is True
        assert match.offer_was_women_only is False
