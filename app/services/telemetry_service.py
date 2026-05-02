"""Civic-Link DPI - Telemetry Processing Service

Processes 50Hz IMU readings for lane-cutting detection (gyro_z > 1.5 rad/s).
Implements 60,000ms debounce and scoring formula per manifesto.
"""

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, List, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import CivicLinkException
from app.models.civic_score import CivicScore
from app.models.user import User

settings = get_settings()


@dataclass
class IMUReading:
    """Single IMU reading from mobile device."""

    timestamp_ms: int  # Unix timestamp in milliseconds
    gyro_x: float  # rad/s
    gyro_y: float  # rad/s
    gyro_z: float  # rad/s (lane-cutting detection axis)
    accel_x: float  # m/s²
    accel_y: float  # m/s²
    accel_z: float  # m/s²


@dataclass
class SwerveEvent:
    """Detected swerve (lane-cutting) event."""

    timestamp_ms: int
    gyro_z_value: float
    severity: str  # 'minor', 'moderate', 'severe' based on gyro_z magnitude


@dataclass
class TelemetryBatchResult:
    """Result of processing a telemetry batch."""

    user_id: str
    swerve_events: List[SwerveEvent] = field(default_factory=list)
    new_score: float = 0.0
    old_score: float = 0.0
    processed_readings: int = 0
    errors: List[str] = field(default_factory=list)


class TelemetryService:
    """Service for processing telemetry data from mobile devices.

    Processes 50Hz IMU readings (gyroscope + accelerometer) to detect:
    - Lane-cutting events (gyro_z > 1.5 rad/s)
    - Hard braking (accelerometer pattern)
    - Rapid acceleration (accelerometer pattern)

    Implements 60,000ms (1 minute) debounce per manifesto.
    """

    # Telemetry thresholds
    SWERVE_THRESHOLD_RAD_S = 1.5  # abs(gyro_z) trigger
    SWERVE_COOLDOWN_MS = 60000  # 60 second debounce
    SEVERITY_MINOR = 1.5
    SEVERITY_MODERATE = 3.0
    SEVERITY_SEVERE = 5.0

    # Accelerometer thresholds (for future implementation)
    HARD_BRAKE_THRESHOLD = -4.0  # m/s²
    RAPID_ACCEL_THRESHOLD = 3.5  # m/s²

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        # In-memory cooldown tracking (user_id -> last_swerve_ms)
        # In production, this should be in Redis for distributed systems
        self._swerve_cooldowns: Dict[str, int] = {}

    def _is_swerve(self, reading: IMUReading) -> bool:
        """Check if reading indicates a lane-cutting event.

        Args:
            reading: IMU reading to check

        Returns:
            True if abs(gyro_z) > 1.5 rad/s
        """
        return abs(reading.gyro_z) > self.SWERVE_THRESHOLD_RAD_S

    def _get_swerve_severity(self, gyro_z: float) -> str:
        """Determine severity of swerve based on gyro_z magnitude.

        Args:
            gyro_z: The gyro_z reading value

        Returns:
            Severity string: 'minor', 'moderate', or 'severe'
        """
        abs_gyro = abs(gyro_z)
        if abs_gyro >= self.SEVERITY_SEVERE:
            return "severe"
        elif abs_gyro >= self.SEVERITY_MODERATE:
            return "moderate"
        else:
            return "minor"

    def _check_cooldown(self, user_id: str, timestamp_ms: int) -> bool:
        """Check if user is within cooldown period.

        Args:
            user_id: The user ID to check
            timestamp_ms: Current timestamp in milliseconds

        Returns:
            True if cooldown has expired (can process new swerve)
        """
        last_swerve = self._swerve_cooldowns.get(user_id, 0)
        elapsed_ms = timestamp_ms - last_swerve
        return elapsed_ms >= self.SWERVE_COOLDOWN_MS

    def _update_cooldown(self, user_id: str, timestamp_ms: int) -> None:
        """Update the cooldown timestamp for a user.

        Args:
            user_id: The user ID to update
            timestamp_ms: Timestamp when swerve occurred
        """
        self._swerve_cooldowns[user_id] = timestamp_ms

    def _detect_swerves(self, readings: List[IMUReading], user_id: str) -> List[SwerveEvent]:
        """Detect swerve events in IMU readings with cooldown.

        Args:
            readings: List of IMU readings
            user_id: User ID for cooldown tracking

        Returns:
            List of detected SwerveEvent objects
        """
        swerve_events: List[SwerveEvent] = []

        for reading in readings:
            if self._is_swerve(reading):
                # Check cooldown before counting
                if self._check_cooldown(user_id, reading.timestamp_ms):
                    severity = self._get_swerve_severity(reading.gyro_z)
                    event = SwerveEvent(
                        timestamp_ms=reading.timestamp_ms,
                        gyro_z_value=reading.gyro_z,
                        severity=severity,
                    )
                    swerve_events.append(event)
                    self._update_cooldown(user_id, reading.timestamp_ms)

        return swerve_events

    async def get_or_create_civic_score(self, user_id: str) -> CivicScore:
        """Get or create CivicScore record for user.

        Args:
            user_id: The user ID

        Returns:
            The CivicScore record
        """
        result = await self.session.execute(
            select(CivicScore).where(CivicScore.user_id == user_id)
        )
        score = result.scalar_one_or_none()

        if score is None:
            score = CivicScore(
                user_id=user_id,
                score=100.0,
                total_trips=0,
                total_distance_km=0.0,
                swerve_count=0,
                speeding_count=0,
            )
            self.session.add(score)
            await self.session.flush()

        return score

    def _calculate_new_score(
        self,
        old_score: float,
        swerve_count: int,
        new_swerves: int,
        speeding_count: int = 0,
    ) -> float:
        """Calculate new civic score using manifesto formula.

        Formula: S_new = (S_old × 0.85) + (max(0, 100 - (n_swerves × 5)) × 0.15)

        Args:
            old_score: Previous score
            swerve_count: Current total swerve count
            new_swerves: New swerves detected in this batch
            speeding_count: Number of speeding events (penalty: 10 each)

        Returns:
            New score (0-100)
        """
        total_swerves = swerve_count + new_swerves
        swerve_penalty = total_swerves * 5.0
        speeding_penalty = speeding_count * 10.0

        # Calculate base score from penalties
        base_score = max(0.0, 100.0 - swerve_penalty - speeding_penalty)

        # Apply weighted rolling average
        new_score = (old_score * 0.85) + (base_score * 0.15)

        # Clamp to valid range
        return max(0.0, min(100.0, new_score))

    async def process_telemetry_batch(
        self,
        user_id: str,
        readings: List[IMUReading],
        match_id: Optional[str] = None,
    ) -> TelemetryBatchResult:
        """Process a batch of telemetry readings.

        This method is designed to run in a BackgroundTask for
        zero-lag response to mobile clients.

        Args:
            user_id: The driver/user ID
            readings: List of 50Hz IMU readings
            match_id: Optional match ID for trip association

        Returns:
            TelemetryBatchResult with processing results
        """
        result = TelemetryBatchResult(user_id=user_id)
        result.processed_readings = len(readings)

        try:
            # Validate user exists
            user_result = await self.session.execute(
                select(User).where(User.id == user_id)
            )
            user = user_result.scalar_one_or_none()
            if user is None:
                result.errors.append(f"User {user_id} not found")
                return result

            # Detect swerve events
            swerve_events = self._detect_swerves(readings, user_id)
            result.swerve_events = swerve_events

            # Get or create civic score
            civic_score = await self.get_or_create_civic_score(user_id)
            result.old_score = civic_score.score

            # Update swerve count
            if swerve_events:
                civic_score.swerve_count += len(swerve_events)
                civic_score.last_swerve_at = datetime.now(timezone.utc)
                civic_score.swerve_penalty = civic_score.swerve_count * 5.0

            # Calculate new score
            new_score = self._calculate_new_score(
                old_score=civic_score.score,
                swerve_count=civic_score.swerve_count,
                new_swerves=len(swerve_events),
                speeding_count=civic_score.speeding_count,
            )
            civic_score.score = new_score
            civic_score.last_calculated_at = datetime.now(timezone.utc)

            result.new_score = new_score

            # TODO: Generate audit log for swerve events
            # TODO: Update Redis cache for active commute if applicable

            await self.session.commit()

        except Exception as e:
            await self.session.rollback()
            result.errors.append(str(e))
            raise CivicLinkException(f"Telemetry processing failed: {e}") from e

        return result

    async def process_single_trip(
        self,
        user_id: str,
        trip_distance_km: float,
        trip_duration_hours: float,
    ) -> CivicScore:
        """Record trip completion and update score.

        Args:
            user_id: The driver/user ID
            trip_distance_km: Distance traveled in kilometers
            trip_duration_hours: Duration of trip in hours

        Returns:
            Updated CivicScore
        """
        civic_score = await self.get_or_create_civic_score(user_id)
        civic_score.record_trip(trip_distance_km, trip_duration_hours)
        await self.session.commit()
        return civic_score
