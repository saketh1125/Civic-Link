# Civic-Link DPI - Testing Guide

## Overview

This document covers all testing strategies, test scripts, and validation procedures for Civic-Link.

---

## Test Categories

1. **Unit Tests** - Individual function/class testing
2. **Integration Tests** - Service and database interaction
3. **Safety Tests** - Hard-reject logic validation
4. **Load Tests** - Performance under stress
5. **End-to-End Tests** - Full user journey simulation

---

## Test Scripts

### 1. Database Seeding (Task 1)

**File:** `app/seed_kphb.py`

**Purpose:** Populate database with test data for development and testing.

**What it creates:**
- 50 users (25 Female, 25 Male)
- 30 commute offers
- All users have @company.com emails
- Locations clustered around KPHB Phase 3 → Mindspace/HITEC City

**Run inside Docker:**
```bash
docker compose exec api python app/seed_kphb.py
```

**Expected Output:**
```
[1/4] Seeding 50 users (25 Female, 25 Male)...
      ✓ Created 50 users
[2/4] Seeding 30 commutes (KPHB Phase 3 -> Mindspace/HITEC City)...
      ✓ Created 30 commutes
[3/4] Creating Women-Only test offer...
      ✓ Created Women-Only offer from female1@company.com
[4/4] Running safety validation...
      Searching for matches within 500m...
      ✓ Matching complete
      
============================================================
SEEDING & SAFETY VALIDATION COMPLETE
============================================================
USERS CREATED: 50
  - Female: 25
  - Male: 25
COMMUTES CREATED: 30
  - Women-Only Commutes: [count]
SAFETY TEST RESULTS:
  - Women-Only Passenger: female1@company.com
  - Total Matches Checked: [count]
  - Male Drivers Found: 0 ✓ (CRITICAL: Should always be 0)
  - Female Drivers Found: [count]
  - Women-Only Commutes Matched: [count]
  - Hard-Reject Safety Logic: VERIFIED ✓
============================================================
```

**Verification File:** `verification_results.txt`
- Contains detailed match results
- Used for manual review

---

### 2. Safety Stress Test (Task 2)

**File:** `app/safety_stress_test.py`

**Purpose:** Simulate 10 Women-Only requests and verify zero male drivers are matched.

**What it tests:**
- Hard-Reject Safety Logic at database level
- 10 consecutive Women-Only requests
- Each request verified for male driver exclusion

**Run inside Docker:**
```bash
docker compose exec api python app/safety_stress_test.py
```

**Expected Output:**
```
======================================================
SAFETY STRESS TEST: 10 Women-Only Requests
======================================================
Request 1/10: Women-Only search by female1@company.com
  ✓ Matched female driver female2@company.com at 245m
Request 2/10: Women-Only search by female2@company.com
  ✓ Matched female driver female3@company.com at 312m
...
Request 10/10: Women-Only search by female10@company.com
  ✓ Matched female driver female11@company.com at 198m

======================================================
TEST PASSED: Hard-Reject Safety Logic Verified
Total matches checked: 15
Male drivers found: 0 (EXPECTED: 0)
Female drivers found: 15
======================================================
```

**Log File:** `safety_audit.log`
- Detailed per-request logging
- Safety violation alerts (if any)
- Timestamped for audit purposes

**Failure Condition:**
If any male driver is returned, the test fails with:
```
✗ SAFETY VIOLATION: Matched male driver male5@company.com for Women-Only request!

======================================================
TEST FAILED: SAFETY VIOLATION DETECTED
Found 1 male drivers in Women-Only matches
Hard-Reject Safety Logic is BROKEN
======================================================
```

---

## Manual Testing Procedures

### 1. Container Health Check

```bash
# Check all containers are running
docker compose ps

# Expected output:
# NAME              STATUS
# civic_postgres    Up (healthy)
# civic_redis       Up (healthy)
# civic_api         Up (healthy)
```

### 2. Database Connection Test

```bash
# Connect to PostgreSQL
docker compose exec postgres psql -U civic -d civic_link -c "SELECT 1;"

# Expected output:
#  ?column?
# ----------
#         1
```

### 3. PostGIS Extension Test

```bash
# Verify PostGIS is enabled
docker compose exec postgres psql -U civic -d civic_link -c "SELECT PostGIS_Version();"

# Expected output:
# 3.4.0 ...
```

### 4. API Health Check

```bash
# Check API is responding
curl http://localhost:8000/health

# Expected output:
# {"status":"healthy","database":"connected"}
```

---

## Geospatial Testing

### Test 1: Coordinate Accuracy

**KPHB Phase 3 to Mindspace Distance:**
```sql
-- Should return ~8.2 km
SELECT ST_Distance(
    ST_SetSRID(ST_MakePoint(78.4020, 17.4930), 4326)::geography,
    ST_SetSRID(ST_MakePoint(78.3770, 17.4430), 4326)::geography
) / 1000 AS distance_km;
```

### Test 2: 500m Radius Search

```sql
-- Should find commutes within 500m of KPHB Phase 3
SELECT c.id, u.email, u.gender,
       ST_Distance(c.origin, ST_SetSRID(ST_MakePoint(78.4020, 17.4930), 4326)::geography) AS distance_m
FROM commutes c
JOIN users u ON c.driver_id = u.id
WHERE ST_DWithin(
    c.origin,
    ST_SetSRID(ST_MakePoint(78.4020, 17.4930), 4326)::geography,
    500
)
AND c.status = 'active';
```

### Test 3: Women-Only Safety Filter

```sql
-- Verify no male drivers returned for women-only search
SELECT COUNT(*) as male_driver_count
FROM (
    SELECT u.gender
    FROM commutes c
    JOIN users u ON c.driver_id = u.id
    WHERE ST_DWithin(c.origin, :passenger_origin, 500)
    AND c.is_women_only = FALSE
    AND u.gender = 'male'  -- This should be excluded by app logic
) subquery;

-- Expected: 0
```

---

## Telemetry Testing

### Test 1: Swerve Detection

**Input:**
```json
{
  "user_id": "test-driver-id",
  "readings": [
    {"timestamp": "2026-04-15T10:00:00Z", "gyro_z": 2.0, "accel_x": 0.1, "accel_y": 0.2}
  ]
}
```

**Expected Result:**
- Swerve event recorded (|2.0| > 1.5 rad/s threshold)
- Civic score decreases
- 60-second cooldown activated

### Test 2: Cooldown Validation

**Test Case:**
1. Submit reading with gyro_z = 2.0 rad/s → Swerve detected
2. Within 60 seconds, submit gyro_z = 2.5 rad/s → No swerve (cooldown)
3. After 60 seconds, submit gyro_z = 2.0 rad/s → Swerve detected

---

## Integration Testing

### Full User Journey Test

```bash
# 1. Seed database
docker compose exec api python app/seed_kphb.py

# 2. Create a Women-Only commute offer
curl -X POST http://localhost:8000/api/v1/commute-offers \
  -H "Content-Type: application/json" \
  -d '{
    "passenger_id": "female-user-uuid",
    "origin": {"lat": 17.4930, "lon": 78.4020, "address": "KPHB"},
    "destination": {"lat": 17.4430, "lon": 78.3770, "address": "Mindspace"},
    "preferred_departure_date": "2026-04-16",
    "preferred_departure_time": "09:00:00",
    "is_women_only": true
  }'

# 3. Find matches (should return only female drivers)
curl "http://localhost:8000/api/v1/commute-offers/{offer_id}/matches?radius_meters=1000"

# 4. Verify all returned drivers are female
```

---

## Performance Testing

### Load Test: Matching Service

**Goal:** Test matching performance with 1000 concurrent users.

**Tool:** Locust (Python)

**Sample locustfile.py:**
```python
from locust import HttpUser, task, between

class CivicLinkUser(HttpUser):
    wait_time = between(1, 5)
    
    @task
    def search_commutes(self):
        self.client.get("/api/v1/commutes?origin_lat=17.4930&origin_lon=78.4020")
    
    @task(3)
    def submit_telemetry(self):
        self.client.post("/api/v1/telemetry", json={
            "user_id": "load-test-user",
            "readings": [{"timestamp": "2026-04-15T10:00:00Z", "gyro_z": 0.1}]
        })
```

**Run:**
```bash
locust -f locustfile.py --host=http://localhost:8000
```

**Target Metrics:**
- P50 latency < 100ms
- P95 latency < 300ms
- P99 latency < 500ms
- Throughput: 1000 requests/second

---

## Regression Testing

### Before Each Release

1. **Run all test scripts:**
   ```bash
   docker compose exec api python app/seed_kphb.py
   docker compose exec api python app/safety_stress_test.py
   ```

2. **Verify logs:**
   ```bash
   docker compose exec api cat safety_audit.log
   docker compose exec api cat verification_results.txt
   ```

3. **Check for safety violations:**
   ```bash
   docker compose exec api grep -i "violation" safety_audit.log || echo "No violations found"
   ```

4. **Verify database schema:**
   ```bash
   docker compose exec postgres psql -U civic -d civic_link -c "\dt"
   ```

---

## Continuous Integration

### GitHub Actions Workflow (Future)

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Start containers
        run: docker compose up -d postgres redis
      
      - name: Run migrations
        run: docker compose run --rm migrations alembic upgrade head
      
      - name: Seed database
        run: docker compose exec api python app/seed_kphb.py
      
      - name: Run safety tests
        run: docker compose exec api python app/safety_stress_test.py
      
      - name: Verify no violations
        run: |
          if docker compose exec api grep -q "SAFETY VIOLATION" safety_audit.log; then
            echo "SAFETY VIOLATION DETECTED"
            exit 1
          fi
```

---

## Debugging Failed Tests

### Issue: Seed script fails

**Check:**
```bash
# Database connection
docker compose logs postgres | tail -20

# Container status
docker compose ps

# File permissions
ls -la init.sql postgresql.conf
```

### Issue: Safety test finds male drivers

**Investigate:**
```sql
-- Check user genders
SELECT gender, COUNT(*) FROM users GROUP BY gender;

-- Check women-only commute flags
SELECT is_women_only, COUNT(*) FROM commutes GROUP BY is_women_only;

-- Verify hard-reject SQL clause is in code
grep -n "women_only" app/services/match_service.py
```

### Issue: Geospatial queries return wrong results

**Verify:**
```sql
-- Check SRID
SELECT Find_SRID('public', 'commutes', 'origin');
-- Should return 4326

-- Check Geography type
SELECT ST_GeometryType(origin) FROM commutes LIMIT 1;
-- Should return ST_Point

-- Test distance calculation
SELECT ST_Distance(
    ST_GeogFromText('POINT(78.4020 17.4930)'),
    ST_GeogFromText('POINT(78.3770 17.4430)')
);
-- Should return ~8200 meters
```

---

## Test Checklist

### Pre-Release Checklist

- [ ] Docker containers start successfully
- [ ] Database migrations run without errors
- [ ] PostGIS extension enabled
- [ ] Seed script completes (50 users, 30 commutes)
- [ ] Safety stress test passes (0 male drivers for Women-Only)
- [ ] Geospatial distance calculations accurate (KPHB→HITEC ~8.2km)
- [ ] API health check returns 200
- [ ] Telemetry endpoint accepts 202
- [ ] No safety violations in safety_audit.log
- [ ] All files committed to git

---

*Document Version: 1.0*  
*Last Updated: April 15, 2026*
