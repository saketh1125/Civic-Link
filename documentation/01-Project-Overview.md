# Civic-Link DPI - Project Overview

**Project Name:** Civic-Link  
**Type:** Digital Public Infrastructure (DPI)  
**Domain:** Carpooling/Ridesharing  
**Region:** Cyberabad IT Corridor, Hyderabad, India  
**Status:** Backend Core & Safety Verified  

---

## Mission Statement

Civic-Link is a **non-commercial, safety-hardened** carpooling Digital Public Infrastructure designed for the Cyberabad IT Corridor. Unlike commercial ride-sharing apps, Civic-Link prioritizes:

1. **Commuter Safety** - Hard-reject safety logic at the database level
2. **Privacy Protection** - Delete-by-default anonymization after 24 hours
3. **Transparency** - Civic scoring system for driver behavior
4. **Inclusivity** - Women-only ride options with strict enforcement

---

## Key Features

### 1. Safety-First Matching
- **Hard-Reject Logic:** Women-only requests can NEVER match with male drivers
- **Database-Level Enforcement:** Safety logic is in SQL, not application code
- **Double Validation:** Both SQL filter AND application-level checks

### 2. Geospatial Precision
- **PostGIS Geography Type:** Uses earth-surface calculations (meters, not degrees)
- **SRID 4326:** Standard WGS 84 GPS coordinate system
- **500m Search Radius:** Optimal for KPHB to HITEC City corridor

### 3. Civic Score System
- **Telemetry-Based:** 50Hz IMU (gyroscope/accelerometer) data from mobile devices
- **Lane-Cutting Detection:** gyro_z > 1.5 rad/s triggers swerve events
- **Scoring Formula:** Weighted rolling average with 60-second debounce

### 4. Privacy by Design
- **GDPR/RTI Compliant:** Anonymize coordinates 24 hours after ride completion
- **Encrypted Audit Logs:** All matches logged with encryption
- **Hashed Emails:** Corporate emails stored hashed, never plaintext

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Backend** | FastAPI (Python 3.12+) | Async API framework |
| **Database** | PostgreSQL 16 + PostGIS 3.4 | Geospatial data storage |
| **Cache** | Redis 7 | Session & commute offer caching |
| **ORM** | SQLAlchemy 2.0 | Async database abstraction |
| **Validation** | Pydantic 2.x | Input/output validation |
| **Async** | asyncpg | Async PostgreSQL driver |
| **Geospatial** | GeoAlchemy2 + Shapely | PostGIS integration |
| **Mobile** | Flutter 3.11+ / Dart | Cross-platform mobile app |
| **State Mgmt** | Riverpod 3.x | Flutter state management |
| **Migrations** | Alembic (async) | Database schema versioning |
| **Container** | Docker Compose | Development & production orchestration |

---

## Project Structure

```
Traffic-pooling/
├── app/
│   ├── api/v1/endpoints/    # API route handlers (auth, commutes, matches, civic_score, telemetry)
│   ├── core/                 # Config, database, security, exceptions, redis
│   ├── models/              # SQLAlchemy ORM models (8 tables)
│   ├── schemas/             # Pydantic request/response schemas
│   └── services/            # Business logic (match, commute, civic_score, user, audit, telemetry)
├── civic_link/              # Flutter mobile app
│   └── lib/
│       ├── providers/       # Riverpod state management (auth, civic_score, commute, match, profile, theme)
│       ├── services/        # AuthService, TelemetryService (50Hz IMU isolate)
│       ├── ui/screens/      # 12 screens (splash, login, register, dashboard, commute CRUD, match CRUD, profile, settings)
│       ├── ui/widgets/      # Shared widgets (AuthGuard, CivicScoreBadge, CommuteCard, MatchCard, ErrorBanner, LoadingOverlay)
│       └── utils/           # PrivacyCrypto (SHA-256 email hashing)
├── docker/                  # Docker configurations (nginx, redis)
├── documentation/           # Project documentation (8 guides)
├── migrations/              # Alembic async migrations (2 versions)
├── tests/                   # Pytest suite (4 test files, 75+ tests)
├── docker-compose.yml       # Development container orchestration
├── docker-compose.prod.yml  # Production hardened orchestration
├── requirements.txt         # Python dependencies
└── .env                     # Environment variables (not committed)
```

---

## Target Users

### Primary Users
- **IT Professionals:** Commuting between KPHB Phase 3 and Mindspace/HITEC City
- **Women Commuters:** Priority safety features for women-only rides
- **Environmentally Conscious:** Reducing carbon footprint through carpooling

### Corporate Integration
- @company.com email validation
- Corporate verification system
- Bulk employee onboarding

---

## Compliance & Legal

### Safety Compliance
- Women-only ride filtering at database level (immutable rule)
- Real-time telemetry monitoring for dangerous driving
- Emergency alert system integration (planned)

### Data Privacy
- **Anonymization:** 24-hour data retention for location data
- **Encryption:** AES-256-GCM for audit logs
- **Access Control:** Role-based permissions

### RTI (Right to Information)
- Transparent civic scoring methodology
- Public API for non-sensitive data
- Audit trail for all matches

---

## Roadmap

### Phase 1: Backend Core ✅ COMPLETED
- [x] SQLAlchemy 2.0 models with PostGIS (8 tables)
- [x] Hard-reject safety logic (SQL-level gender filtering)
- [x] Telemetry processing service (50Hz IMU, swerve detection)
- [x] Docker containerization (dev + production hardened)
- [x] Database seeding & safety testing (75+ tests)
- [x] All CRUD endpoints (auth, commutes, matches, civic_score, telemetry)
- [x] Encrypted audit logging (AES-256-GCM)
- [x] JWT auth with refresh tokens

### Phase 2: Flutter UI ✅ COMPLETED
- [x] Splash screen with session restore
- [x] Login + Registration with Zero-Liability email hashing
- [x] Dashboard with real-time Civic Score + fl_chart history
- [x] Commute CRUD (create, search, detail, my commutes, cancel)
- [x] Match lifecycle (request, confirm, detail, rate)
- [x] Profile screen with score badge + edit form
- [x] Settings screen with theme toggle + logout
- [x] Shared widget library (6 reusable widgets)
- [x] Dark/light theme with SharedPreferences persistence

### Phase 3: Production Hardening ⏳ PENDING
- [ ] Load testing
- [ ] Security audit
- [ ] Performance optimization
- [ ] Production deployment
- [ ] Map/location picker for commute creation
- [ ] Password reset flow
- [ ] Real email verification
- [ ] Push notifications

---

## Key Achievements

1. **Geospatial Accuracy:** Implemented Geography (not Geometry) types for precise meter-based calculations
2. **Safety at Scale:** Database-level gender filtering prevents any application-level bypass
3. **Real-time Processing:** 50Hz IMU data processing with zero-lag background tasks
4. **Privacy First:** Delete-by-default architecture for location data
5. **Zero-Liability Auth:** SHA-256 email hashing — raw emails never reach the server
6. **Cross-Platform:** Flutter mobile app with Riverpod state management and dark/light themes

---

## Contact & Contribution

This is a **Digital Public Infrastructure** project. Contributions are welcome:

- Code contributions via pull requests
- Documentation improvements
- Security audits
- Feature requests via issues

---

*Document Version: 2.0*
*Last Updated: May 17, 2026*
*Status: Backend + Flutter UI Complete, Ready for Production Hardening*
