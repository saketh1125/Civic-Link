"""initial_schema

Revision ID: e14fe2c5ae57
Revises:
Create Date: 2026-05-16

Initial schema migration for Civic-Link DPI.
Covers all 8 ORM models: User, Commute, CommuteOffer, CommuteMatch,
CivicScore, CivicScoreHistory, CommuteAuditLog, SafetyAlertLog.
"""

from typing import Sequence, Union

import geoalchemy2
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "e14fe2c5ae57"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # NOTE: Enum types are auto-created by SQLAlchemy during the first
    # create_table() that references them. No explicit creation needed.

    # ------------------------------------------------------------------
    # TABLE: users
    # ------------------------------------------------------------------
    op.create_table(
        "users",
        sa.Column("id", sa.String(36), primary_key=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, default=True),
        sa.Column("email_hash", sa.String(64), nullable=False, comment="SHA-256 hash of corporate email for deduplication"),
        sa.Column("email_domain", sa.String(255), nullable=False, comment="Email domain for corporate filtering"),
        sa.Column("phone_number", sa.String(20), nullable=False),
        sa.Column("full_name", sa.String(255), nullable=False),
        sa.Column("gender", sa.Enum("male", "female", "undisclosed", name="gender_enum"), nullable=False, comment="Gender for women-only commute safety matching"),
        sa.Column("employee_id", sa.String(100), nullable=True, comment="Optional corporate employee ID"),
        sa.Column("company_name", sa.String(255), nullable=False),
        sa.Column("verification_status", sa.Enum("pending", "verified", "rejected", name="verification_status_enum"), nullable=False, default="pending"),
        sa.Column("last_login", sa.DateTime(timezone=False), nullable=True),
        sa.Column("role", sa.Enum("commuter", "admin", "moderator", name="user_role_enum"), nullable=False, default="commuter"),
        sa.Column("password_hash", sa.String(255), nullable=True, comment="Bcrypt hashed password"),
        sa.UniqueConstraint("email_hash"),
        sa.UniqueConstraint("phone_number"),
    )
    op.create_index("ix_users_id", "users", ["id"])
    op.create_index("ix_users_is_active", "users", ["is_active"])
    op.create_index("ix_users_email_hash", "users", ["email_hash"])
    op.create_index("ix_users_email_domain", "users", ["email_domain"])
    op.create_index("ix_users_phone_number", "users", ["phone_number"])
    op.create_index("ix_users_gender", "users", ["gender"])
    op.create_index("ix_users_company_name", "users", ["company_name"])
    op.create_index("ix_users_company_gender", "users", ["company_name", "gender"])
    op.create_index("ix_users_verified_domain", "users", ["verification_status", "email_domain"])

    # ------------------------------------------------------------------
    # TABLE: civic_scores
    # ------------------------------------------------------------------
    op.create_table(
        "civic_scores",
        sa.Column("id", sa.String(36), primary_key=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, default=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("score", sa.Float(), nullable=False, default=100.0, comment="Current civic score 0-100, calculated from telemetry"),
        sa.Column("total_trips", sa.Integer(), nullable=False, default=0),
        sa.Column("total_distance_km", sa.Float(), nullable=False, default=0.0),
        sa.Column("total_driving_hours", sa.Float(), nullable=False, default=0.0),
        sa.Column("swerve_count", sa.Integer(), nullable=False, default=0, comment="Lane-cutting events (gyro_z > 1.5 rad/s)"),
        sa.Column("speeding_count", sa.Integer(), nullable=False, default=0),
        sa.Column("hard_braking_count", sa.Integer(), nullable=False, default=0),
        sa.Column("rapid_acceleration_count", sa.Integer(), nullable=False, default=0),
        sa.Column("last_swerve_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("last_speeding_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("last_hard_brake_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("swerve_penalty", sa.Float(), nullable=False, default=0.0, comment="Penalty points from swerve events"),
        sa.Column("speeding_penalty", sa.Float(), nullable=False, default=0.0, comment="Penalty points from speeding events"),
        sa.Column("last_calculated_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("calculation_version", sa.String(10), nullable=False, default="1.0", comment="Version of scoring formula used"),
        sa.UniqueConstraint("user_id"),
    )
    op.create_index("ix_civic_scores_id", "civic_scores", ["id"])
    op.create_index("ix_civic_scores_is_active", "civic_scores", ["is_active"])
    op.create_index("ix_civic_scores_user_id", "civic_scores", ["user_id"])
    op.create_index("ix_civic_scores_score", "civic_scores", ["score"])
    op.create_index("ix_civic_scores_swerves", "civic_scores", ["swerve_count", "score"])

    # ------------------------------------------------------------------
    # TABLE: commute_audit_logs
    # ------------------------------------------------------------------
    op.create_table(
        "commute_audit_logs",
        sa.Column("id", sa.String(36), primary_key=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, default=True),
        sa.Column("match_id", sa.String(36), nullable=True),
        sa.Column("driver_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("passenger_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("event_type", sa.Enum(
            "match_created", "match_confirmed", "match_started", "match_completed",
            "match_cancelled", "safety_alert", "gender_mismatch_blocked",
            "data_anonymized", "telemetry_swerve", "telemetry_speeding", "user_reported",
            name="audit_event_type_enum",
            create_type=False,
        ), nullable=False),
        sa.Column("severity", sa.Enum("info", "warning", "error", "critical", name="audit_event_severity_enum"), nullable=False, default="info"),
        sa.Column("encrypted_payload", sa.Text(), nullable=False, comment="AES-256-GCM encrypted JSON event data (Base64 encoded)"),
        sa.Column("encryption_iv", sa.String(32), nullable=False, comment="Initialization vector for AES decryption (hex encoded)"),
        sa.Column("encryption_version", sa.String(10), nullable=False, default="v1", comment="Encryption scheme version for future migrations"),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ip_address", sa.String(45), nullable=True),
        sa.Column("user_agent", sa.String(500), nullable=True),
        sa.Column("driver_gender_at_time", sa.String(20), nullable=True, comment="Driver gender at time of event (for safety audit)"),
        sa.Column("passenger_gender_at_time", sa.String(20), nullable=True, comment="Passenger gender at time of event (for safety audit)"),
        sa.Column("commute_women_only_at_time", sa.Boolean(), nullable=False, default=False),
        sa.Column("offer_women_only_at_time", sa.Boolean(), nullable=False, default=False),
        sa.Column("retention_until", sa.DateTime(timezone=True), nullable=False, comment="GDPR/RTI: When this log can be purged"),
        sa.Column("purged_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_commute_audit_logs_id", "commute_audit_logs", ["id"])
    op.create_index("ix_commute_audit_logs_is_active", "commute_audit_logs", ["is_active"])
    op.create_index("ix_commute_audit_logs_match_id", "commute_audit_logs", ["match_id"])
    op.create_index("ix_commute_audit_logs_driver_id", "commute_audit_logs", ["driver_id"])
    op.create_index("ix_commute_audit_logs_passenger_id", "commute_audit_logs", ["passenger_id"])
    op.create_index("ix_commute_audit_logs_event_type", "commute_audit_logs", ["event_type"])
    op.create_index("ix_commute_audit_logs_severity", "commute_audit_logs", ["severity"])
    op.create_index("ix_commute_audit_logs_occurred_at", "commute_audit_logs", ["occurred_at"])
    op.create_index("ix_audit_logs_event_occurred", "commute_audit_logs", ["event_type", "occurred_at"])
    op.create_index("ix_audit_logs_severity_occurred", "commute_audit_logs", ["severity", "occurred_at"])
    op.create_index("ix_audit_logs_retention", "commute_audit_logs", ["retention_until", "purged_at"])
    op.create_index("ix_audit_logs_match_event", "commute_audit_logs", ["match_id", "event_type"])

    # ------------------------------------------------------------------
    # TABLE: commutes
    # ------------------------------------------------------------------
    op.create_table(
        "commutes",
        sa.Column("id", sa.String(36), primary_key=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, default=True),
        sa.Column("driver_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("origin", geoalchemy2.types.Geography(geometry_type="POINT", srid=4326, from_text="ST_GeogPoint", name="geography"), nullable=False, comment="Driver's pickup location as GPS coordinates (WGS 84)"),
        sa.Column("destination", geoalchemy2.types.Geography(geometry_type="POINT", srid=4326, from_text="ST_GeogPoint", name="geography"), nullable=False, comment="Driver's dropoff location as GPS coordinates (WGS 84)"),
        sa.Column("origin_address", sa.String(500), nullable=False, comment="Human-readable origin address"),
        sa.Column("destination_address", sa.String(500), nullable=False, comment="Human-readable destination address"),
        sa.Column("departure_date", sa.Date(), nullable=False),
        sa.Column("departure_time", sa.Time(), nullable=False),
        sa.Column("arrival_time", sa.Time(), nullable=True),
        sa.Column("available_seats", sa.Integer(), nullable=False, default=1),
        sa.Column("total_seats", sa.Integer(), nullable=False, default=4),
        sa.Column("is_women_only", sa.Boolean(), nullable=False, default=False, comment="CRITICAL SAFETY: When True, only female passengers allowed"),
        sa.Column("commute_type", sa.Enum("one_time", "recurring", name="commute_type_enum"), nullable=False, default="one_time"),
        sa.Column("recurring_days", sa.String(100), nullable=True, comment="Comma-separated days for recurring commutes (e.g., 'monday,wednesday')"),
        sa.Column("status", sa.Enum("pending", "active", "in_progress", "completed", "cancelled", "expired", name="commute_status_enum"), nullable=False, default="pending"),
        sa.Column("expires_at", sa.DateTime(timezone=False), nullable=False, comment="Redis cache expiration timestamp"),
        sa.Column("origin_anonymized_at", sa.DateTime(timezone=False), nullable=True, comment="GDPR: When origin coordinates were anonymized"),
        sa.Column("destination_anonymized_at", sa.DateTime(timezone=False), nullable=True, comment="GDPR: When destination coordinates were anonymized"),
        sa.CheckConstraint("available_seats <= total_seats", name="chk_available_seats"),
        sa.CheckConstraint("available_seats >= 0", name="chk_available_seats_non_negative"),
    )
    op.create_index("ix_commutes_id", "commutes", ["id"])
    op.create_index("ix_commutes_is_active", "commutes", ["is_active"])
    op.create_index("ix_commutes_driver_id", "commutes", ["driver_id"])
    op.create_index("ix_commutes_departure_date", "commutes", ["departure_date"])
    op.create_index("ix_commutes_is_women_only", "commutes", ["is_women_only"])
    op.create_index("ix_commutes_status", "commutes", ["status"])
    op.create_index("ix_commutes_driver_status", "commutes", ["driver_id", "status"])
    op.create_index("ix_commutes_departure", "commutes", ["departure_date", "departure_time"])
    op.create_index("ix_commutes_women_only", "commutes", ["is_women_only", "status"])
    op.create_index("ix_commutes_origin_gist", "commutes", ["origin"], postgresql_using="GIST")
    op.create_index("ix_commutes_destination_gist", "commutes", ["destination"], postgresql_using="GIST")

    # ------------------------------------------------------------------
    # TABLE: civic_score_history
    # ------------------------------------------------------------------
    op.create_table(
        "civic_score_history",
        sa.Column("id", sa.String(36), primary_key=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, default=True),
        sa.Column("civic_score_id", sa.String(36), sa.ForeignKey("civic_scores.id", ondelete="CASCADE"), nullable=False),
        sa.Column("old_score", sa.Float(), nullable=False),
        sa.Column("new_score", sa.Float(), nullable=False),
        sa.Column("trigger_event", sa.String(50), nullable=False, comment="Event type that triggered recalculation"),
        sa.Column("match_id", sa.String(36), nullable=True, comment="Associated match if triggered by trip completion"),
        sa.Column("swerve_count_at_time", sa.Integer(), nullable=False),
        sa.Column("speeding_count_at_time", sa.Integer(), nullable=False),
        sa.Column("calculation_version", sa.String(10), nullable=False),
    )
    op.create_index("ix_civic_score_history_id", "civic_score_history", ["id"])
    op.create_index("ix_civic_score_history_is_active", "civic_score_history", ["is_active"])
    op.create_index("ix_civic_score_history_civic_score_id", "civic_score_history", ["civic_score_id"])
    op.create_index("ix_civic_history_score_change", "civic_score_history", ["civic_score_id", "created_at"])

    # ------------------------------------------------------------------
    # TABLE: commute_matches
    # ------------------------------------------------------------------
    op.create_table(
        "commute_matches",
        sa.Column("id", sa.String(36), primary_key=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, default=True),
        sa.Column("commute_id", sa.String(36), sa.ForeignKey("commutes.id", ondelete="CASCADE"), nullable=False),
        sa.Column("driver_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("passenger_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("status", sa.Enum("pending", "confirmed", "in_progress", "completed", "cancelled", "no_show", name="match_status_enum"), nullable=False, default="pending"),
        sa.Column("confirmed_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("pickup_radius_meters", sa.Integer(), nullable=False, comment="Distance from passenger to driver pickup point"),
        sa.Column("dropoff_radius_meters", sa.Integer(), nullable=True, comment="Distance from driver dropoff to passenger destination"),
        sa.Column("fare_amount", sa.Numeric(10, 2), nullable=True, comment="Calculated ride fare in local currency"),
        sa.Column("payment_status", sa.Enum("pending", "completed", "failed", "refunded", name="payment_status_enum"), nullable=False, default="pending"),
        sa.Column("driver_rating", sa.Integer(), nullable=True, comment="Passenger's rating of driver (1-5)"),
        sa.Column("driver_review", sa.String(1000), nullable=True),
        sa.Column("passenger_rating", sa.Integer(), nullable=True, comment="Driver's rating of passenger (1-5)"),
        sa.Column("passenger_review", sa.String(1000), nullable=True),
        sa.Column("commute_was_women_only", sa.Boolean(), nullable=False, default=False, comment="Snapshot of Commute.is_women_only at match time"),
        sa.Column("offer_was_women_only", sa.Boolean(), nullable=False, default=False, comment="Snapshot of CommuteOffer.is_women_only at match time"),
        sa.Column("audit_log_id", sa.String(36), nullable=True, comment="Reference to encrypted CommuteAuditLog entry"),
        sa.Column("anonymized_at", sa.DateTime(timezone=False), nullable=True, comment="GDPR: When PII in this match was anonymized"),
    )
    op.create_index("ix_commute_matches_id", "commute_matches", ["id"])
    op.create_index("ix_commute_matches_is_active", "commute_matches", ["is_active"])
    op.create_index("ix_commute_matches_commute_id", "commute_matches", ["commute_id"])
    op.create_index("ix_commute_matches_driver_id", "commute_matches", ["driver_id"])
    op.create_index("ix_commute_matches_passenger_id", "commute_matches", ["passenger_id"])
    op.create_index("ix_commute_matches_status", "commute_matches", ["status"])
    op.create_index("ix_matches_commute_status", "commute_matches", ["commute_id", "status"])
    op.create_index("ix_matches_driver_status", "commute_matches", ["driver_id", "status"])
    op.create_index("ix_matches_passenger_status", "commute_matches", ["passenger_id", "status"])
    op.create_index("ix_matches_completed", "commute_matches", ["completed_at", "status"])

    # ------------------------------------------------------------------
    # TABLE: commute_offers
    # ------------------------------------------------------------------
    op.create_table(
        "commute_offers",
        sa.Column("id", sa.String(36), primary_key=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, default=True),
        sa.Column("passenger_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("commute_id", sa.String(36), sa.ForeignKey("commutes.id", ondelete="SET NULL"), nullable=True),
        sa.Column("origin", geoalchemy2.types.Geography(geometry_type="POINT", srid=4326, from_text="ST_GeogPoint", name="geography"), nullable=False, comment="Passenger's requested pickup location (WGS 84)"),
        sa.Column("destination", geoalchemy2.types.Geography(geometry_type="POINT", srid=4326, from_text="ST_GeogPoint", name="geography"), nullable=False, comment="Passenger's requested dropoff location (WGS 84)"),
        sa.Column("origin_address", sa.String(500), nullable=False),
        sa.Column("destination_address", sa.String(500), nullable=False),
        sa.Column("preferred_departure_date", sa.Date(), nullable=False),
        sa.Column("preferred_departure_time", sa.Time(), nullable=False),
        sa.Column("preferred_arrival_time", sa.Time(), nullable=True),
        sa.Column("time_flexibility_minutes", sa.Integer(), nullable=False, default=15, comment="How many minutes passenger can adjust departure time"),
        sa.Column("is_women_only", sa.Boolean(), nullable=False, default=False, comment="CRITICAL SAFETY: When True, only female drivers allowed"),
        sa.Column("max_walking_distance", sa.Integer(), nullable=False, default=500, comment="Maximum walking distance to pickup point in meters"),
        sa.Column("max_wait_time_minutes", sa.Integer(), nullable=False, default=10),
        sa.Column("status", sa.String(50), nullable=False, default="pending"),
        sa.Column("origin_anonymized_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("destination_anonymized_at", sa.DateTime(timezone=False), nullable=True),
    )
    op.create_index("ix_commute_offers_id", "commute_offers", ["id"])
    op.create_index("ix_commute_offers_is_active", "commute_offers", ["is_active"])
    op.create_index("ix_commute_offers_passenger_id", "commute_offers", ["passenger_id"])
    op.create_index("ix_commute_offers_commute_id", "commute_offers", ["commute_id"])
    op.create_index("ix_commute_offers_preferred_departure_date", "commute_offers", ["preferred_departure_date"])
    op.create_index("ix_commute_offers_is_women_only", "commute_offers", ["is_women_only"])
    op.create_index("ix_commute_offers_status", "commute_offers", ["status"])
    op.create_index("ix_commute_offers_passenger_status", "commute_offers", ["passenger_id", "status"])
    op.create_index("ix_commute_offers_departure", "commute_offers", ["preferred_departure_date", "preferred_departure_time"])
    op.create_index("ix_commute_offers_women_only", "commute_offers", ["is_women_only", "status"])
    op.create_index("ix_commute_offers_origin_gist", "commute_offers", ["origin"], postgresql_using="GIST")
    op.create_index("ix_commute_offers_destination_gist", "commute_offers", ["destination"], postgresql_using="GIST")

    # ------------------------------------------------------------------
    # TABLE: safety_alert_logs
    # ------------------------------------------------------------------
    op.create_table(
        "safety_alert_logs",
        sa.Column("id", sa.String(36), primary_key=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, default=True),
        sa.Column("audit_log_id", sa.String(36), sa.ForeignKey("commute_audit_logs.id", ondelete="CASCADE"), nullable=False),
        sa.Column("match_id", sa.String(36), nullable=True),
        sa.Column("reporter_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("reported_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("alert_type", sa.String(50), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("severity", sa.String(20), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, default="open"),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolved_by", sa.String(36), nullable=True),
        sa.Column("resolution_notes", sa.Text(), nullable=True),
        sa.UniqueConstraint("audit_log_id"),
    )
    op.create_index("ix_safety_alert_logs_id", "safety_alert_logs", ["id"])
    op.create_index("ix_safety_alert_logs_is_active", "safety_alert_logs", ["is_active"])
    op.create_index("ix_safety_alert_logs_match_id", "safety_alert_logs", ["match_id"])
    op.create_index("ix_safety_alert_logs_alert_type", "safety_alert_logs", ["alert_type"])
    op.create_index("ix_safety_alert_logs_severity", "safety_alert_logs", ["severity"])
    op.create_index("ix_safety_alerts_status_type", "safety_alert_logs", ["status", "alert_type"])
    op.create_index("ix_safety_alerts_reported_user", "safety_alert_logs", ["reported_user_id", "status"])


def downgrade() -> None:
    # Drop tables in reverse dependency order
    op.drop_table("safety_alert_logs")
    op.drop_table("commute_offers")
    op.drop_table("commute_matches")
    op.drop_table("civic_score_history")
    op.drop_table("commutes")
    op.drop_table("commute_audit_logs")
    op.drop_table("civic_scores")
    op.drop_table("users")

    # Drop enum types
    sa.Enum(name="audit_event_severity_enum").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="audit_event_type_enum").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="payment_status_enum").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="match_status_enum").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="commute_status_enum").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="commute_type_enum").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="verification_status_enum").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="gender_enum").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="user_role_enum").drop(op.get_bind(), checkfirst=True)
