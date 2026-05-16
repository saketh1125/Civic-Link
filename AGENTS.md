# AGENTS.md — Civic-Link DPI

## Monorepo Structure

| Directory | What | Language |
|-----------|------|----------|
| `app/` | FastAPI backend (API, models, services, schemas) | Python 3.12+ |
| `civic_link/` | Flutter mobile app | Dart 3.11+ |
| `tests/` | Backend pytest tests | Python |
| `documentation/` | Architecture, API, schema docs | Markdown |

## Backend (`app/`)

### Entry Point
- `app/main.py` — FastAPI app, mounts `app.api.v1.api:api_router` at `/api/v1`
- Run: `uvicorn app.main:app --reload --port 8000`

### Docker
- `docker compose up` — starts Postgres (PostGIS 16-3.4), Redis 7, API on port 8000
- `docker compose --profile migrations up` — runs Alembic migrations
- `.env` controls credentials; defaults in `docker-compose.yml`

### Key Directories
- `app/api/v1/endpoints/` — `auth.py`, `telemetry.py`, `commutes.py`, `matches.py`, `civic_score.py`
- `app/services/` — `match_service.py` (hard-reject SQL safety), `telemetry_service.py`, `commute_service.py`, `user_service.py`, `civic_score_service.py`, `audit_service.py`
- `app/models/` — SQLAlchemy 2.0 ORM: `user.py`, `commute.py`, `match.py`, `civic_score.py`, `audit.py`
- `app/schemas/` — Pydantic request/response models: `user.py`, `commute.py`, `match.py`
- `app/core/` — `config.py`, `database.py`, `security.py`, `exceptions.py`

### Empty Stubs (not yet implemented)
- `app/core/redis.py` — empty
- `app/core/logging_config.py` — empty
- `app/migrations/` — directory does not exist; `alembic.ini` exists at root but no migration versions
- `tests/factories.py`, `tests/test_commutes.py`, `tests/test_matches.py`, `tests/test_users.py` — all empty

### Safety Logic (CRITICAL)
- `app/services/match_service.py:68-99` — SQL-level hard-reject gender filtering
- Women-only commutes reject non-female passengers; women-only offers reject non-female drivers
- Double validation: SQL clause + Python-level check in `create_match()`
- Never modify safety logic without understanding both layers

### Telemetry
- `app/services/telemetry_service.py` — processes IMU batches, calculates civic scores
- `app/telemetry_sim.py`, `app/telemetry_simulation.py` — simulation scripts for testing
- Civic score formula: `S_new = (S_old × 0.85) + (max(0, 100 - (n_swerves × 5) - P_speeding) × 0.15)`
- Swerve threshold: `abs(gyro_z) > 1.5 rad/s` with 60s cooldown

### Auth
- Zero-Liability: email is SHA-256 hashed client-side; only hash + domain sent to server
- Domain whitelist enforced in `app/schemas/user.py` and `app/core/config.py`
- JWT tokens via `app/core/security.py`; defaults in `app/core/config.py` are dev-only

### Running Tests
- `pytest tests/` — runs all tests
- `pytest tests/test_safety_logic.py -v` — safety logic tests only (17 tests, no DB required)
- Integration tests require Postgres running on `localhost:5432` with test DB `civic_link_test`
- Config: `pyproject.toml` [tool.pytest.ini_options], asyncio_mode = "auto"

### Lint/Typecheck
- `ruff check app/` — linting
- `mypy app/` — type checking (strict mode, configured in `pyproject.toml`)
- `black app/` — formatting (line-length 100)

## Frontend (`civic_link/`)

### Entry Point
- `civic_link/lib/main.dart` — `main()` checks for stored auth token, routes to `LoginScreen` or `DashboardScreen`
- Base URL: `kBaseUrl = 'http://192.168.1.9:8000'` in `main.dart` (update for your network)

### Architecture
- Riverpod 3.x state management
- `lib/providers/auth_provider.dart` — `AuthNotifier` manages login/logout/session state
- `lib/providers/civic_score_provider.dart` — `CivicScoreNotifier` + 50Hz telemetry lifecycle
- `lib/services/auth_service.dart` — Zero-Liability auth (SHA-256 email hashing via `PrivacyCrypto`)
- `lib/services/telemetry_isolate.dart` — background isolate for 50Hz IMU sensor processing
- `lib/ui/screens/dashboard_screen.dart` — real-time score display with fl_chart

### Auth Flow
1. `LoginScreen` → `authProvider.notifier.login(email, password)` → stores userId + token in `FlutterSecureStorage`
2. `DashboardScreen` reads `authProvider` for real `userId`/`accessToken` → starts telemetry isolate
3. `AuthService` persists userId under key `civic_link_user_id`

### Telemetry Isolate
- Spawns separate Dart isolate via `Isolate.spawn`
- Communicates via `SendPort`/`ReceivePort` with sealed class protocol (`TelemetryCommand`/`TelemetryStatus`)
- Score updates flow: isolate → `ScoreUpdate` → `onScoreUpdate` callback → `CivicScoreNotifier.updateScore()`
- Lifecycle: `startTelemetry()` / `stopTelemetry()` / `ref.onDispose` cleanup

### Running Flutter
- `cd civic_link && flutter pub get`
- `flutter analyze` — static analysis (no errors, ~24 info-level deprecation warnings for `withOpacity`)
- `flutter run` — runs on connected device/emulator

### Dependencies
- `flutter_riverpod: ^3.3.1`, `dio: ^5.9.2`, `sensors_plus: ^7.0.0`, `fl_chart: ^1.2.0`, `flutter_secure_storage: ^10.1.0`

## Git & Branching
- `.gitignore` scopes `/lib/` to Python only; Flutter `civic_link/lib/` is unblocked via negation rules
- Main branch: `main`; development branch: `ustable`
- Never commit debug `print()` statements or hardcoded credentials

## Conventions
- No debug prints in committed code
- Safety-critical code (gender matching) must have both SQL and Python validation
- All email addresses hashed before transmission (Zero-Liability)
- PostGIS Geography type with SRID 4326 for all coordinates (NOT Geometry)
- Alembic migrations not yet set up — `app/migrations/` does not exist
