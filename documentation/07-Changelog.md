# Civic-Link DPI - Changelog

All notable changes to the Civic-Link project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Planned
- Flutter UI Shell integration
- Real-time WebSocket updates
- Production deployment pipeline
- Load testing and performance optimization

---

## [0.1.0] - 2026-04-15

### Backend Core & Safety Verified

#### Added
- **Database Layer**
  - PostgreSQL 16 with PostGIS 3.4 extension
  - SQLAlchemy 2.0 async ORM with Mapped[] types
  - Geography type (SRID 4326) for accurate geospatial calculations
  - GIST indexes on origin/destination for ST_DWithin queries
  - Alembic migration system configured

- **Models**
  - `User` model with gender enum (male, female, undisclosed)
  - `Commute` model with origin/destination Geography(POINT, 4326)
  - `CommuteOffer` model for passenger requests
  - `CommuteMatch` model with safety snapshots
  - `CivicScore` model for driver behavior tracking
  - `CommuteAuditLog` model for encrypted audit trail
  - `SwerveEvent` model for telemetry data

- **Services**
  - `MatchingService` with hard-reject safety logic at database level
  - `TelemetryService` for 50Hz IMU processing
  - Civic scoring formula: S_new = (S_old × 0.85) + (new × 0.15)
  - Lane-cutting detection: abs(gyro_z) > 1.5 rad/s
  - 60-second cooldown for swerve events

- **API Endpoints**
  - `POST /api/v1/telemetry` - IMU data submission (zero-lag with BackgroundTasks)
  - `GET /api/v1/commutes` - List available commutes
  - `POST /api/v1/commutes` - Create commute offer
  - `POST /api/v1/commute-offers` - Create passenger request
  - `GET /api/v1/commute-offers/{id}/matches` - Find matching commutes
  - `POST /api/v1/matches` - Create driver-passenger match
  - `GET /api/v1/civic-score/{user_id}` - Get civic score
  - `GET /health` - Health check

- **Safety Features**
  - Hard-reject SQL clause: `(:women_only=false OR driver.gender='female')`
  - Double validation: SQL filter + application-level check
  - Safety snapshots: `commute_was_women_only`, `offer_was_women_only`
  - Women-only matching returns zero male drivers (enforced at DB level)

- **Testing Scripts**
  - `app/seed_kphb.py` - Seeds 50 users (25F/25M), 30 commutes
  - `app/safety_stress_test.py` - 10 Women-Only request simulations
  - Geospatial test data: KPHB Phase 3 → Mindspace/HITEC City
  - Safety validation with verification_results.txt output

- **Docker Setup**
  - Multi-service docker-compose.yml (postgres, redis, api, migrations)
  - PostgreSQL 16-3.4 with custom postgresql.conf
  - Redis 7-alpine for caching
  - Volume mounts for persistent data

- **Configuration**
  - `.env` support for environment variables
  - Pydantic Settings for type-safe config
  - PostGIS-specific optimizations in postgresql.conf

- **Documentation**
  - `01-Project-Overview.md` - Mission, features, roadmap
  - `02-Architecture.md` - System design and data flows
  - `03-Database-Schema.md` - ER diagrams and table specs
  - `04-API-Reference.md` - Endpoint documentation
  - `05-Testing-Guide.md` - Test procedures and scripts
  - `06-Development-Guide.md` - Setup and coding standards
  - `07-Changelog.md` - This file

#### Fixed
- PostgreSQL init errors: Removed invalid SELECT statement from init.sql
- PostGIS configuration: Fixed SQL-style comments to use # in postgresql.conf
- Permission issues: Set init.sql permissions to 644 for container access

#### Security
- Database-level gender filtering (immutable rule)
- 500m geospatial radius for matching
- Safety snapshots preserved at match time
- AES-256-GCM encryption ready for audit logs

---

## Development History

### April 15, 2026
- Created comprehensive documentation folder
- Documented database schema with ER diagrams
- Documented all API endpoints
- Created testing guide with safety procedures
- Created development guide with coding standards

### April 12, 2026
- Completed Task 1: Seed Injection (50 users, 30 commutes)
- Completed Task 2: Safety Stress Test (10 Women-Only requests)
- Verified Hard-Reject Safety Logic (0 male drivers matched)
- Updated backlog.md marking Tasks 1 & 2 complete
- Created work_done.md summary

### April 11, 2026
- Fixed Docker container initialization issues
- Resolved PostgreSQL permission denied error
- Corrected postgresql.conf comment syntax
- Successfully started postgres and redis containers
- Attempted to run seed scripts (dependency issues identified)

### April 10, 2026
- Created `app/seed_kphb.py` with 20 users (10F/10M)
- Created `app/safety_stress_test.py` for validation
- Implemented `MatchingService` with raw SQL safety clause
- Implemented `TelemetryService` with 50Hz processing
- Created FastAPI telemetry endpoint with BackgroundTasks
- Set up Alembic migration framework
- Created all SQLAlchemy 2.0 models with Geography types

### April 9, 2026
- Project initialization
- Created project structure (app/, docker/, tests/)
- Set up docker-compose.yml with postgres, redis, api services
- Created initial models with PostGIS support
- Configured FastAPI application

---

## Technical Decisions

### Why Geography instead of Geometry?
**Decision:** Use PostGIS Geography type for all coordinates
**Rationale:** 
- Automatic meter-based calculations
- No degree-to-meter conversion needed
- Accurate for 10km KPHB to HITEC corridor
- ST_DWithin returns true for meters, not degrees

### Why Raw SQL for Safety Logic?
**Decision:** Embed hard-reject clause in raw SQL text()
**Rationale:**
- Immutable at database level
- Cannot be bypassed by application code
- Works regardless of API changes
- Double validation still applied in Python

### Why 500m Radius?
**Decision:** Set default search radius to 500 meters
**Rationale:**
- Optimal for dense urban areas like KPHB
- Walking distance < 5 minutes
- Reduces false positives in matching
- Configurable per request

### Why 60s Cooldown for Swerves?
**Decision:** 60-second debounce for lane-cutting events
**Rationale:**
- Prevents duplicate counting in traffic
- Single aggressive maneuver = one event
- Multiple swerves in sequence = one event
- Balances sensitivity with practicality

### Why Async Everything?
**Decision:** Use async/await for all I/O operations
**Rationale:**
- PostgreSQL via asyncpg
- FastAPI async endpoints
- BackgroundTasks for telemetry
- Scalable to high concurrent loads

---

## Known Issues

### Current
- Scripts must run inside Docker container (local Python lacks dependencies)
- Verification results written inside container (need volume mount for local access)

### Resolved
- ✅ PostgreSQL container startup failures
- ✅ Permission denied on init.sql
- ✅ PostGIS configuration errors

### Future Improvements
- Add GitHub Actions CI/CD pipeline
- Implement WebSocket for real-time updates
- Add comprehensive unit test suite
- Create load testing with Locust
- Implement JWT authentication
- Add rate limiting

---

## Migration Notes

### From 0.0.x to 0.1.0
No migrations needed (initial release).

### Database Setup
```bash
# Fresh install
docker compose up -d postgres
docker compose run --rm migrations alembic upgrade head
docker compose exec api python app/seed_kphb.py
```

---

## Contributors

- **Development Team:** Civic-Link DPI Contributors
- **Safety Review:** Exam Mode Validation
- **Documentation:** Comprehensive technical docs created

---

## License

Digital Public Infrastructure - Open Source

---

*This changelog documents the journey of building a safety-first carpooling platform for the Cyberabad IT Corridor.*

*Last Updated: April 15, 2026*
