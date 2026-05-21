# Civic-Link DPI

**Safety-first carpooling for the Cyberabad IT Corridor**

Civic-Link is a non-commercial, safety-hardened carpooling Digital Public Infrastructure (DPI) for IT professionals commuting in Hyderabad. It combines a Python/FastAPI backend with a Flutter mobile app, enforcing safety at the database level and protecting user privacy through Zero-Liability email hashing.

---

## Key Features

- **Safety-First Matching** — Women-only rides are hard-rejected at the SQL level. No application-layer bypass is possible.
- **Zero-Liability Auth** — Emails are SHA-256 hashed client-side. Raw emails never reach the server. Domain whitelist enforced.
- **Civic Score** — Real-time driver behavior scoring from 50Hz IMU telemetry (gyroscope + accelerometer). Lane-cutting detection via gyro_z threshold.
- **Geospatial Matching** — PostGIS Geography type with SRID 4326 for meter-accurate distance calculations.
- **Encrypted Audit Trail** — All match events logged with AES-256-GCM encryption.
- **Privacy by Design** — Location data anonymized after 24 hours. GDPR/RTI compliant.

---

## Architecture

```
┌──────────────┐     REST API      ┌──────────────────┐
│  Flutter App  │ ◄──────────────► │   FastAPI Backend  │
│  (Dart 3.11)  │   /api/v1/*      │  (Python 3.12+)   │
└──────────────┘                   └────────┬─────────┘
                                            │
                              ┌─────────────┼─────────────┐
                              │             │             │
                        ┌─────▼─────┐ ┌─────▼─────┐ ┌────▼────┐
                        │ PostgreSQL│ │   Redis   │ │  Alembic│
                        │ + PostGIS │ │    7      │ │ Migrate │
                        │   16      │ └───────────┘ └─────────┘
                        └───────────┘
```

### Backend (`app/`)

| Layer | Files | Purpose |
|-------|-------|---------|
| Endpoints | `app/api/v1/endpoints/` | `auth`, `commutes`, `matches`, `civic_score`, `telemetry` |
| Services | `app/services/` | Business logic — match safety, commute CRUD, scoring, audit |
| Models | `app/models/` | SQLAlchemy 2.0 ORM — 8 tables with PostGIS Geography |
| Schemas | `app/schemas/` | Pydantic request/response validation |
| Core | `app/core/` | Config, database, security (JWT), exceptions, Redis |
| Migrations | `migrations/versions/` | Async Alembic — 2 migration files |

### Flutter App (`civic_link/lib/`)

| Layer | Files | Purpose |
|-------|-------|---------|
| Providers | `lib/providers/` | Riverpod 3.x state — auth, civic_score, commute, match, profile, theme |
| Services | `lib/services/` | AuthService (Dio + SecureStorage), TelemetryService (50Hz IMU isolate) |
| Screens | `lib/ui/screens/` | 12 screens — splash, login, register, dashboard, commute CRUD, match CRUD, profile, settings |
| Widgets | `lib/ui/widgets/` | 6 shared widgets — AuthGuard, CivicScoreBadge, CommuteCard, MatchCard, ErrorBanner, LoadingOverlay |
| Utils | `lib/utils/` | PrivacyCrypto (SHA-256 email hashing) |

---

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Python 3.12+
- Flutter 3.11+

### Backend

```bash
# Clone and enter project
git clone https://github.com/saketh1125/Civic-Link.git
cd Civic-Link

# Create .env from example
cp .env.example .env
# Edit .env with your keys (SECRET_KEY, JWT_SECRET_KEY, AUDIT_LOG_ENCRYPTION_KEY)

# Start services (Postgres + PostGIS, Redis, API)
docker compose up

# Or run locally
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# Run migrations
alembic upgrade head

# Seed database
python app/seed.py
```

The API runs at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

### Flutter App

```bash
cd civic_link

# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run with custom backend URL
flutter run --dart-define=BASE_URL=https://api.example.com

# Static analysis
flutter analyze

# Run tests
flutter test
```

---

## API Endpoints

### Authentication
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/v1/auth/register` | No | Register with hashed email |
| POST | `/api/v1/auth/login/access-token` | No | Login, get JWT |
| POST | `/api/v1/auth/refresh-token` | No | Refresh access token |
| GET | `/api/v1/auth/me` | Yes | Get current user profile |
| PUT | `/api/v1/auth/me` | Yes | Update profile |
| POST | `/api/v1/auth/change-password` | Yes | Change password |
| POST | `/api/v1/auth/verify` | Yes | Verify account |

### Commutes
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/v1/commutes/` | Yes | Create commute offer |
| GET | `/api/v1/commutes/my` | Yes | Get my commutes |
| GET | `/api/v1/commutes/search` | Yes | Search commutes |
| GET | `/api/v1/commutes/{id}` | Yes | Get commute details |
| POST | `/api/v1/commutes/{id}/cancel` | Yes | Cancel commute |
| POST | `/api/v1/commutes/offers` | Yes | Create ride request |
| GET | `/api/v1/commutes/offers/my` | Yes | Get my ride requests |

### Matches
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/v1/matches/{id}/request` | Yes | Request to join commute |
| POST | `/api/v1/matches/{id}/confirm` | Yes | Confirm match |
| POST | `/api/v1/matches/{id}/start` | Yes | Start trip |
| POST | `/api/v1/matches/{id}/complete` | Yes | Complete trip |
| POST | `/api/v1/matches/{id}/cancel` | Yes | Cancel match |
| GET | `/api/v1/matches/my` | Yes | Get my matches |
| GET | `/api/v1/matches/{id}` | Yes | Get match details |
| POST | `/api/v1/matches/{id}/rate` | Yes | Rate completed match |

### Civic Score
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/v1/civic-score/ingest` | Yes | Ingest telemetry samples |
| GET | `/api/v1/civic-score/me` | Yes | Get my civic score |
| GET | `/api/v1/civic-score/history` | Yes | Get score history |

### Telemetry
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/v1/telemetry/telemetry` | Yes | Submit IMU telemetry batch |

---

## Safety Logic (Critical)

The gender safety system is enforced at two layers:

**SQL Layer** (`app/services/match_service.py:68-99`):
```sql
-- Women-only commutes reject non-female passengers
WHERE (c.is_women_only = FALSE OR u.gender = 'female')
-- Women-only offers reject non-female drivers
WHERE (co.is_women_only = FALSE OR du.gender = 'female')
```

**Python Layer**: Double-validation in `create_match()` checks the same conditions after the SQL query returns.

**Never modify safety logic without understanding both layers.**

---

## Database

8 tables with PostGIS Geography (SRID 4326):

| Table | Purpose |
|-------|---------|
| `users` | Commuter profiles, auth, verification |
| `commutes` | Driver ride offers with geospatial origin/destination |
| `commute_offers` | Passenger ride requests |
| `commute_matches` | Driver-passenger pairings with safety snapshots |
| `civic_scores` | Driver behavior scoring (swerve, speeding, braking) |
| `civic_score_history` | Audit trail of score changes |
| `commute_audit_logs` | AES-256-GCM encrypted event logs |
| `safety_alert_logs` | Safety incident reports |

See [documentation/03-Database-Schema.md](documentation/03-Database-Schema.md) for full schema.

---

## Testing

### Backend (pytest)

```bash
# All tests
pytest tests/ -v

# Safety logic only (no DB required)
pytest tests/test_safety_logic.py -v

# User model + JWT tests
pytest tests/test_users.py -v

# Commute model tests
pytest tests/test_commutes.py -v

# Match model tests
pytest tests/test_matches.py -v
```

**75 tests passing** across 4 test files.

### Flutter

```bash
cd civic_link
flutter test
flutter analyze  # 0 errors
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SECRET_KEY` | Yes | Application secret key |
| `JWT_SECRET_KEY` | Yes | JWT signing key |
| `AUDIT_LOG_ENCRYPTION_KEY` | Yes | 64-char hex key for AES-256-GCM |
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `REDIS_URL` | No | Redis connection string |
| `SENTRY_DSN` | No | Sentry error tracking DSN |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | No | JWT expiry (default: 30) |
| `REFRESH_TOKEN_EXPIRE_DAYS` | No | Refresh token expiry (default: 7) |

---

## Documentation

| Document | Description |
|----------|-------------|
| [01-Project-Overview.md](documentation/01-Project-Overview.md) | Mission, features, tech stack, roadmap |
| [02-Architecture.md](documentation/02-Architecture.md) | System design, data flows |
| [03-Database-Schema.md](documentation/03-Database-Schema.md) | ER diagrams, table specifications |
| [04-API-Reference.md](documentation/04-API-Reference.md) | Endpoint documentation |
| [05-Testing-Guide.md](documentation/05-Testing-Guide.md) | Test procedures |
| [06-Development-Guide.md](documentation/06-Development-Guide.md) | Setup, coding standards, Flutter dev |
| [07-Changelog.md](documentation/07-Changelog.md) | Version history |
| [08-Flutter-UI-Specification.md](documentation/08-Flutter-UI-Specification.md) | Flutter screens, widgets, providers |

---

## CI/CD

GitHub Actions workflows in `.github/workflows/`:

- **backend-ci.yml** — Lint (flake8, black) + test (PostGIS service container, pytest)
- **flutter-ci.yml** — Analyze + test + build APK
- **pr-checks.yml** — Runs both CI pipelines + secret scanning on PRs

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit with conventional messages (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`)
4. Push and open a PR against `ustable`

**Rules:**
- Safety-critical code must have both SQL and Python validation
- All email addresses hashed before transmission (Zero-Liability)
- PostGIS Geography type with SRID 4326 for all coordinates
- No debug `print()` statements or hardcoded credentials in commits

---

## License

This is a Digital Public Infrastructure project. See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

---

*Built for the Cyberabad IT Corridor — KPHB Phase 3 to Mindspace/HITEC City*
