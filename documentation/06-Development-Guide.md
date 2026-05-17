# Civic-Link DPI - Development Guide

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Python 3.12+ (for local development)
- Git

### Quick Start

```bash
# 1. Clone repository
git clone <repository-url>
cd Traffic-pooling

# 2. Copy environment template and configure
cp .env.example .env
# Edit .env — set AUDIT_LOG_ENCRYPTION_KEY and JWT_SECRET_KEY
# Generate keys: python3 -c "import secrets; print(secrets.token_hex(32))"

# 3. Start containers
docker compose up -d postgres redis

# 4. Verify containers
docker compose ps

# 5. Run Alembic migrations
docker compose run --rm api alembic upgrade head

# 6. Seed database
docker compose exec api python app/seed_kphb.py

# 7. Run safety tests
docker compose exec api python app/safety_stress_test.py
```

---

## Project Structure

```
Traffic-pooling/
├── app/
│   ├── api/
│   │   ├── deps.py                   # Auth dependencies
│   │   └── v1/
│   │       ├── api.py                # API router configuration
│   │       └── endpoints/
│   │           ├── auth.py           # Registration, login, verify
│   │           ├── telemetry.py      # IMU data endpoint
│   │           ├── commutes.py       # Commute endpoints
│   │           ├── matches.py        # Match endpoints
│   │           └── civic_score.py    # Civic score endpoints
│   ├── core/
│   │   ├── config.py                 # Pydantic settings
│   │   ├── database.py               # AsyncSession factory
│   │   ├── security.py               # JWT & encryption
│   │   ├── exceptions.py             # Custom exceptions
│   │   └── redis.py                  # Async Redis client
│   ├── middleware/
│   │   ├── __init__.py
│   │   └── rate_limit.py             # Sliding window rate limiter
│   ├── models/
│   │   ├── base.py                   # BaseModel (id, timestamps)
│   │   ├── user.py                   # User model
│   │   ├── commute.py                # Commute & CommuteOffer models
│   │   ├── match.py                  # CommuteMatch model
│   │   ├── civic_score.py            # CivicScore & History
│   │   ├── audit.py                  # CommuteAuditLog & SafetyAlertLog
│   │   └── __init__.py               # Model exports
│   ├── schemas/                      # Pydantic request/response
│   ├── services/                     # Business logic
│   ├── seed_kphb.py                  # Database seeding
│   ├── safety_stress_test.py         # Safety validation
│   └── main.py                       # FastAPI entry point
├── migrations/
│   ├── env.py                        # Alembic async environment
│   └── versions/
│       └── e14fe2c5ae57_initial_schema.py
├── docker/
│   ├── postgres/
│   └── redis/
├── documentation/                    # Project docs (this folder)
├── tests/                            # Test suite
├── nginx.conf                        # Production Nginx config
├── docker-compose.yml                # Development orchestration
├── docker-compose.prod.yml           # Production orchestration
├── Dockerfile                        # Multi-stage build
├── alembic.ini                       # Alembic configuration
├── requirements.txt                  # Python dependencies
├── pyproject.toml                    # Project metadata
└── .env                              # Environment variables
```

---

## Development Workflow

### 1. Branch Strategy

```bash
# Main branches
main       - Production code
develop    - Integration branch
feature/*  - New features
bugfix/*   - Bug fixes
hotfix/*   - Emergency fixes
```

### 2. Making Changes

```bash
# Create feature branch
git checkout -b feature/my-new-feature

# Make changes
# ... edit files ...

# Test locally
docker compose exec api python app/safety_stress_test.py

# Commit
git add .
git commit -m "feat: add new feature description"

# Push
git push origin feature/my-new-feature
```

### 3. Code Review Checklist

- [ ] Code follows project structure
- [ ] All tests pass
- [ ] Safety logic is enforced at database level
- [ ] No hardcoded credentials or secrets
- [ ] Match events generate audit log entries
- [ ] Verification status checked for protected endpoints
- [ ] Documentation updated
- [ ] Git commit message follows convention

---

## Coding Standards

### Python Style

**Follow:** PEP 8 with these additions:

1. **Imports:** Grouped and sorted
```python
# Standard library
import asyncio
from datetime import datetime

# Third party
from fastapi import FastAPI
from sqlalchemy import select

# Local
from app.core.database import AsyncSessionLocal
from app.models.user import User
```

2. **Type Hints:** Required for all functions
```python
async def find_matches(
    offer: CommuteOffer,
    radius_meters: int = 500
) -> List[Tuple[Commute, float]]:
    """Find matching commutes for an offer."""
```

3. **Docstrings:** Google style
```python
def calculate_civic_score(
    current_score: float,
    swerve_count: int,
    speeding_penalty: float
) -> float:
    """Calculate new civic score using weighted rolling average.
    
    Formula: S_new = (S_old × 0.85) + (new_score × 0.15)
    
    Args:
        current_score: Existing civic score (0-100)
        swerve_count: Number of swerve events in 24h
        speeding_penalty: Speeding deduction amount
        
    Returns:
        New civic score between 0 and 100
        
    Raises:
        ValueError: If inputs are invalid
    """
```

4. **Async/Await:** Always use for I/O operations
```python
# Good
async def get_user(user_id: str) -> User:
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User).where(User.id == user_id))
        return result.scalar_one()

# Bad (blocking)
def get_user(user_id: str) -> User:
    with SessionLocal() as session:
        return session.query(User).get(user_id)
```

### SQLAlchemy 2.0 Standards

**Mapped Type Hints:**
```python
class Commute(BaseModel):
    __tablename__ = "commutes"
    
    driver_id: Mapped[str] = mapped_column(
        ForeignKey("users.id"),
        nullable=False
    )
    origin: Mapped[Geography] = mapped_column(
        Geography(geometry_type="POINT", srid=4326),
        nullable=False
    )
```

**Query Style:**
```python
# Modern 2.0 style
result = await session.execute(
    select(Commute)
    .where(Commute.status == "active")
    .options(selectinload(Commute.driver))
)

# Avoid legacy style
# result = session.query(Commute).filter(Commute.status == "active").all()
```

### Safety-Critical Code

**Hard-Reject Logic Must:**
1. Be at database level (raw SQL)
2. Be immutable (no configuration to disable)
3. Have double validation (SQL + application)
4. Include safety snapshots

**Example:**
```python
# Raw SQL safety clause
SAFETY_CLAUSE = """
AND (
    (:offer_women_only = FALSE OR u.gender = 'female')
    AND
    (c.is_women_only = FALSE OR :passenger_gender = 'female')
)
"""

# Application-level double-check
if commute.is_women_only and passenger.gender != Gender.FEMALE:
    raise CivicLinkSafetyException("Safety violation")
```

---

## Environment Setup

### Local Development (Without Docker)

```bash
# 1. Create virtual environment
python3.12 -m venv venv
source venv/bin/activate  # Linux/Mac
# or
venv\Scripts\activate     # Windows

# 2. Install dependencies
pip install -r requirements.txt

# 3. Copy environment template
cp .env.example .env

# 4. Generate required secrets
python3 -c "import secrets; print('AUDIT_LOG_ENCRYPTION_KEY=' + secrets.token_hex(32))"
python3 -c "import secrets; print('JWT_SECRET_KEY=' + secrets.token_hex(32))"

# 5. Edit .env — set AUDIT_LOG_ENCRYPTION_KEY, JWT_SECRET_KEY, and SECRET_KEY
#    These are REQUIRED — the application will refuse to start without them.

# 6. Run migrations
alembic upgrade head

# 7. Start API
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Required Environment Variables:**

| Variable | Required | Description |
|----------|----------|-------------|
| `SECRET_KEY` | Yes | Application secret key |
| `AUDIT_LOG_ENCRYPTION_KEY` | Yes | 32-byte hex key for AES-256-GCM audit encryption |
| `JWT_SECRET_KEY` | Yes | 32-byte hex key for JWT signing |
| `DATABASE_URL` | No | Defaults to `postgresql+asyncpg://civic:civic_secret@localhost:5432/civic_link` |
| `REDIS_URL` | No | Defaults to `redis://localhost:6379/0` |

### Using Docker (Recommended)

```bash
# 1. Copy and configure environment
cp .env.example .env
# Edit .env — set AUDIT_LOG_ENCRYPTION_KEY and JWT_SECRET_KEY

# 2. Start all services
docker compose up -d

# 3. View logs
docker compose logs -f api

# 4. Stop
docker compose down

# 5. Reset (remove volumes)
docker compose down -v
docker compose up -d
```

---

## Database Migrations

### Overview

Civic-Link uses **Alembic** for database migrations. The `create_all()` approach is gated to development only — production relies exclusively on Alembic.

**Initial migration:** `e14fe2c5ae57_initial_schema.py` — creates all 8 tables and 9 enum types.

### Create Migration

```bash
# Auto-generate from model changes
docker compose run --rm api alembic revision --autogenerate -m "add new field"

# Manual migration
docker compose run --rm api alembic revision -m "manual change"
```

### Apply Migrations

```bash
# Upgrade to latest
docker compose run --rm api alembic upgrade head

# Upgrade specific
docker compose run --rm api alembic upgrade +1

# Downgrade
docker compose run --rm api alembic downgrade -1

# Round-trip test
docker compose run --rm api alembic downgrade -1 && docker compose run --rm api alembic upgrade head
```

### Migration Environment

**File:** `migrations/env.py`

- Async engine via `async_engine_from_config`
- Reads `DATABASE_URL` from environment (overrides `alembic.ini`)
- Filters out PostGIS extension tables (tiger, topology, spatial_ref_sys)
- Supports both online and offline migration modes

---

## Testing

### Run Tests

```bash
# All tests
pytest

# Specific test
pytest tests/test_match_service.py::test_women_only_safety

# With coverage
pytest --cov=app --cov-report=html
```

### Test Structure

```
tests/
├── conftest.py              # Shared fixtures
├── unit/
│   ├── test_models.py
│   ├── test_schemas.py
│   └── test_services.py
├── integration/
│   ├── test_api.py
│   ├── test_database.py
│   └── test_matching.py
└── e2e/
    └── test_full_journey.py
```

### Writing Tests

```python
# tests/unit/test_match_service.py
import pytest
from app.services.match_service import MatchingService

@pytest.mark.asyncio
async def test_women_only_returns_female_drivers_only():
    """Critical safety test: Women-Only must return zero male drivers."""
    # Arrange
    women_only_offer = create_test_offer(is_women_only=True)
    
    # Act
    matches = await MatchingService(db_session).find_matching_commutes(
        women_only_offer
    )
    
    # Assert
    for commute, _ in matches:
        driver = await get_driver(commute.driver_id)
        assert driver.gender == "female", \
            "SAFETY VIOLATION: Male driver matched for Women-Only request"
```

---

## Debugging

### Database Queries

```bash
# Enable SQL logging in app/core/database.py:
echo "True"  # Set SQLALCHEMY_ECHO=True in .env

# View live queries
docker compose logs -f postgres | grep "SELECT\|INSERT\|UPDATE"
```

### API Requests

```bash
# Use curl with verbose
curl -v http://localhost:8000/health

# Or use httpie
http http://localhost:8000/health
```

### Container Issues

```bash
# Check logs
docker compose logs postgres | tail -50
docker compose logs api | tail -50

# Shell into container
docker compose exec postgres bash
docker compose exec api bash

# Check resource usage
docker stats
```

### Common Issues

**Issue:** `pydantic_core._pydantic_core.ValidationError: field required` on startup
**Fix:** Set `SECRET_KEY`, `AUDIT_LOG_ENCRYPTION_KEY`, and `JWT_SECRET_KEY` in `.env`. These are now required with no defaults.

**Issue:** `ModuleNotFoundError: No module named 'geoalchemy2'`
**Fix:** Run scripts inside Docker container where dependencies are installed

**Issue:** `Permission denied` on init.sql
**Fix:** `chmod 644 init.sql`

**Issue:** Database connection refused
**Fix:** Wait for postgres to be healthy: `docker compose up -d postgres && sleep 5`

**Issue:** `relation "xxx" already exists` during `alembic upgrade head`
**Fix:** The database was created by `create_all()`. Drop tables first: `docker compose down -v && docker compose up -d postgres`, then run `alembic upgrade head`.

**Issue:** Rate limiting not working
**Fix:** Ensure Redis container is running. Check logs: `docker compose logs api | grep -i rate`. Rate limiting gracefully degrades if Redis is unavailable.

**Issue:** API starts but Redis health check fails
**Fix:** This is expected behavior — the API continues without Redis. Check Redis logs: `docker compose logs redis`.

---

## Git Workflow

### Commit Message Convention

```
feat: add telemetry endpoint
fix: correct safety logic in matching
refactor: simplify database queries
docs: update API reference
test: add safety stress test
deps: update sqlalchemy to 2.0
```

### Branch Naming

```
feature/telemetry-processing
feature/women-only-filtering
bugfix/match-count-update
hotfix/critical-safety-bypass
```

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Safety Checklist
- [ ] Hard-reject logic unchanged or improved
- [ ] Safety tests pass
- [ ] No new safety bypasses introduced

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Safety stress test passes (0 male drivers for Women-Only)
```

---

## Redis Usage

### Client API

```python
from app.core.redis import (
    get_redis_client,
    set_with_ttl,
    get,
    delete,
    exists,
    increment,
)

# Get raw Redis client
redis = get_redis_client()
if redis:
    await redis.set("key", "value")

# Utility functions (graceful degradation)
await set_with_ttl("session:abc", "data", ttl_seconds=3600)
value = await get("session:abc")
await delete("session:abc")
key_exists = await exists("session:abc")
count = await increment("ratelimit:user:123", ttl_seconds=60)
```

### FastAPI Dependency

```python
from fastapi import Depends
from app.core.redis import get_redis

@app.get("/cached-data")
async def get_cached_data(redis = Depends(get_redis)):
    if redis is None:
        return {"error": "Redis unavailable"}
    data = await redis.get("my_key")
    return {"data": data}
```

### Graceful Degradation

All Redis operations return `None`/`False` when Redis is unavailable — they never raise exceptions. The API continues to function without caching or rate limiting.

---

## Rate Limiting

### Configuration

Rate limits are defined in `app/middleware/rate_limit.py`:

| Endpoint | Limit | Window | Key |
|----------|-------|--------|-----|
| `/api/v1/auth/login` | 10 req/min | 60s | IP address |
| `/api/v1/auth/register` | 5 req/min | 60s | IP address |
| `/api/v1/civic-score/ingest` | 30 req/min | 60s | User ID |
| `/api/v1/*` (other) | 120 req/min | 60s | User ID |

### Response on Limit Exceeded

```json
{
  "error": "RATE_LIMIT_EXCEEDED",
  "retry_after_seconds": 45
}
```

HTTP status: `429 Too Many Requests`
Header: `Retry-After: 45`

### Exempt Paths

The following paths are never rate limited:
- `/health`
- `/docs`
- `/redoc`
- `/openapi.json`
- `/`

---

## Exception Handling

### Structured Error Response

All exceptions return a consistent JSON format:

```json
{
  "error": "User not found",
  "code": "USER_NOT_FOUND",
  "request_id": "uuid-4-uuid-4-uuid",
  "detail": "optional detail string"
}
```

### Exception → Status Code Mapping

| Exception | Status Code |
|-----------|-------------|
| `CivicLinkSafetyException` | 400 |
| `ValidationError` | 422 |
| `AuthenticationError` | 401 |
| `AuthorizationError` | 403 |
| `UserNotFoundError` | 404 |
| `CommuteNotFoundError` | 404 |
| `MatchNotFoundError` | 404 |
| `GeospatialConflictError` | 409 |
| `RateLimitError` | 429 |
| `AuditLogError` | 500 |
| `Exception` (fallback) | 500 |

The generic `Exception` handler logs the full traceback via `logger.exception()` but never exposes internal details to the client.

---

## Production Deployment

### Prerequisites

- `.env.production` file with all required secrets
- TLS certificates (optional, for HTTPS)
- Domain name pointing to server IP

### Deploy

```bash
# 1. Prepare environment
cp .env.example .env.production
# Edit .env.production with production values

# 2. (Optional) Place TLS certificates
mkdir -p ssl
cp fullchain.pem ssl/
cp privkey.pem ssl/
# Uncomment TLS section in nginx.conf

# 3. Deploy
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# 4. Verify
docker compose -f docker-compose.prod.yml ps
curl https://your-domain/health
```

### Service Architecture (Production)

```
Internet → Nginx (80/443) → API (internal:8000)
                                    ↓
                              PostgreSQL (internal)
                              Redis (internal)
```

- PostgreSQL and Redis have **no exposed ports** — accessible only by API
- Nginx handles TLS, gzip compression, security headers, and rate limiting
- Migrations run automatically before API starts via the `migrations` service

### Resource Limits

| Service | Memory | CPU |
|---------|--------|-----|
| API | 512 MB | 0.5 |
| PostgreSQL | 1 GB | 1.0 |
| Redis | 256 MB | 0.25 |
| Nginx | 128 MB | 0.25 |

### Updating

```bash
# 1. Pull latest code
git pull origin main

# 2. Rebuild and redeploy
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build
```

---

## Release Process

### Version Numbering

Follow Semantic Versioning: `MAJOR.MINOR.PATCH`

- **MAJOR:** Breaking changes (safety logic changes)
- **MINOR:** New features (new endpoints)
- **PATCH:** Bug fixes

### Release Checklist

1. [ ] All tests pass
2. [ ] Safety stress test passes
3. [ ] Alembic migration round-trip verified
4. [ ] Documentation updated
5. [ ] CHANGELOG.md updated
6. [ ] Version bumped in `pyproject.toml`
7. [ ] Git tag created: `git tag -a v1.0.0 -m "Release v1.0.0"`
8. [ ] Tag pushed: `git push origin v1.0.0`

---

*Document Version: 2.0*  
*Last Updated: May 16, 2026*
