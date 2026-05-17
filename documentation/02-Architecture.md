# Civic-Link DPI - System Architecture

## Architectural Overview

Civic-Link follows a **Layered Architecture** pattern with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    API Layer (FastAPI)                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│  │    Auth     │ │   Commute   │ │      Match / Score      │ │
│  │  Endpoints  │ │  Endpoints  │ │       Endpoints         │ │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │           Exception Handlers (11 types)                 │ │
│  └─────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │         Rate Limiting Middleware (sliding window)       │ │
│  └─────────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                  Service Layer                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│  │  Telemetry  │ │   Commute   │ │    MatchingService      │ │
│  │   Service   │ │   Service   │ │  (Hard-Reject Logic)    │ │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│  │ CivicScore  │ │   Audit     │ │      User Service       │ │
│  │  Service    │ │  Service    │ │                         │ │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                   Data Access Layer                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│  │   Models    │ │   Schemas   │ │   Database Session      │ │
│  │ (SQLAlchemy)│ │  (Pydantic) │ │     (AsyncSession)      │ │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                  Infrastructure Layer                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│  │  PostgreSQL │ │    Redis    │ │   Nginx (production)    │ │
│  │  + PostGIS  │ │  (asyncio)  │ │   Reverse Proxy         │ │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Layer Responsibilities

### 1. API Layer (FastAPI)

**Location:** `app/api/v1/endpoints/`, `app/main.py`

**Responsibilities:**
- HTTP request/response handling
- Input validation via Pydantic schemas
- Authentication/Authorization (JWT tokens)
- Background task orchestration (FastAPI BackgroundTasks)
- Global exception handling (11 custom exception types)
- Rate limiting middleware (sliding window via Redis)
- CORS configuration

**Key Endpoints:**
- `POST /api/v1/auth/register` — Zero-Liability registration
- `POST /api/v1/auth/login/access-token` — JWT login
- `POST /api/v1/auth/verify` — Account verification (placeholder)
- `GET /api/v1/auth/me` — Current user profile
- `POST /api/v1/telemetry` — Submit 50Hz IMU data
- `GET /api/v1/commutes` — Search available commutes
- `POST /api/v1/matches` — Create driver-passenger matches
- `POST /api/v1/civic-score/ingest` — Telemetry ingestion
- `GET /api/v1/civic-score/me` — Current civic score
- `GET /health` — Health check

**Lifespan Management:**
```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()           # Database connection
    # create_all() only in development
    await init_redis()        # Redis connection pool
    yield
    await close_redis()
    await close_db()
```

**Exception Handlers:**
All exceptions return structured JSON: `{error, code, request_id, detail?}`. The generic fallback handler logs full tracebacks but never exposes internals to clients.

---

### 2. Service Layer

**Location:** `app/services/`

**Responsibilities:**
- Business logic implementation
- Transaction management
- Cross-cutting concerns (logging, metrics)
- External service integration

**Key Services:**

#### MatchingService (`match_service.py`)
- **Hard-Reject Safety Logic:** Database-level gender filtering
- **Geospatial Matching:** ST_DWithin for 500m radius
- **Time Window Filtering:** ±30 minutes departure flexibility

#### TelemetryService (`telemetry_service.py`)
- **Swerve Detection:** abs(gyro_z) > 1.5 rad/s
- **60s Cooldown:** Debounce to prevent duplicate events
- **Civic Scoring:** Weighted rolling average formula

#### CommuteService (`commute_service.py`)
- **CRUD Operations:** Create, read, update commutes
- **Redis Caching:** 15-minute TTL for active offers
- **Expiration Management:** Auto-expire old offers

---

### 3. Data Access Layer

**Location:** `app/models/`, `app/schemas/`, `app/core/database.py`

**Responsibilities:**
- Database model definitions
- Schema validation
- Session management
- Migration handling

#### Models (SQLAlchemy 2.0)

**Declarative Mapping Style:**
```python
class Commute(BaseModel):
    __tablename__ = "commutes"
    
    driver_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    origin: Mapped[Geography] = mapped_column(
        Geography(geometry_type="POINT", srid=4326)
    )
```

**Key Models:**
- `User` - Commuter profiles with gender, verification status
- `Commute` - Driver's ride offer with origin/destination
- `CommuteOffer` - Passenger's ride request
- `CommuteMatch` - Driver-passenger pairing with safety snapshots
- `CivicScore` - Driver behavior scoring
- `CommuteAuditLog` - Encrypted audit trail

#### Schemas (Pydantic)

**Input/Output Validation:**
```python
class TelemetryBatchRequest(BaseModel):
    user_id: str
    readings: List[IMUReadingInput]
    match_id: Optional[str]
```

---

### 4. Infrastructure Layer

#### PostgreSQL + PostGIS

**Purpose:** Primary data store with geospatial capabilities

**Features:**
- **Geography Type:** Earth-surface calculations (meters)
- **SRID 4326:** WGS 84 standard GPS coordinates
- **GIST Indexes:** Optimized for ST_DWithin queries
- **Async Support:** Via asyncpg driver

**Connection:**
```
postgresql+asyncpg://civic:civic_secret@postgres:5432/civic_link
```

#### Redis

**Purpose:** Caching, rate limiting, and session management

**Implementation:** `app/core/redis.py` — async client via `redis.asyncio`

**Features:**
- Lifespan-managed connection pool
- Utility functions: `set_with_ttl()`, `get()`, `delete()`, `exists()`, `increment()`
- Graceful degradation: returns `None`/`False` when unavailable
- Health check key on startup (`redis:health` with 60s TTL)

**Use Cases:**
- Rate limiting (sliding window via sorted sets)
- Active commute offers (15-minute TTL)
- User session tokens
- Swerve cooldown tracking

**Connection:**
```
redis://redis:6379/0
```

#### Nginx (Production)

**Purpose:** Reverse proxy, TLS termination, security headers

**Features:**
- Gzip compression for JSON responses
- Security headers: X-Frame-Options, X-Content-Type-Options, Referrer-Policy
- Nginx-level rate limiting (complements application-level)
- `/health` endpoint bypasses rate limiting
- TLS configuration (commented template)

**Configuration:** `nginx.conf`

#### Docker

**Development Services:**
- `postgres` — PostGIS 16-3.4 database
- `redis` — Redis 7-alpine cache
- `api` — FastAPI application (hot reload)
- `migrations` — Alembic database migrations (profile: migrations)

**Production Services (`docker-compose.prod.yml`):**
- `postgres` — No exposed ports, volume persistence
- `redis` — appendonly, 128mb maxmemory, allkeys-lru
- `api` — 4 workers, no hot reload, resource limits
- `nginx` — Ports 80/443, security headers
- `migrations` — Runs before API (condition: service_completed_successfully)

---

## Data Flow Diagrams

### 1. Women-Only Ride Matching (Safety-Critical)

```
Passenger App                    Backend                           Database
     │                              │                                  │
     │  POST /api/v1/commutes       │                                  │
     │  is_women_only=true          │                                  │
     ├──────────────────────────────>│                                  │
     │                              │                                  │
     │                              │  MatchingService.find_matching() │
     │                              ├─────────────────────────────────>│
     │                              │                                  │
     │                              │  Raw SQL with Safety Clause:     │
     │                              │  AND (                           │
     │                              │    :women_only=false OR          │
     │                              │    driver.gender='female'        │
     │                              │  )                               │
     │                              │                                  │
     │                              │<─────────────────────────────────┤
     │                              │  Returns: Only Female Drivers   │
     │                              │                                  │
     │<──────────────────────────────┤                                  │
     │  Response: Matches (0 males)  │                                  │
     │                              │                                  │
```

### 2. Telemetry Processing (50Hz IMU)

```
Mobile Device                  FastAPI                         BackgroundTask
     │                            │                                   │
     │  POST /api/v1/telemetry    │                                   │
     │  50Hz IMU batch          │                                   │
     ├───────────────────────────>│                                   │
     │                            │                                   │
     │                            │  202 ACCEPTED (immediate)         │
     │<───────────────────────────┤                                   │
     │                            │                                   │
     │                            │  add_task(process_telemetry)      │
     │                            ├──────────────────────────────────>│
     │                            │                                   │
     │                            │                                   │  Swerve Detection
     │                            │                                   │  - gyro_z > 1.5 rad/s
     │                            │                                   │  - 60s cooldown check
     │                            │                                   │
     │                            │                                   │  Update CivicScore
     │                            │                                   │  - Formula: 0.85*old + 0.15*new
     │                            │<──────────────────────────────────┤
     │                            │                                   │
```

---

## Security Architecture

### 1. Hard-Reject Safety Logic

**Location:** Database-level SQL query

**Implementation:**
```sql
SELECT c.*, u.gender as driver_gender
FROM commutes c
JOIN users u ON c.driver_id = u.id
WHERE 
    -- ... other filters ...
    -- CRITICAL: Hard-reject safety clause
    AND (
        (:offer_women_only = FALSE OR u.gender = 'female')
        AND
        (c.is_women_only = FALSE OR :passenger_gender = 'female')
    )
```

**Why Database-Level?**
- Prevents application-level bypass
- Immutable rule, cannot be disabled
- Works regardless of API changes

### 2. Double Validation

**First Layer:** SQL filter (above)
**Second Layer:** Application check in `create_match()`

```python
if commute.is_women_only and passenger.gender != Gender.FEMALE:
    raise CivicLinkSafetyException(
        "Women-only commute cannot match non-female passenger"
    )
```

### 3. Safety Snapshots

Every `CommuteMatch` stores:
- `commute_was_women_only` - State at match time
- `offer_was_women_only` - Request state at match time

**Purpose:** Audit trail even if parent records change

---

## Scalability Considerations

### 1. Database

**Read Replicas:** For matching queries (future)
**Sharding:** By geographic region (future)
**Connection Pooling:** asyncpg with 20+ connections

### 2. Caching

**Redis Cluster:** For distributed caching (production)
**Cache Invalidation:** Event-driven updates

### 3. Background Processing

**Celery:** Replace FastAPI BackgroundTasks for heavy loads
**Queue:** Redis-backed task queue

---

## Monitoring & Observability

### 1. Application Metrics

- Request latency (p50, p95, p99)
- Match success rate
- Safety violations (should always be 0)
- Telemetry processing rate

### 2. Database Metrics

- Query performance (ST_DWithin timing)
- Connection pool utilization
- Replication lag (if enabled)

### 3. Business Metrics

- Active commutes by hour
- Match completion rate
- Civic score distribution
- Women-only ride utilization

---

*Document Version: 2.0*  
*Last Updated: May 16, 2026*
