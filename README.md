# Civic-Link DPI

**A safety-first, privacy-hardened carpooling platform for urban commuters.**

Civic-Link is a non-commercial Digital Public Infrastructure (DPI) designed to make shared commuting safe, transparent, and accessible. It combines real-time driver behavior scoring with strict gender-safety enforcement to build trust in carpooling — starting with the Cyberabad IT Corridor in Hyderabad, India.

---

## Table of Contents

1. [The Problem](#the-problem)
2. [What Civic-Link Does](#what-civic-link-does)
3. [How Safety Works](#how-safety-works)
4. [Privacy by Design](#privacy-by-design)
5. [The Civic Score System](#the-civic-score-system)
6. [Architecture](#architecture)
7. [Project Structure](#project-structure)
8. [Quick Start](#quick-start)
9. [API Reference](#api-reference)
10. [Mobile App](#mobile-app)
11. [Database](#database)
12. [Security Architecture](#security-architecture)
13. [Testing](#testing)
14. [CI/CD Pipeline](#cicd-pipeline)
15. [Deployment](#deployment)
16. [Operations](#operations)
17. [Contributing](#contributing)
18. [Documentation Map](#documentation-map)
19. [License](#license)

---

## The Problem

In Indian IT corridors, 60-70% of employees drive single-occupancy vehicles over the same routes every day. The result:

| Problem | Impact |
|---------|--------|
| **Traffic congestion** | 45-90 minute commutes for 12-22 km distances |
| **Safety concerns** | Women hesitant to share rides with strangers |
| **No trust layer** | No way to verify a driver's behavior before getting in |
| **Privacy risk** | Commercial apps collect and monetize location data |
| **Environmental cost** | Thousands of single-occupancy cars per corridor daily |

Existing ride-sharing apps optimize for profit, not safety. Civic-Link reimagines carpooling as public infrastructure — where safety is enforced by the database itself, not by trust in a brand.

---

## What Civic-Link Does

### For Commuters
- **Find or offer rides** along your daily route with verified colleagues
- **Women-only mode** — guarantee your ride partner is female, enforced at the database level
- **Driver behavior scores** — see a real-time Civic Score for every driver before you ride
- **Full privacy** — your email never leaves your phone; locations are anonymized after your trip

### For Organizations
- **Corporate commute management** — reduce parking demand and carbon footprint
- **Domain-verified trust** — users authenticate via company email (client-side hashed)
- **Safety compliance** — encrypted audit trail for every trip
- **Zero-liability** — raw emails never touch the server

### Match Lifecycle

```
REQUEST → CONFIRMED → IN_PROGRESS → COMPLETED
    ↓          ↓                        ↓
 CANCELLED  CANCELLED               CANCELLED
                                       ↓
                                    NO_SHOW
```

Every state transition is:
- **Validated server-side** — invalid transitions return `INVALID_STATE_TRANSITION`
- **Audit logged** — AES-256-GCM encrypted event log for every state change
- **Atomic** — duplicate match prevention via `SELECT FOR UPDATE`

---

## How Safety Works

Civic-Link's safety model operates at two independent layers — no single layer can be bypassed.

### Layer 1: Database-Level Enforcement

When a passenger searches for rides, the SQL query itself contains hard constraints:
- Women-only passengers see **only female drivers** — filtered in the `WHERE` clause
- Women-only commutes accept **only female passengers** — filtered in the `WHERE` clause

This is not application logic. It's the database query. No API change, no code update, no configuration toggle can override it.

### Layer 2: Application-Level Validation

Before any match is created, a second check runs in Python:
- Verifies gender constraints again after the database returns results
- Raises a `CivicLinkSafetyException` if violated — the match is blocked

### Safety Snapshots

Every match record captures the safety context at the moment it was created:
- Whether the commute was women-only at match time
- Whether the offer was women-only at match time

This creates an immutable audit trail — even if the parent records change later.

---

## Privacy by Design

### Zero-Liability Authentication

| What happens | What does NOT happen |
|-------------|---------------------|
| Email is SHA-256 hashed **on the device** | Raw email never leaves the phone |
| Only hash + domain sent to server | Server never stores plaintext emails |
| Domain whitelist enforced (e.g. `@cmrcet.ac.in`) | Unauthorized domains rejected at registration |
| JWT access tokens (60 min) + refresh tokens (7 days) | Access tokens cannot be used as refresh tokens |

### Data Retention

- Location data is anonymized after trip completion
- Audit logs are encrypted at rest with AES-256-GCM
- GDPR/RTI compliant architecture

---

## The Civic Score System

Every driver has a Civic Score — a 0-100 rating computed from real-time phone sensor data.

### How It Works

1. The mobile app reads the phone's IMU sensors (gyroscope + accelerometer) at 50 Hz
2. A background Dart isolate processes the data stream, detecting driving events
3. Batched telemetry is sent to the backend
4. The backend computes a weighted rolling score that updates in real-time

### What It Measures

| Behavior | Detection Method | Impact |
|----------|-----------------|--------|
| **Lane-cutting / swerving** | Gyroscope Z-axis spikes | High penalty |
| **Speeding** | Speed samples vs. threshold | Moderate penalty |
| **Hard braking** | Acceleration samples | Moderate penalty |
| **Phone usage** | Sensor patterns | Penalty applied |

### Score Tiers

| Score | Tier | Color | Meaning |
|-------|------|-------|---------|
| 90-100 | CRUISING | Green | Safe, smooth driving |
| 70-89 | WARNING | Yellow | Some concerning events |
| 0-69 | ALERT | Red | Unsafe driving pattern |

The score is a rolling average — it recovers over time with good driving, or degrades quickly with violations. Passengers see the driver's score before accepting a ride.

---

## Architecture

```
┌────────────────────┐                         ┌───────────────────────────┐
│   Flutter Mobile   │    HTTPS / REST         │     FastAPI Backend        │
│   App (Dart 3.11)  │ ◄─────────────────────► │     (Python 3.12+)          │
│                    │    /api/v1/*            │                            │
│ ┌────────────────┐ │                         │ ┌────────────────────────┐ │
│ │ Riverpod State │ │                         │ │ API Layer              │ │
│ │ Background     │ │                         │ │ (endpoints + schemas)  │ │
│ │ IMU Isolate    │ │     Background Tasks    │ │                        │ │
│ │ 50Hz Telemetry │ │ ◄─────────────────────► │ │ ┌────────────────────┐ │ │
│ └────────────────┘ │                         │ │ │ Service Layer      │ │ │
└────────────────────┘                         │ │ │ (business logic)   │ │ │
                                               │ │ │                    │ │ │
                                               │ │ │ ┌────────────────┐ │ │ │
                                               │ │ │ │ Data Access    │ │ │ │
                                               │ │ │ │ (SQLAlchemy)   │ │ │ │
                                               │ │ │ └────────────────┘ │ │ │
                                               │ │ └────────────────────┘ │ │
                                               │ └────────────────────────┘ │
                                               │                            │
                                               └──────────┬─────────────────┘
                                                          │
                                      ┌───────────────────┼───────────────────┐
                                      │                   │                   │
                              ┌───────▼──────┐   ┌───────▼──────┐   ┌────────▼──────┐
                              │  PostgreSQL  │   │    Redis      │   │    Nginx       │
                              │  + PostGIS   │   │    Cache      │   │  (production)  │
                              │    16        │   │   Rate Limit  │   │  Reverse Proxy │
                              └──────────────┘   └──────────────┘   └───────────────┘
```

### Technology Stack

| Layer | Technology | Role |
|-------|-----------|------|
| **API Framework** | FastAPI (Python 3.12) | Async REST API with auto-docs |
| **Database** | PostgreSQL 16 + PostGIS 3.4 | Geospatial carpool matching |
| **Cache** | Redis 7 | Sliding-window rate limiting, commute caching |
| **ORM** | SQLAlchemy 2.0 (async) | Type-safe database access |
| **Validation** | Pydantic 2.x | Request/response schema validation |
| **Migrations** | Alembic (async) | Database schema versioning |
| **Mobile** | Flutter 3.11 / Dart | Cross-platform iOS & Android |
| **State Mgmt** | Riverpod 3.x | Compile-safe reactive state |
| **HTTP Client** | Dio 5.x | Authenticated API communication |
| **Charts** | fl_chart 1.x | Real-time score history visualization |
| **Sensors** | sensors_plus 7.x | 50 Hz IMU data collection |
| **Container** | Docker Compose | Dev & production orchestration |

### Design Patterns

- **Layered architecture** — API → Service → Data Access, each with clear boundaries
- **Async-first** — All database and cache operations are non-blocking
- **Graceful degradation** — Redis unavailability never crashes the API
- **Immutable audit** — Every state change is encrypted and logged
- **Defense in depth** — Safety constraints enforced at multiple layers

---

## Project Structure

```
Traffic-pooling/
│
├── app/                              # FastAPI Backend
│   ├── api/
│   │   └── v1/
│   │       ├── api.py                # Router aggregation
│   │       └── endpoints/            # Route handlers
│   │           ├── auth.py           # Login, register, refresh, profile
│   │           ├── commutes.py       # Commute CRUD + search
│   │           ├── matches.py        # Match lifecycle (request→complete)
│   │           ├── civic_score.py    # Score retrieval + history
│   │           └── telemetry.py      # IMU data ingestion
│   ├── core/
│   │   ├── config.py                 # Settings (env-based)
│   │   ├── database.py               # Async SQLAlchemy engine
│   │   ├── security.py               # JWT creation, verification, refresh
│   │   ├── exceptions.py             # Custom exception classes
│   │   └── redis.py                  # Async Redis client + utilities
│   ├── models/
│   │   ├── user.py                   # User, verification, auth
│   │   ├── commute.py                # Commute + CommuteOffer
│   │   ├── match.py                  # CommuteMatch with safety snapshots
│   │   ├── civic_score.py            # CivicScore + score history
│   │   └── audit.py                  # AES-256-GCM encrypted audit logs
│   ├── schemas/                      # Pydantic request/response models
│   ├── services/                     # Business logic layer
│   │   ├── match_service.py          # Safety-filtered matching
│   │   ├── commute_service.py        # Commute CRUD + geospatial search
│   │   ├── telemetry_service.py      # IMU processing + swerve detection
│   │   ├── civic_score_service.py    # Rolling score computation
│   │   ├── user_service.py           # Profile management
│   │   └── audit_service.py          # Encrypted event logging
│   ├── middleware/
│   │   └── rate_limit.py             # Sliding window rate limiter
│   └── main.py                       # FastAPI app + lifespan + exception handlers
│
├── civic_link/                       # Flutter Mobile App
│   ├── lib/
│   │   ├── main.dart                 # Entry point, theme, LoginScreen
│   │   ├── providers/                # Riverpod state (5 notifiers)
│   │   │   ├── auth_provider.dart    # Auth + session management
│   │   │   ├── civic_score_provider.dart  # 50Hz telemetry lifecycle
│   │   │   ├── commute_provider.dart # Commute CRUD
│   │   │   ├── match_provider.dart   # Match lifecycle
│   │   │   └── profile_provider.dart # User profile
│   │   ├── services/
│   │   │   ├── auth_service.dart     # Dio client + 401 interceptor + refresh
│   │   │   └── telemetry_isolate.dart # Background IMU processing isolate
│   │   ├── ui/
│   │   │   ├── screens/              # 13 screens
│   │   │   │   ├── splash_screen.dart
│   │   │   │   ├── dashboard_screen.dart
│   │   │   │   ├── registration_screen.dart
│   │   │   │   ├── commute_create_screen.dart
│   │   │   │   ├── commute_search_screen.dart
│   │   │   │   ├── commute_detail_screen.dart
│   │   │   │   ├── my_commutes_screen.dart
│   │   │   │   ├── match_detail_screen.dart
│   │   │   │   ├── my_matches_screen.dart
│   │   │   │   ├── rating_screen.dart
│   │   │   │   ├── profile_screen.dart
│   │   │   │   ├── settings_screen.dart
│   │   │   │   └── change_password_screen.dart
│   │   │   └── widgets/              # 6 reusable widgets
│   │   │       ├── auth_guard.dart
│   │   │       ├── civic_score_badge.dart
│   │   │       ├── commute_card.dart
│   │   │       ├── match_card.dart
│   │   │       ├── loading_overlay.dart
│   │   │       └── error_banner.dart
│   │   └── utils/
│   │       └── privacy_crypto.dart    # SHA-256 email hashing
│   └── test/                          # 37 widget + unit tests
│       ├── helpers/
│       │   ├── pump_app.dart
│       │   └── mock_providers.dart
│       ├── screens/
│       │   ├── login_screen_test.dart
│       │   └── dashboard_screen_test.dart
│       ├── providers/
│       │   └── auth_provider_test.dart
│       └── models/
│           └── civic_score_test.dart
│
├── tests/                             # Backend pytest suite (75 tests)
│   ├── test_safety_logic.py          # Gender matching enforcement
│   ├── test_users.py                 # User model + JWT tests
│   ├── test_commutes.py              # Commute CRUD tests
│   └── test_matches.py               # Match lifecycle tests
│
├── migrations/                        # Alembic async migrations
│   ├── env.py
│   └── versions/
│
├── documentation/                     # Detailed technical docs (9 guides)
│   ├── 01-Project-Overview.md
│   ├── 02-Architecture.md
│   ├── 03-Database-Schema.md
│   ├── 04-API-Reference.md
│   ├── 05-Testing-Guide.md
│   ├── 06-Development-Guide.md
│   ├── 07-Changelog.md
│   └── 08-Flutter-UI-Specification.md
│
├── docker/                            # Nginx + Redis config
├── .github/workflows/                 # CI/CD pipelines
│   ├── backend-ci.yml                # Lint → Test (PostGIS service)
│   ├── flutter-ci.yml                # Analyze → Test → Build APK
│   └── pr-checks.yml                 # Combined CI + secret scanning
│
├── docker-compose.yml                 # Dev environment (API + PostGIS + Redis)
├── docker-compose.prod.yml            # Production-hardened deployment
├── Makefile                           # 15 development commands
├── .dockerignore
├── pyproject.toml                     # Python project config + tool settings
└── requirements.txt                   # Python dependencies
```

---

## Quick Start

### Prerequisites

- **Docker** & **Docker Compose** (recommended for quick setup)
- **Python 3.12+** (for local development)
- **Flutter SDK 3.11+** (for mobile app)

### Backend (Docker — Easiest)

```bash
git clone https://github.com/saketh1125/Civic-Link.git
cd Civic-Link

# Create and configure environment
cp .env.example .env
# REQUIRED: Set SECRET_KEY, JWT_SECRET_KEY, AUDIT_LOG_ENCRYPTION_KEY
# Generate a 64-char hex key: openssl rand -hex 32

# Start all services
docker compose up

# Run migrations (separate terminal)
docker compose --profile migrations up

# API available at http://localhost:8000
# Interactive docs at http://localhost:8000/docs
```

### Backend (Local Development)

```bash
pip install -r requirements.txt

# Start PostgreSQL + Redis via Docker
docker compose up postgres redis -d

# Run migrations
alembic upgrade head

# Start API with hot reload
uvicorn app.main:app --reload --port 8000
```

### Flutter App

```bash
cd civic_link
flutter pub get

# Run on connected device
flutter run

# Run with custom backend URL
flutter run --dart-define=BASE_URL=https://api.example.com

# Run tests
flutter test

# Static analysis
flutter analyze
```

### Makefile Commands

```bash
make help          # Show all available commands
make dev           # Start Docker services
make stop          # Stop all services
make test          # Run backend test suite
make lint          # Run flake8 + black check
make format        # Auto-format Python code
make migrate       # Run Alembic migrations
make migration     # Generate new migration (m="description")
make rollback      # Rollback last migration
make shell         # Open psql in Postgres container
make logs          # Tail API logs
make prod-up       # Deploy production stack
make prod-down     # Stop production stack
```

---

## API Reference

### Authentication

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/auth/register` | No | Register with client-hashed email |
| `POST` | `/api/v1/auth/login/access-token` | No | Login — returns JWT access + refresh tokens |
| `POST` | `/api/v1/auth/refresh-token` | No | Rotate refresh token for new access token |
| `GET` | `/api/v1/auth/me` | Yes | Get current user profile |
| `PUT` | `/api/v1/auth/me` | Yes | Update profile (partial updates supported) |
| `POST` | `/api/v1/auth/change-password` | Yes | Change password with current password verification |
| `POST` | `/api/v1/auth/verify` | Yes | Verify account (placeholder token flow) |

### Commutes

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/commutes/` | Yes | Create commute offer (driver) |
| `GET` | `/api/v1/commutes/my` | Yes | Get authenticated user's commutes |
| `GET` | `/api/v1/commutes/search` | Yes | Search public commutes (excludes own + cancelled) |
| `GET` | `/api/v1/commutes/{id}` | Yes | Get commute with driver details |
| `POST` | `/api/v1/commutes/{id}/cancel` | Yes | Cancel an active commute |
| `POST` | `/api/v1/commutes/offers` | Yes | Create ride request (passenger) |
| `GET` | `/api/v1/commutes/offers/my` | Yes | Get authenticated user's ride requests |

### Matches

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/matches/{id}/request` | Yes | Request to join a commute |
| `POST` | `/api/v1/matches/{id}/confirm` | Yes | Driver confirms a match |
| `POST` | `/api/v1/matches/{id}/start` | Yes | Start the trip |
| `POST` | `/api/v1/matches/{id}/complete` | Yes | Complete the trip |
| `POST` | `/api/v1/matches/{id}/cancel` | Yes | Cancel a match |
| `POST` | `/api/v1/matches/{id}/rate` | Yes | Rate a completed match |
| `GET` | `/api/v1/matches/my` | Yes | Get user's active matches |
| `GET` | `/api/v1/matches/{id}` | Yes | Get match details |

### Civic Score

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/civic-score/ingest` | Yes | Submit trip telemetry for scoring |
| `GET` | `/api/v1/civic-score/me` | Yes | Get current score + trip stats |
| `GET` | `/api/v1/civic-score/history` | Yes | Get score change history |

### Telemetry

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/telemetry/telemetry` | Yes | Submit IMU sensor batch (50 Hz) |

### Health

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/health` | No | Service health check |

### Common Error Response Format

```json
{
  "detail": "Error description"
}
```

| Status | Meaning |
|--------|---------|
| `400` | Invalid input or invalid state transition |
| `401` | Missing or expired authentication |
| `403` | Permission denied or safety violation |
| `404` | Resource not found |
| `409` | Conflict (e.g., duplicate match) |
| `422` | Request validation failure |
| `500` | Internal server error |

See `documentation/04-API-Reference.md` for complete request/response schemas and curl examples.

---

## Mobile App

The Flutter app provides a complete carpooling experience with real-time driver behavior monitoring.

### Screen Flow

```
SplashScreen
    ↓ (check stored auth)
    ├──→ DashboardScreen (authenticated)
    │        ↓
    │        ├──→ CommuteSearchScreen → CommuteDetailScreen → MatchDetailScreen
    │        ├──→ CommuteCreateScreen
    │        ├──→ MyCommutesScreen
    │        ├──→ MyMatchesScreen → RatingScreen
    │        ├──→ ProfileScreen
    │        ├──→ SettingsScreen → ChangePasswordScreen
    │
    └──→ LoginScreen → RegistrationScreen
```

### Key Features

- **Dark/Light theme** with persistent preference via SharedPreferences
- **Background telemetry** — 50 Hz IMU processing in a separate Dart isolate
- **Token refresh** — Automatic 401 interception with single-retry refresh
- **Session persistence** — Secure token storage in FlutterSecureStorage
- **Offline-tolerant** — Graceful handling of network unavailability
- **Shared widget library** — 6 reusable components (AuthGuard, CivicScoreBadge, etc.)

### Configuration

| Build Flag | Default | Description |
|-----------|---------|-------------|
| `BASE_URL` | `http://192.168.1.9:8000` | Backend API URL |
| `SENTRY_DSN` | `""` | Sentry error tracking |
| `FLUTTER_ENV` | `development` | Environment label |

---

## Database

### Engine

**PostgreSQL 16** with **PostGIS 3.4** extension. All geographic data uses the `Geography` type (not `Geometry`) with SRID 4326 for accurate earth-surface distance calculations in meters.

### Tables (8)

| Table | Purpose |
|-------|---------|
| `users` | Commuter profiles, Zero-Liability auth, verification status |
| `commutes` | Driver ride offers with geospatial origin/destination |
| `commute_offers` | Passenger ride requests |
| `commute_matches` | Driver-passenger pairings with safety snapshots |
| `civic_scores` | Per-user driving behavior scores |
| `civic_score_history` | Audit trail of all score changes |
| `commute_audit_logs` | AES-256-GCM encrypted event logs |
| `safety_alert_logs` | Safety incident reports |

### Enums (9)

`Gender` (male, female, undisclosed), `UserRole` (commuter, admin, moderator), `CommuteStatus` (active, cancelled, completed, expired), `MatchStatus` (pending, confirmed, in_progress, completed, cancelled, no_show), `PaymentStatus`, `ScoreTier`, `CommuteType`, `VerificationStatus`, `AuditEventType`.

### Spatial Queries

Matching uses `ST_DWithin` on `Geography` columns for meter-level accuracy. GIST spatial indexes are maintained on origin and destination columns.

Full schema: `documentation/03-Database-Schema.md`

---

## Security Architecture

### Authentication Flow

```
Client (Flutter)                              Server (FastAPI)
─────────────────                             ──────────────────
Email → SHA-256 hash
       ↓
POST /auth/login/access-token
       {email_hash, email_domain, password}
       ──────────────────────────────►        Verify hash + domain + password
                                              Issue JWT (type: access, 60 min)
                                              Issue JWT (type: refresh, 7 days)
       ◄──────────────────────────────        {access_token, refresh_token}

All subsequent requests:
       Authorization: Bearer <access_token>
       ──────────────────────────────►        Verify JWT signature + expiry
                                              Extract user from claims
       ◄──────────────────────────────        Response

Token expired (401):
       ──────────────────────────────►        401 Unauthorized
        POST /auth/refresh-token
        Authorization: Bearer <refresh_token>
        ──────────────────────────────►        Verify type=refresh claim
                                              Issue rotated token pair
       ◄──────────────────────────────        {access_token, refresh_token}
       Retry original request
```

### Key Security Properties

- **Raw emails never reach the server** — SHA-256 hashed client-side
- **Domain whitelist enforced** — only approved email domains can register
- **Access tokens cannot refresh themselves** — must use dedicated refresh token with `type=refresh` claim
- **Only one refresh attempt per failed request** — no infinite retry loops
- **Database-level safety enforcement** — independent of application code
- **Double validation** — both SQL and Python layers must agree
- **Encrypted audit trail** — AES-256-GCM for all match and state change events
- **Sliding window rate limiting** — Redis-backed, per-endpoint configurable
- **Graceful Redis degradation** — rate limiter returns `None` on cache failure, never crashes

---

## Testing

### Backend (pytest)

```bash
# All tests
pytest tests/ -v                    # 75 tests

# Specific test files
pytest tests/test_safety_logic.py -v  # Safety enforcement (no DB required)
pytest tests/test_users.py -v         # User model + JWT
pytest tests/test_commutes.py -v      # Commute CRUD
pytest tests/test_matches.py -v       # Match lifecycle
```

Integration tests require a running PostgreSQL instance. The safety logic tests are pure unit tests — no database required.

### Flutter

```bash
cd civic_link
flutter test                        # 37 tests
flutter analyze                     # Static analysis

# Test categories
flutter test test/models/            # CivicScore model (19 tests)
flutter test test/providers/         # Auth provider (7 tests)
flutter test test/screens/           # Login (7 tests) + Dashboard (4 tests)
```

### Coverage (per-file)

| Test File | Tests | Target |
|-----------|-------|--------|
| `test_safety_logic.py` | 17 | Gender matching enforcement |
| `test_users.py` | 22 | User model, JWT, auth flows |
| `test_commutes.py` | 18 | Commute CRUD + search |
| `test_matches.py` | 18 | Match lifecycle + state transitions |
| Flutter: `civic_score_test.dart` | 19 | Model + provider behavior |
| Flutter: `auth_provider_test.dart` | 7 | Auth state machine |
| Flutter: `login_screen_test.dart` | 7 | Form validation + error states |
| Flutter: `dashboard_screen_test.dart` | 4 | Score display + UI rendering |

**Total: 112 tests (75 backend + 37 Flutter)**

---

## CI/CD Pipeline

All workflows in `.github/workflows/`:

### Backend CI (`backend-ci.yml`)
- **Triggers**: Push to `main`/`ustable`, PRs to `main`, manual `workflow_call`
- **Lint**: flake8 + black check
- **Test**: pytest with PostGIS 16-3.4 service container
- **Artifacts**: Uploaded on failure for debugging

### Flutter CI (`flutter-ci.yml`)
- **Triggers**: Push to `main`/`ustable`, PRs to `main`
- **Analyze**: `flutter analyze --no-fatal-infos`
- **Test**: `flutter test` (37 tests)
- **Build**: Debug APK as smoketest

### PR Checks (`pr-checks.yml`)
- **Triggers**: Pull requests to `main` only (avoids double-execution with push triggers)
- Runs both CI workflows via `workflow_call`
- Secret scanning for `AKIA*`, `sk-*`, `BEGIN PRIVATE KEY` patterns
- Posts a summary comment on the PR

---

## Deployment

### Development

```bash
docker compose up                     # API on :8000, Postgres :5432, Redis :6379
docker compose --profile migrations up  # Run migrations
```

### Production

```bash
# Create .env.production with strong keys
cp .env.example .env.production
# Edit with production values

# Deploy production stack
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

Production configuration includes:
- Nginx reverse proxy with security headers
- API with 4 workers, no hot reload
- Resource limits on all containers
- Redis with appendonly persistence, allkeys-lru eviction
- Postgres with volume persistence, no exposed ports
- Migrations run before API starts (`condition: service_completed_successfully`)

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SECRET_KEY` | **Yes** | — | Application secret key |
| `JWT_SECRET_KEY` | **Yes** | — | JWT signing key |
| `AUDIT_LOG_ENCRYPTION_KEY` | **Yes** | — | 64-char hex for AES-256-GCM |
| `DATABASE_URL` | Yes | — | PostgreSQL connection string |
| `REDIS_URL` | No | `redis://redis:6379/0` | Redis connection |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | No | `60` | Access token lifetime |
| `REFRESH_TOKEN_EXPIRE_DAYS` | No | `7` | Refresh token lifetime |
| `SENTRY_DSN` | No | `""` | Error tracking |

Generate secure keys:
```bash
openssl rand -hex 32   # For SECRET_KEY, JWT_SECRET_KEY
openssl rand -hex 64   # For AUDIT_LOG_ENCRYPTION_KEY
```

---

## Operations

### Monitoring

- **Health check**: `GET /health` — returns service status and version
- **Structured logging** with request IDs
- **Graceful degradation**: Redis failures are logged but never crash the API
- **Sentry integration**: Error tracking via `SENTRY_DSN` (optional)

### Maintenance Tasks

```bash
make logs       # Watch API logs in real-time
make shell      # Open PostgreSQL shell
make migrate    # Apply pending migrations
make rollback   # Rollback last migration
```

### Common Operations

```bash
# Rebuild after dependency changes
docker compose build api

# Reset database (development only)
docker compose down -v
docker compose up postgres -d
docker compose --profile migrations up

# View database from host
make shell
```

---

## Contributing

### Branch Strategy

- `main` — production-ready code
- `ustable` — active development branch (target for PRs)

### Workflow

1. Fork the repository
2. Create a feature branch from `ustable`
3. Make your changes following the conventions below
4. Write or update tests
5. Run lint + typecheck + tests locally
6. Push and open a PR against `ustable`

### Code Conventions

| Rule | Rationale |
|------|-----------|
| Safety-critical code needs SQL + Python validation | Defense in depth |
| All email addresses hashed before transmission | Zero-Liability |
| PostGIS `Geography` type with SRID 4326 | Meter-accurate distances |
| No `print()` statements or hardcoded credentials | Security |
| Async all database operations | Non-blocking performance |
| `ruff check app/` — 0 errors | Code quality |
| `mypy app/` — strict mode | Type safety |
| `black app/` — line length 100 | Consistent formatting |
| `flutter analyze` — 0 errors | Flutter code quality |

### Commit Convention

Use conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `ci:`, `chore:`

---

## Documentation Map

| Document | Contents |
|----------|----------|
| `README.md` (this file) | Project overview, quick start, architecture, deployment |
| `documentation/01-Project-Overview.md` | Mission, features, roadmap, target users |
| `documentation/02-Architecture.md` | Layered design, data flows, security architecture |
| `documentation/03-Database-Schema.md` | ER diagrams, table specs, enums, indexes |
| `documentation/04-API-Reference.md` | Complete API docs with request/response schemas |
| `documentation/05-Testing-Guide.md` | Test categories, seed data, load testing |
| `documentation/06-Development-Guide.md` | Setup, coding standards, common tasks |
| `documentation/07-Changelog.md` | Version history from v0.1.0 to v0.5.0 |
| `documentation/08-Flutter-UI-Specification.md` | Screens, widgets, providers, routing |
| `AGENTS.md` | Instructions for automated tooling and agents |

---

## License

Civic-Link is a Digital Public Infrastructure project. Built for public good.

---

*Safety-hardened carpooling for the Cyberabad IT Corridor. KPHB Phase 3 → Mindspace/HITEC City.*