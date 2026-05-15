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

# 2. Start containers
docker compose up -d postgres redis

# 3. Verify containers
docker compose ps

# 4. Seed database
docker compose exec api python app/seed_kphb.py

# 5. Run safety tests
docker compose exec api python app/safety_stress_test.py
```

---

## Project Structure

```
Traffic-pooling/
├── app/
│   ├── api/
│   │   └── v1/
│   │       ├── api.py              # API router configuration
│   │       └── endpoints/
│   │           ├── telemetry.py    # IMU data endpoint
│   │           ├── commutes.py     # Commute endpoints
│   │           └── matches.py      # Match endpoints
│   ├── core/
│   │   ├── config.py               # Pydantic settings
│   │   ├── database.py             # AsyncSession factory
│   │   ├── security.py             # JWT & encryption
│   │   └── exceptions.py           # Custom exceptions
│   ├── models/
│   │   ├── user.py                 # User model
│   │   ├── commute.py              # Commute & CommuteOffer models
│   │   └── match.py                # CommuteMatch model
│   ├── schemas/
│   │   ├── telemetry.py            # Pydantic schemas
│   │   ├── commute.py              # Request/response schemas
│   │   └── match.py                # Match schemas
│   ├── services/
│   │   ├── match_service.py        # Matching logic
│   │   ├── telemetry_service.py    # IMU processing
│   │   └── commute_service.py      # Commute CRUD
│   ├── seed_kphb.py                # Database seeding
│   ├── safety_stress_test.py       # Safety validation
│   └── main.py                     # FastAPI entry point
├── docker/
│   ├── postgres/
│   └── redis/
├── documentation/                  # Project docs (this folder)
├── tests/                          # Test suite
├── docker-compose.yml              # Container orchestration
├── requirements.txt                # Python dependencies
├── pyproject.toml                  # Project metadata
└── .env                            # Environment variables
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
- [ ] No hardcoded credentials
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

# 3. Set environment variables
export DATABASE_URL="postgresql+asyncpg://civic:civic_secret@localhost:5432/civic_link"
export REDIS_URL="redis://localhost:6379/0"
export AUDIT_LOG_ENCRYPTION_KEY="your-secret-key"

# 4. Run migrations
alembic upgrade head

# 5. Start API
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Using Docker (Recommended)

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f api

# Stop
docker compose down

# Reset (remove volumes)
docker compose down -v
docker compose up -d
```

---

## Database Migrations

### Create Migration

```bash
# Auto-generate from model changes
docker compose run --rm migrations alembic revision --autogenerate -m "add new field"

# Manual migration
docker compose run --rm migrations alembic revision -m "manual change"
```

### Apply Migrations

```bash
# Upgrade to latest
docker compose run --rm migrations alembic upgrade head

# Upgrade specific
docker compose run --rm migrations alembic upgrade +1

# Downgrade
docker compose run --rm migrations alembic downgrade -1
```

### Migration File Structure

```python
"""add women_only flag

Revision ID: 20240415_001
Revises: previous_revision
Create Date: 2026-04-15 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers
revision = '20240415_001'
down_revision = 'previous_revision'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Add column
    op.add_column(
        'commutes',
        sa.Column('is_women_only', sa.Boolean(), nullable=False, server_default='false')
    )
    
    # Add index
    op.create_index(
        'idx_commutes_is_women_only',
        'commutes',
        ['is_women_only']
    )

def downgrade() -> None:
    op.drop_index('idx_commutes_is_women_only', table_name='commutes')
    op.drop_column('commutes', 'is_women_only')
```

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

**Issue:** `ModuleNotFoundError: No module named 'geoalchemy2'`
**Fix:** Run scripts inside Docker container where dependencies are installed

**Issue:** `Permission denied` on init.sql
**Fix:** `chmod 644 init.sql`

**Issue:** Database connection refused
**Fix:** Wait for postgres to be healthy: `docker compose up -d postgres && sleep 5`

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

## Release Process

### Version Numbering

Follow Semantic Versioning: `MAJOR.MINOR.PATCH`

- **MAJOR:** Breaking changes (safety logic changes)
- **MINOR:** New features (new endpoints)
- **PATCH:** Bug fixes

### Release Checklist

1. [ ] All tests pass
2. [ ] Safety stress test passes
3. [ ] Documentation updated
4. [ ] CHANGELOG.md updated
5. [ ] Version bumped in `pyproject.toml`
6. [ ] Git tag created: `git tag -a v1.0.0 -m "Release v1.0.0"`
7. [ ] Tag pushed: `git push origin v1.0.0`

---

*Document Version: 1.0*  
*Last Updated: April 15, 2026*
