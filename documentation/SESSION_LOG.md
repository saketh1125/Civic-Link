# Session Documentation — Civic Link Compliance + Test Fix Sprints

> **Date:** 2026-05-16
> **Branch:** ustable
> **Stack:** FastAPI + PostgreSQL + SQLAlchemy 2.0 + pytest + structlog

---

## Sprint 1: Compliance Sprint (Parallel to Security Hardening)

### Objective
Wire encrypted audit logging across all service layers, implement GDPR anonymization, and establish structured logging — without touching files owned by the parallel Security Sprint.

### Step 0: Codebase Reconnaissance

Read and internalized 14 files before making any changes:

| File | Key Finding |
|------|-------------|
| `README.md` | Empty |
| `app/core/config.py` | Has `audit_log_retention_days=90`, `audit_log_encryption_key` (optional), `environment` flag |
| `app/models/audit.py` | `CommuteAuditLog` + `SafetyAlertLog` models; AES-256-GCM encrypted payloads; `AuditEventType` enum had only 11 match-centric values |
| `app/services/audit_service.py` | `log_match_event()`, `log_safety_alert()`, `resolve_safety_alert()` exist but are **never called** anywhere; IV is `os.urandom(12)` — correctly random |
| `app/services/match_service.py` | Hard-reject SQL safety at lines 68-99; contains `TODO: Generate encrypted audit log entry` at line 273 |
| `app/services/commute_service.py` | 4 lifecycle methods with no audit calls: create/cancel commute, create/cancel offer |
| `app/services/civic_score_service.py` | 3 score-change methods with no audit calls: get_or_create, ingest_telemetry, record_trip |
| `app/services/user_service.py` | 2 admin methods with no audit calls: verify_user, promote_to_admin |
| `app/schemas/match.py` | `ConfirmMatchRequest` was a bare `pass` class |
| `migrations/env.py` | Empty stub |
| `scripts/anonymize_data.py` | Empty stub |
| `tests/test_safety_logic.py` | 27 tests (later found to be 28); 5 pre-existing failures in `TestCivicScoreSafety` |

### Task 1: Fix ConfirmMatchRequest Empty Schema

**File:** `app/schemas/match.py`

Replaced bare `pass` with proper Pydantic fields:

```python
class ConfirmMatchRequest(BaseModel):
    match_id: str = Field(description="The match UUID to confirm")
    confirmed: bool = Field(description="Whether to confirm or reject the match")
    message: Optional[str] = Field(None, max_length=500)
```

Verified: `ConfirmMatchRequest` is only defined in `schemas/match.py` and not imported anywhere else yet (the endpoint `confirm_match` in `matches.py` doesn't use it — it takes `match_id` from the path).

### Task 2: Wire Audit Logging for Commute and User Admin Events

#### 2a: Extended AuditEventType Enum

**File:** `app/models/audit.py`

Added 8 new event types to `AuditEventType`:
- `COMMUTE_CREATED`, `COMMUTE_CANCELLED`
- `OFFER_CREATED`, `OFFER_CANCELLED`
- `ADMIN_PROMOTED`, `USER_VERIFIED`
- `SCORE_UPDATED`, `TRIP_COMPLETED`, `SCORE_INITIALIZED`

#### 2b: Made AuditService.log_match_event Params Optional

**File:** `app/services/audit_service.py`

Changed `match_id`, `driver_id`, `passenger_id`, `event_type` from required to `Optional` with defaults. This allows non-match events (commute creation, user verification) to log without a match context. The `CommuteAuditLog` model already has these columns as `nullable=True`.

#### 2c: Audit Calls in commute_service.py

**File:** `app/services/commute_service.py`

Added 4 audit call sites, each wrapped in `try/except`:

| Method | Event Type | Severity |
|--------|-----------|----------|
| `create_commute()` | `COMMUTE_CREATED` | INFO |
| `cancel_commute()` | `COMMUTE_CANCELLED` | WARNING |
| `create_commute_offer()` | `OFFER_CREATED` | INFO |
| `cancel_offer()` | `OFFER_CANCELLED` | WARNING |

Each call passes relevant context (driver_id/passenger_id, women_only flags).

#### 2d: Audit Calls in user_service.py

**File:** `app/services/user_service.py`

Added 2 audit call sites:

| Method | Event Type | Severity |
|--------|-----------|----------|
| `verify_user()` | `USER_VERIFIED` | INFO |
| `promote_to_admin()` | `ADMIN_PROMOTED` | WARNING |

### Task 3: Wire Audit Logging for Civic Score Changes

**File:** `app/services/civic_score_service.py`

Added 3 audit call sites:

| Method | Event Type | Condition |
|--------|-----------|-----------|
| `get_or_create_score()` | `SCORE_INITIALIZED` | Only when new score is created |
| `ingest_telemetry_samples()` | `SCORE_UPDATED` | After every score update |
| `record_trip_completion()` | `TRIP_COMPLETED` | After every trip recording |

All wrapped in `try/except` with error logging.

### Task 4: Implement anonymize_data.py for GDPR Compliance

**File:** `scripts/anonymize_data.py` (created from empty stub)

Implemented CLI tool with `argparse` supporting `--user-id`, `--reason`, `--dry-run`.

**Functions:**

| Function | Purpose |
|----------|---------|
| `anonymize_user()` | Sets `full_name` to "Anonymized User", overwrites `email_hash` with SHA-256 of random UUID, nulls `phone_number`/`employee_id`, sets `company_name` to "ANONYMIZED" |
| `anonymize_audit_logs()` | Deletes `CommuteAuditLog` entries older than `retention_days` for the user |
| `anonymize_commute_coordinates()` | Sets `origin_anonymized_at`/`destination_anonymized_at` timestamps on user's commutes and offers |
| `log_anonymization_action()` | Logs the anonymization itself as a `DATA_ANONYMIZED` audit entry before clearing data |

**Key design decisions:**
- Does NOT delete the user record — only anonymizes PII fields
- Phone number nulling includes a TODO comment flagging plaintext storage as a known gap
- Uses existing `AsyncSessionLocal` pattern — no new DB connection method
- Dry-run mode prints what would change without committing

### Task 5: Implement Structured Logging

**File:** `app/core/logging_config.py` (created from empty stub)

Configured structlog with:
- JSON renderer for production (`ENVIRONMENT=production`)
- Console renderer for development
- `request_id` (UUID) injected per request via middleware
- Log level configurable via `LOG_LEVEL` env var

**File:** `app/main.py`

- Added `RequestIDMiddleware` (Starlette `BaseHTTPMiddleware`) that generates a UUID per request and binds it to structlog context
- Calls `configure_logging()` at module load time
- Added startup/shutdown log messages

**print() Replacements:**

Replaced 10 `print()` calls in core app files with `structlog.get_logger().error()`:

| File | Count | Context |
|------|-------|---------|
| `app/services/commute_service.py` | 4 | Audit failure logging |
| `app/services/user_service.py` | 2 | Audit failure logging |
| `app/services/civic_score_service.py` | 3 | Audit failure logging |
| `app/api/v1/endpoints/telemetry.py` | 1 | Background telemetry processing failure |

**Not replaced:** 104+ `print()` calls in simulation/seed scripts (`telemetry_sim.py`, `telemetry_simulation.py`, `seed_kphb.py`, `privacy_worker.py`) — these are standalone CLI tools where `print()` is appropriate.

---

## Sprint 2: Test Failures Fix (Parallel to Infra Sprint)

### Objective
Fix 5 pre-existing test failures in `TestCivicScoreSafety` — all caused by SQLAlchemy column defaults not applying to non-DB-instantiated objects.

### Diagnosis

**Root cause:** Tests instantiate `CivicScore()` directly (e.g., `CivicScore(user_id="test-user")`) without a DB session. SQLAlchemy 2.0's `default=` in `mapped_column()` fires only at INSERT/flush time, NOT at Python `__init__`. So fields are `None` on bare objects.

**5 exact failures:**

| Test | Error | Field |
|------|-------|-------|
| `test_score_starts_at_100` | `assert None == 100.0` | `score` |
| `test_score_clamps_to_zero_minimum` | `TypeError: NoneType + int` | `swerve_count` |
| `test_score_clamps_to_100_maximum` | `TypeError: NoneType + int` | `swerve_count` |
| `test_swerve_penalty_applied` | `TypeError: NoneType += int` | `swerve_count` |
| `test_trip_recording` | `TypeError: NoneType += int` | `total_trips` |

**12 fields affected** (all had `default=` in `mapped_column` but no Python `__init__`):
`score`, `total_trips`, `total_distance_km`, `total_driving_hours`, `swerve_count`, `speeding_count`, `hard_braking_count`, `rapid_acceleration_count`, `swerve_penalty`, `speeding_penalty`, `last_calculated_at`, `calculation_version`.

### Fix

**File:** `app/models/civic_score.py`

Added `__init__` to `CivicScore` with `kwargs.setdefault()` for all 12 fields, matching the SQLAlchemy `default=` values exactly. Calls `super().__init__(**kwargs)` after setting defaults.

**No test changes needed.** All 28 tests pass after the model fix alone.

---

## Files Modified Summary

| File | Sprint | Change |
|------|--------|--------|
| `app/schemas/match.py` | 1 | Fixed `ConfirmMatchRequest` — added `match_id`, `confirmed`, `message` fields |
| `app/models/audit.py` | 1 | Added 8 new `AuditEventType` values |
| `app/services/audit_service.py` | 1 | Made `log_match_event` params optional for non-match events |
| `app/services/commute_service.py` | 1 | Added 4 audit call sites + structlog imports |
| `app/services/user_service.py` | 1 | Added 2 audit call sites + structlog imports |
| `app/services/civic_score_service.py` | 1+2 | Added 3 audit call sites + structlog imports + model `__init__` fix |
| `app/api/v1/endpoints/telemetry.py` | 1 | Replaced print() with structlog for background errors |
| `app/core/logging_config.py` | 1 | Created: structlog config (JSON prod / console dev) |
| `app/main.py` | 1 | Added request_id middleware + logging init |
| `scripts/anonymize_data.py` | 1 | Created: GDPR anonymization CLI with dry-run |
| `app/models/civic_score.py` | 2 | Added `__init__` with Python-level defaults for 12 fields |

## Files NOT Touched (per constraints)

- `.env`, `app/core/config.py` (Security Sprint)
- `app/api/deps.py` (Security Sprint)
- `app/api/v1/endpoints/auth.py` (Security Sprint)
- `app/services/match_service.py` (Security Sprint)
- `migrations/env.py` (Infra Sprint)
- `app/core/redis.py` (Infra Sprint)
- `app/middleware/` (Infra Sprint)
- `nginx.conf`, `docker-compose.prod.yml`, `Dockerfile` (Infra Sprint)
- Telemetry pipeline logic
- Scoring formula / 70/30 blend logic
- Existing test assertions

## Verification Results

| Check | Result |
|-------|--------|
| `pytest tests/test_safety_logic.py -v` | **28 passed, 0 failed** |
| `grep -rn 'print('` in core app files | **0 matches** (all replaced) |
| AuditService call sites wrapped in try/except | **All 9 confirmed** |
| AuditService IV randomness | **Confirmed random** (`os.urandom(12)`) |
| `anonymize_data.py --help` | **CLI works correctly** |
| Pre-existing passing tests broken | **None** |
