# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Civic-Link DPI is a safety-first carpooling platform for the Cyberabad IT Corridor. It consists of a Python/FastAPI backend and a Flutter mobile app connected via REST API.

## Monorepo Structure

| Directory | What | Language |
|-----------|------|----------|
| `app/` | FastAPI backend (API, models, services, schemas) | Python 3.12+ |
| `civic_link/` | Flutter mobile app | Dart 3.11+ |
| `tests/` | Backend pytest tests | Python |
| `documentation/` | Architecture, API, schema docs | Markdown |

## Backend Commands

```bash
# Start all services (Postgres + PostGIS, Redis, API)
docker compose up

# Run API locally
uvicorn app.main:app --reload --port 8000

# Run migrations
docker compose --profile migrations up
# or locally:
alembic upgrade head

# Production deploy
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# Tests
pytest tests/                           # all tests
pytest tests/test_safety_logic.py -v    # safety logic only (no DB required)
pytest tests/test_safety_logic.py::test_name -v  # single test

# Lint/format/typecheck
ruff check app/
black app/ --line-length 100
mypy app/
```

## Flutter Commands

```bash
cd civic_link
flutter pub get          # install dependencies
flutter analyze          # static analysis
flutter run              # run on connected device
flutter test             # run tests
dart format lib/         # format code
```

## Architecture

### Backend (`app/`)

- **Entry point:** `app/main.py` — FastAPI app, mounts router at `/api/v1`
- **API endpoints:** `app/api/v1/endpoints/` — `auth.py`, `telemetry.py`, `commutes.py`, `matches.py`, `civic_score.py`
- **Services:** `app/services/` — business logic. `match_service.py` contains the critical safety hard-reject SQL
- **Models:** `app/models/` — SQLAlchemy 2.0 ORM with PostGIS Geography (SRID 4326)
- **Schemas:** `app/schemas/` — Pydantic request/response models
- **Core:** `app/core/` — config, database, security (JWT), exceptions, redis
- **Migrations:** `migrations/env.py` (async Alembic), `migrations/versions/` (schema versions)

### Flutter (`civic_link/lib/`)

- **Entry point:** `lib/main.dart` — constants, LoginScreen, app root with `SplashScreen` as initial route
- **State management:** Riverpod 3.x with `Notifier` pattern (not legacy StateNotifier)
- **Providers:** `lib/providers/` — `auth_provider.dart`, `civic_score_provider.dart`, `commute_provider.dart`, `commute_search_provider.dart`, `match_provider.dart`
- **Services:** `lib/services/` — `auth_service.dart` (Dio + FlutterSecureStorage), `telemetry_isolate.dart` (50Hz IMU isolate)
- **Screens:** `lib/ui/screens/` — splash, login, registration, dashboard, commute CRUD, match CRUD, rating
- **Widgets:** `lib/ui/widgets/` — shared widgets (CivicScoreBadge, CommuteCard, MatchCard, LoadingOverlay, ErrorBanner, AuthGuard)
- **Navigation:** Manual `Navigator.push`/`pushReplacement` with `MaterialPageRoute` (no go_router)

### Key Patterns

- **Zero-Liability Auth:** Email is SHA-256 hashed client-side via `PrivacyCrypto`; only hash + domain sent to server. Domain whitelist enforced server-side.
- **Auth Guard:** Protected screens wrap content in `AuthGuard` widget which checks `authProvider` and redirects to login if unauthenticated.
- **Provider Token Flow:** All new providers create Dio instances with token from `authProvider` and handle 401 with auto-logout.
- **Telemetry Isolate:** Background Dart isolate reads IMU sensors at 50Hz, computes civic score locally, batches data for server transmission. Communicates via `SendPort`/`ReceivePort` with sealed class protocol.

## Critical Safety Logic

`app/services/match_service.py:68-99` contains SQL-level hard-reject gender filtering:
- Women-only commutes reject non-female passengers
- Women-only offers reject non-female drivers
- Double validation: SQL clause + Python-level check in `create_match()`
- Never modify safety logic without understanding both layers

## Environment

- `.env` controls credentials; `SECRET_KEY`, `AUDIT_LOG_ENCRYPTION_KEY`, `JWT_SECRET_KEY` are REQUIRED (no defaults)
- `kBaseUrl` in `civic_link/lib/main.dart:16` is hardcoded — update for your network
- `create_all()` runs only in development — production uses `alembic upgrade head`

## Git

- Main branch: `main`; development branch: `ustable`
- Commit convention: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`
- No debug `print()` statements or hardcoded credentials in committed code
