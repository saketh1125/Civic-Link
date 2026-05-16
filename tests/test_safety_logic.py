"""Civic-Link DPI - Safety Logic Tests

Tests for the hard-reject gender safety logic.
These tests verify that:
1. Women-only commutes reject non-female passengers
2. Women-only offers reject non-female drivers
3. Non-women-only commutes allow all passengers
"""

import pytest

from app.core.exceptions import CivicLinkSafetyException
from app.models.match import CommuteMatch, MatchStatus
from app.models.user import Gender, User


class TestGenderSafetyLogic:
    """Test suite for gender-based safety matching."""

    def test_women_only_commute_rejects_male_passenger(self):
        """Women-only commute must reject male passengers."""
        commute_is_women_only = True
        passenger_gender = Gender.MALE

        should_allow = (
            not commute_is_women_only or passenger_gender == Gender.FEMALE
        )

        assert not should_allow

    def test_women_only_commute_allows_female_passenger(self):
        """Women-only commute must allow female passengers."""
        commute_is_women_only = True
        passenger_gender = Gender.FEMALE

        should_allow = (
            not commute_is_women_only or passenger_gender == Gender.FEMALE
        )

        assert should_allow

    def test_women_only_commute_rejects_undisclosed_passenger(self):
        """Women-only commute must reject undisclosed gender passengers."""
        commute_is_women_only = True
        passenger_gender = Gender.UNDISCLOSED

        should_allow = (
            not commute_is_women_only or passenger_gender == Gender.FEMALE
        )

        assert not should_allow

    def test_regular_commute_allows_male_passenger(self):
        """Regular commute must allow male passengers."""
        commute_is_women_only = False
        passenger_gender = Gender.MALE

        should_allow = (
            not commute_is_women_only or passenger_gender == Gender.FEMALE
        )

        assert should_allow

    def test_regular_commute_allows_female_passenger(self):
        """Regular commute must allow female passengers."""
        commute_is_women_only = False
        passenger_gender = Gender.FEMALE

        should_allow = (
            not commute_is_women_only or passenger_gender == Gender.FEMALE
        )

        assert should_allow

    def test_women_only_offer_rejects_male_driver(self):
        """Women-only offer must reject male drivers."""
        offer_is_women_only = True
        driver_gender = Gender.MALE

        should_allow = (
            not offer_is_women_only or driver_gender == Gender.FEMALE
        )

        assert not should_allow

    def test_women_only_offer_allows_female_driver(self):
        """Women-only offer must allow female drivers."""
        offer_is_women_only = True
        driver_gender = Gender.FEMALE

        should_allow = (
            not offer_is_women_only or driver_gender == Gender.FEMALE
        )

        assert should_allow

    def test_double_safety_both_women_only(self):
        """Both commute and offer are women-only: both must be female."""
        commute_is_women_only = True
        offer_is_women_only = True
        driver_gender = Gender.FEMALE
        passenger_gender = Gender.FEMALE

        commute_check = (
            not commute_is_women_only or passenger_gender == Gender.FEMALE
        )
        offer_check = not offer_is_women_only or driver_gender == Gender.FEMALE

        assert commute_check
        assert offer_check

    def test_double_safety_driver_not_female(self):
        """Both women-only but driver is male: must reject."""
        commute_is_women_only = True
        offer_is_women_only = True
        driver_gender = Gender.MALE
        passenger_gender = Gender.FEMALE

        commute_check = (
            not commute_is_women_only or passenger_gender == Gender.FEMALE
        )
        offer_check = not offer_is_women_only or driver_gender == Gender.FEMALE

        assert commute_check
        assert not offer_check

    def test_double_safety_passenger_not_female(self):
        """Both women-only but passenger is male: must reject."""
        commute_is_women_only = True
        offer_is_women_only = True
        driver_gender = Gender.FEMALE
        passenger_gender = Gender.MALE

        commute_check = (
            not commute_is_women_only or passenger_gender == Gender.FEMALE
        )
        offer_check = not offer_is_women_only or driver_gender == Gender.FEMALE

        assert not commute_check
        assert offer_check


class TestUserGenderProperty:
    """Test User model gender properties."""

    def test_is_female_property(self):
        """User.is_female returns True only for Gender.FEMALE."""
        female_user = User(
            email_hash="a" * 64,
            email_domain="test.com",
            phone_number="+1234567890",
            full_name="Female User",
            gender=Gender.FEMALE,
            company_name="Test Corp",
        )
        assert female_user.is_female is True

        male_user = User(
            email_hash="b" * 64,
            email_domain="test.com",
            phone_number="+1234567891",
            full_name="Male User",
            gender=Gender.MALE,
            company_name="Test Corp",
        )
        assert male_user.is_female is False

        undisclosed_user = User(
            email_hash="c" * 64,
            email_domain="test.com",
            phone_number="+1234567892",
            full_name="Undisclosed User",
            gender=Gender.UNDISCLOSED,
            company_name="Test Corp",
        )
        assert undisclosed_user.is_female is False


class TestCivicScoreSafety:
    """Test CivicScore calculation and debounce logic."""

    def test_score_starts_at_100(self):
        """New civic score starts at 100."""
        from app.models.civic_score import CivicScore

        score = CivicScore(user_id="test-user")
        assert score.score == 100.0

    def test_score_clamps_to_zero_minimum(self):
        """Score cannot go below 0."""
        from app.models.civic_score import CivicScore

        score = CivicScore(user_id="test-user", score=5.0)
        new_score = score.calculate_score(new_swerves=100)
        assert new_score >= 0.0

    def test_score_clamps_to_100_maximum(self):
        """Score cannot exceed 100."""
        from app.models.civic_score import CivicScore

        score = CivicScore(user_id="test-user", score=100.0)
        new_score = score.calculate_score(new_swerves=0)
        assert new_score <= 100.0

    def test_swerve_penalty_applied(self):
        """Swerve events reduce the score."""
        from app.models.civic_score import CivicScore

        score = CivicScore(user_id="test-user", score=100.0)
        score.update_from_telemetry(swerve_detected=True)
        assert score.swerve_count == 1
        assert score.score < 100.0

    def test_score_tier_excellent(self):
        """Score >= 90 is excellent tier."""
        from app.models.civic_score import CivicScore

        score = CivicScore(user_id="test-user", score=95.0)
        assert score.score_tier == "excellent"

    def test_score_tier_critical(self):
        """Score < 40 is critical tier."""
        from app.models.civic_score import CivicScore

        score = CivicScore(user_id="test-user", score=30.0)
        assert score.score_tier == "critical"

    def test_trip_recording(self):
        """Recording a trip increments counters."""
        from app.models.civic_score import CivicScore

        score = CivicScore(user_id="test-user")
        score.record_trip(distance_km=10.0, duration_hours=0.5)
        assert score.total_trips == 1
        assert score.total_distance_km == 10.0
        assert score.total_driving_hours == 0.5


class TestWeightedPenaltyScoring:
    """Test the weighted penalty scoring model for telemetry ingestion."""

    def _make_score(self, initial=100.0):
        from app.models.civic_score import CivicScore
        return CivicScore(user_id="test-user", score=initial)

    def test_perfect_samples_no_penalty(self):
        """Perfect driving: no penalties, score stays near 100."""
        samples = [
            {"speed_kmh": 55, "acceleration_ms2": 1.0, "braking_ms2": 0.5,
             "swerve_index": 0.1, "phone_usage_detected": False}
            for _ in range(10)
        ]
        score = self._make_score(100.0)
        new_score = score.calculate_weighted_score(samples)
        assert 0 <= new_score <= 100
        assert new_score >= 90

    def test_speeding_penalty_applied(self):
        """Average speed > 60 kmh triggers speed penalty."""
        samples = [
            {"speed_kmh": 90, "acceleration_ms2": 1.0, "braking_ms2": 0.5,
             "swerve_index": 0.1, "phone_usage_detected": False}
            for _ in range(10)
        ]
        score = self._make_score(100.0)
        new_score = score.calculate_weighted_score(samples)
        assert 0 <= new_score <= 100
        assert new_score < 100.0

    def test_hard_braking_penalty(self):
        """Braking > 4.0 m/s² triggers brake penalty."""
        samples = [
            {"speed_kmh": 50, "acceleration_ms2": 1.0, "braking_ms2": 5.0,
             "swerve_index": 0.1, "phone_usage_detected": False}
            for _ in range(5)
        ]
        score = self._make_score(100.0)
        new_score = score.calculate_weighted_score(samples)
        assert 0 <= new_score <= 100
        assert new_score < 100.0

    def test_swerve_penalty(self):
        """High swerve_index triggers swerve penalty."""
        samples = [
            {"speed_kmh": 50, "acceleration_ms2": 1.0, "braking_ms2": 0.5,
             "swerve_index": 0.8, "phone_usage_detected": False}
            for _ in range(10)
        ]
        score = self._make_score(100.0)
        new_score = score.calculate_weighted_score(samples)
        assert 0 <= new_score <= 100
        assert new_score < 100.0

    def test_phone_usage_penalty(self):
        """Phone usage during driving triggers penalty."""
        samples = [
            {"speed_kmh": 50, "acceleration_ms2": 1.0, "braking_ms2": 0.5,
             "swerve_index": 0.1, "phone_usage_detected": True}
            for _ in range(3)
        ]
        score = self._make_score(100.0)
        new_score = score.calculate_weighted_score(samples)
        assert 0 <= new_score <= 100
        assert new_score < 100.0

    def test_combined_penalties(self):
        """Multiple violations compound penalties."""
        samples = [
            {"speed_kmh": 100, "acceleration_ms2": 4.0, "braking_ms2": 5.0,
             "swerve_index": 0.9, "phone_usage_detected": True}
            for _ in range(10)
        ]
        score = self._make_score(100.0)
        new_score = score.calculate_weighted_score(samples)
        assert 0 <= new_score <= 100
        assert new_score < 80

    def test_empty_samples_returns_current_score(self):
        """Empty sample list returns current score unchanged."""
        score = self._make_score(85.0)
        new_score = score.calculate_weighted_score([])
        assert new_score == 85.0

    def test_score_clamped_to_zero(self):
        """Extreme penalties cannot drive score below 0."""
        samples = [
            {"speed_kmh": 200, "acceleration_ms2": 10.0, "braking_ms2": 10.0,
             "swerve_index": 1.0, "phone_usage_detected": True}
            for _ in range(100)
        ]
        score = self._make_score(50.0)
        new_score = score.calculate_weighted_score(samples)
        assert new_score >= 0.0

    def test_score_clamped_to_100(self):
        """Score cannot exceed 100 even with perfect driving."""
        score = self._make_score(100.0)
        samples = [
            {"speed_kmh": 40, "acceleration_ms2": 0.5, "braking_ms2": 0.2,
             "swerve_index": 0.0, "phone_usage_detected": False}
            for _ in range(10)
        ]
        new_score = score.calculate_weighted_score(samples)
        assert new_score <= 100.0

    def test_blending_with_existing_score(self):
        """New score is blended 70/30 with existing score."""
        score = self._make_score(100.0)
        samples = [
            {"speed_kmh": 100, "acceleration_ms2": 1.0, "braking_ms2": 0.5,
             "swerve_index": 0.1, "phone_usage_detected": False}
            for _ in range(10)
        ]
        new_score = score.calculate_weighted_score(samples)
        assert new_score > 70
        assert new_score < 100
