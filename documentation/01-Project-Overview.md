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
| **Database** | PostgreSQL + PostGIS | Geospatial data storage |
| **Cache** | Redis | Session & commute offer caching |
| **ORM** | SQLAlchemy 2.0 | Database abstraction |
| **Validation** | Pydantic | Input/output validation |
| **Async** | asyncpg | Async PostgreSQL driver |
| **Geospatial** | GeoAlchemy2 | PostGIS integration |

---

## Project Structure

```
Traffic-pooling/
├── app/
│   ├── api/v1/endpoints/    # API route handlers
│   ├── core/                 # Config, database, security, exceptions
│   ├── models/              # SQLAlchemy models
│   ├── schemas/             # Pydantic schemas
│   └── services/            # Business logic
├── docker/                  # Docker configurations
├── documentation/           # Project documentation (this folder)
├── tests/                   # Test suite
├── docker-compose.yml       # Container orchestration
├── requirements.txt         # Python dependencies
└── .env                     # Environment variables
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
- [x] SQLAlchemy 2.0 models with PostGIS
- [x] Hard-reject safety logic
- [x] Telemetry processing service
- [x] Docker containerization
- [x] Database seeding & safety testing

### Phase 2: Flutter UI Shell ⏳ PENDING
- [ ] Mobile app UI/UX
- [ ] Real-time location tracking
- [ ] In-app matching interface
- [ ] Civic score visualization

### Phase 3: Production Hardening ⏳ PENDING
- [ ] Load testing
- [ ] Security audit
- [ ] Performance optimization
- [ ] Production deployment

---

## Key Achievements

1. **Geospatial Accuracy:** Implemented Geography (not Geometry) types for precise meter-based calculations
2. **Safety at Scale:** Database-level gender filtering prevents any application-level bypass
3. **Real-time Processing:** 50Hz IMU data processing with zero-lag background tasks
4. **Privacy First:** Delete-by-default architecture for location data

---

## Contact & Contribution

This is a **Digital Public Infrastructure** project. Contributions are welcome:

- Code contributions via pull requests
- Documentation improvements
- Security audits
- Feature requests via issues

---

*Document Version: 1.0*  
*Last Updated: April 12, 2026*  
*Status: Backend Verified, Ready for Flutter UI*
