# Civic-Link DPI - API Reference

## Base URL

```
Development: http://localhost:8000
Production:  https://api.civic-link.example.com
```

## Authentication

All protected endpoints require JWT authentication via Bearer token:

```
Authorization: Bearer <jwt_token>
```

**Token Generation:**
- `POST /api/v1/auth/login/access-token` — Zero-Liability login (email hashed client-side)
- `POST /api/v1/auth/register` — Registration with domain whitelist

---

## API Version

Current version: **v1**

All endpoints are prefixed with `/api/v1`

---

## Endpoints

### 1. Authentication

#### POST /api/v1/auth/register

Register a new user with Zero-Liability privacy. Email is hashed client-side.

**Request Body:**
```json
{
  "email_hash": "sha256-hash-of-email",
  "email_domain": "cmrcet.ac.in",
  "password": "SecurePass123!",
  "full_name": "John Doe",
  "phone_number": "+91-98765-43210",
  "gender": "male",
  "company_name": "TechCorp India",
  "employee_id": "EMP12345"
}
```

**Response (201 Created):**
```json
{
  "id": "uuid-user-id",
  "email_domain": "cmrcet.ac.in",
  "full_name": "John Doe",
  "gender": "male",
  "company_name": "TechCorp India",
  "role": "commuter",
  "is_verified": false
}
```

**Note:** Newly registered users have `is_verified: false`. They must verify their account before accessing protected endpoints. See `POST /auth/verify`.

**Whitelisted Domains:** `cmrcet.ac.in`, `company.com`, `govt.in`, `hyderabadpolice.gov.in`

---

#### POST /api/v1/auth/login/access-token

Zero-Liability login. Only email_hash + domain transmitted.

**Request Body:**
```json
{
  "email_hash": "sha256-hash-of-email",
  "email_domain": "cmrcet.ac.in",
  "password": "SecurePass123!"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

---

#### POST /api/v1/auth/verify

Verify a user account. Currently a placeholder — accepts the user's own ID as the verification token. In production, this will accept an email verification token.

**Authentication:** Required (JWT Bearer token)

**Request Body:**
```json
{
  "token": "uuid-user-id"
}
```

**Response (200 OK):**
```json
{
  "id": "uuid-user-id",
  "is_verified": true,
  "message": "Account verified successfully"
}
```

**Error Responses:**
- `400 Bad Request`: Invalid verification token
- `401 Unauthorized`: Not authenticated

---

#### GET /api/v1/auth/me

Get current authenticated user profile.

**Response (200 OK):**
```json
{
  "id": "uuid-user-id",
  "email_domain": "cmrcet.ac.in",
  "full_name": "John Doe",
  "gender": "male",
  "company_name": "TechCorp India",
  "role": "commuter",
  "is_verified": true
}
```

---

### 2. Telemetry

#### POST /api/v1/telemetry/telemetry

Submit 50Hz IMU batch for background processing. Returns 202 immediately.

**Request Body:**
```json
{
  "user_id": "uuid-driver-id",
  "match_id": "uuid-match-id",
  "readings": [
    {
      "timestamp_ms": 1704067200000,
      "gyro_x": 0.05,
      "gyro_y": 0.02,
      "gyro_z": 2.1,
      "accel_x": 0.1,
      "accel_y": -0.2,
      "accel_z": 9.8
    }
  ]
}
```

**Response (202 Accepted):**
```json
{
  "user_id": "uuid-driver-id",
  "processed_readings": 50,
  "swerve_events_detected": 0,
  "swerve_events": [],
  "old_civic_score": 0.0,
  "new_civic_score": 0.0,
  "message": "Telemetry batch accepted for processing"
}
```

**Processing:**
- Background task processes IMU data asynchronously
- Swerve detection: `abs(gyro_z) > 1.5 rad/s`
- 60-second cooldown between swerve events
- Civic score updated via weighted rolling average

---

### 3. Commutes

#### POST /api/v1/commutes

Create a new commute offer (driver).

**Request Body:**
```json
{
  "origin_lat": 17.4930,
  "origin_lon": 78.4020,
  "destination_lat": 17.4430,
  "destination_lon": 78.3770,
  "origin_address": "KPHB Phase 3, Hyderabad",
  "destination_address": "Mindspace, HITEC City",
  "departure_date": "2026-04-16",
  "departure_time": "09:00:00",
  "available_seats": 2,
  "total_seats": 4,
  "is_women_only": false,
  "commute_type": "one_time"
}
```

**Response (201 Created):**
```json
{
  "id": "uuid-commute-id",
  "driver_id": "uuid-driver-id",
  "origin_address": "KPHB Phase 3, Hyderabad",
  "destination_address": "Mindspace, HITEC City",
  "departure_date": "2026-04-16",
  "departure_time": "09:00:00",
  "available_seats": 2,
  "total_seats": 4,
  "is_women_only": false,
  "commute_type": "one_time",
  "status": "active"
}
```

---

#### GET /api/v1/commutes/my

Get all active commutes for the authenticated driver.

**Response (200 OK):**
```json
[
  {
    "id": "uuid-commute-id",
    "driver_id": "uuid-driver-id",
    "origin_address": "KPHB Phase 3",
    "destination_address": "Mindspace",
    "departure_date": "2026-04-16",
    "departure_time": "09:00:00",
    "available_seats": 2,
    "total_seats": 4,
    "is_women_only": false,
    "commute_type": "one_time",
    "status": "active"
  }
]
```

---

#### GET /api/v1/commutes/{commute_id}

Get commute details with driver info.

**Response (200 OK):**
```json
{
  "id": "uuid-commute-id",
  "driver_id": "uuid-driver-id",
  "origin_address": "KPHB Phase 3",
  "destination_address": "Mindspace",
  "departure_date": "2026-04-16",
  "departure_time": "09:00:00",
  "available_seats": 2,
  "total_seats": 4,
  "is_women_only": false,
  "commute_type": "one_time",
  "status": "active",
  "driver_name": "John Doe",
  "driver_gender": "male",
  "driver_score": 95.5
}
```

---

#### POST /api/v1/commutes/{commute_id}/cancel

Cancel an active commute (driver only).

**Response (200 OK):** Updated commute with `status: "cancelled"`

---

#### POST /api/v1/commutes/offers

Create a commute offer (passenger requesting a ride).

**Request Body:**
```json
{
  "origin_lat": 17.4930,
  "origin_lon": 78.4020,
  "destination_lat": 17.4430,
  "destination_lon": 78.3770,
  "origin_address": "KPHB Phase 3, Block B",
  "destination_address": "Mindspace, Building 3",
  "preferred_departure_date": "2026-04-16",
  "preferred_departure_time": "09:00:00",
  "is_women_only": true,
  "max_walking_distance": 500,
  "time_flexibility_minutes": 15
}
```

**Response (201 Created):**
```json
{
  "id": "uuid-offer-id",
  "passenger_id": "uuid-passenger-id",
  "origin_address": "KPHB Phase 3, Block B",
  "destination_address": "Mindspace, Building 3",
  "preferred_departure_date": "2026-04-16",
  "preferred_departure_time": "09:00:00",
  "is_women_only": true,
  "max_walking_distance": 500,
  "status": "pending"
}
```

---

### 4. Matches

#### POST /api/v1/matches/{commute_id}/request

Request to join a commute as a passenger. Enforces hard-reject safety logic.

**Response (201 Created):**
```json
{
  "id": "uuid-match-id",
  "commute_id": "uuid-commute-id",
  "driver_id": "uuid-driver-id",
  "passenger_id": "uuid-passenger-id",
  "status": "pending",
  "pickup_radius_meters": 245,
  "fare_amount": null,
  "payment_status": "pending",
  "commute_was_women_only": false,
  "offer_was_women_only": true,
  "confirmed_at": null,
  "started_at": null,
  "completed_at": null
}
```

**Error Responses:**
- `403 Forbidden`: Safety violation (gender mismatch on women-only commute)
- `400 Bad Request`: No seats available or commute not found

---

#### POST /api/v1/matches/{match_id}/confirm

Confirm a pending match (driver action).

**Response (200 OK):** Match with `status: "confirmed"`

---

#### GET /api/v1/matches/my

Get all active matches for the authenticated user (as driver or passenger).

**Response (200 OK):**
```json
{
  "items": [
    {
      "id": "uuid-match-id",
      "commute_id": "uuid-commute-id",
      "driver_id": "uuid-driver-id",
      "passenger_id": "uuid-passenger-id",
      "status": "pending",
      "pickup_radius_meters": 245,
      "payment_status": "pending",
      "commute_was_women_only": false,
      "offer_was_women_only": true
    }
  ],
  "total": 1
}
```

---

#### GET /api/v1/matches/{match_id}

Get match details with driver and passenger names.

**Response (200 OK):**
```json
{
  "id": "uuid-match-id",
  "commute_id": "uuid-commute-id",
  "driver_id": "uuid-driver-id",
  "passenger_id": "uuid-passenger-id",
  "status": "pending",
  "pickup_radius_meters": 245,
  "driver_name": "John Doe",
  "passenger_name": "Jane Smith",
  "origin_address": "KPHB Phase 3",
  "destination_address": "Mindspace"
}
```

---

#### POST /api/v1/matches/{match_id}/rate

Rate a completed match (1-5 stars with optional review).

**Request Body:**
```json
{
  "driver_rating": 5,
  "driver_review": "Excellent driver, safe and punctual",
  "passenger_rating": 4,
  "passenger_review": "Good passenger"
}
```

**Response (200 OK):** Updated match with ratings.

---

### 5. Civic Score

#### POST /api/v1/civic-score/ingest

Ingest raw telemetry samples and recalculate civic score using weighted penalty model.

**Request Body:**
```json
{
  "trip_id": "uuid-trip-id",
  "samples": [
    {
      "timestamp": "2026-05-16T10:30:00Z",
      "speed_kmh": 65.0,
      "acceleration_ms2": 2.1,
      "braking_ms2": 0.5,
      "swerve_index": 0.15,
      "phone_usage_detected": false
    }
  ]
}
```

**Scoring Formula:**
```
base = 100.0
speed_penalty  = clamp(mean(speed_kmh) - 60, 0, 40) * 0.4
brake_penalty  = count(braking_ms2 > 4.0) * 2.0
accel_penalty  = count(acceleration_ms2 > 3.5) * 1.5
swerve_penalty = ratio(swerve_index > 0.3) * 10.0
phone_penalty  = count(phone_usage_detected=True) * 5.0

raw_score = base - speed - brake - accel - swerve - phone
final_score = (existing_score * 0.7) + (clamp(raw_score, 0, 100) * 0.3)
```

**Response (200 OK):**
```json
{
  "civic_score": 92.5,
  "delta": -2.3,
  "tier": "excellent"
}
```

**Score Tiers:** `excellent` (≥90), `good` (≥75), `fair` (≥60), `poor` (≥40), `critical` (<40)

---

#### GET /api/v1/civic-score/me

Get current user's civic score.

**Response (200 OK):**
```json
{
  "score": 92.5,
  "score_tier": "excellent",
  "total_trips": 45,
  "swerve_count": 3,
  "speeding_count": 1,
  "hard_braking_count": 2
}
```

---

#### GET /api/v1/civic-score/history

Get score change history.

**Query Parameters:** `limit` (default: 50)

**Response (200 OK):**
```json
[
  {
    "id": "uuid-history-id",
    "old_score": 95.0,
    "new_score": 92.5,
    "trigger_event": "sample_ingestion",
    "swerve_count": 3,
    "speeding_count": 1,
    "created_at": "2026-05-16T10:30:00"
  }
]
```

---

### 6. Health Check

#### GET /health

Check API health.

**Response (200 OK):**
```json
{
  "status": "healthy",
  "service": "Civic-Link DPI",
  "version": "0.1.0"
}
```

---

## Error Responses

All errors follow this format:

```json
{
  "detail": "Error description"
}
```

**Common HTTP Status Codes:**

| Status | Description |
|--------|-------------|
| 400 | Invalid input data |
| 401 | Authentication required or invalid credentials |
| 403 | Permission denied or safety violation |
| 404 | Resource not found |
| 409 | Safety rule violated (gender mismatch) |
| 422 | Pydantic validation error |
| 500 | Internal server error |

---

## Testing the API

### Using curl

```bash
# Health check
curl http://localhost:8000/health

# Register a user
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email_hash": "'$(echo -n "user@cmrcet.ac.in" | sha256sum | cut -d" " -f1)'",
    "email_domain": "cmrcet.ac.in",
    "password": "SecurePass123!",
    "full_name": "Test User",
    "phone_number": "+91-99999-00001",
    "gender": "male",
    "company_name": "Test Corp"
  }'

# Login and get token
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login/access-token \
  -H "Content-Type: application/json" \
  -d '{
    "email_hash": "'$(echo -n "user@cmrcet.ac.in" | sha256sum | cut -d" " -f1)'",
    "email_domain": "cmrcet.ac.in",
    "password": "SecurePass123!"
  }' | jq -r '.access_token')

# Submit telemetry batch
curl -X POST http://localhost:8000/api/v1/telemetry/telemetry \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "your-user-id",
    "readings": [
      {
        "timestamp_ms": 1704067200000,
        "gyro_z": 0.5,
        "gyro_x": 0.1,
        "gyro_y": 0.2,
        "accel_x": 0.1,
        "accel_y": 0.2,
        "accel_z": 9.8
      }
    ]
  }'

# Ingest telemetry samples for scoring
curl -X POST http://localhost:8000/api/v1/civic-score/ingest \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "trip_id": "trip-uuid",
    "samples": [
      {
        "timestamp": "2026-05-16T10:30:00Z",
        "speed_kmh": 65.0,
        "acceleration_ms2": 2.1,
        "braking_ms2": 0.5,
        "swerve_index": 0.15,
        "phone_usage_detected": false
      }
    ]
  }'

# Get civic score
curl http://localhost:8000/api/v1/civic-score/me \
  -H "Authorization: Bearer $TOKEN"
```

---

*Document Version: 2.0*  
*Last Updated: May 16, 2026*
