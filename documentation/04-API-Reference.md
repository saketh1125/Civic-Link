# Civic-Link DPI - API Reference

## Base URL

```
Development: http://localhost:8000
Production:  https://api.civic-link.example.com
```

## Authentication

All endpoints require JWT authentication via Bearer token in the Authorization header:

```
Authorization: Bearer <jwt_token>
```

**Token Generation:** (Not yet implemented - see Future Work)
- Endpoint: `POST /api/v1/auth/login`
- Payload: `{ "email": "user@company.com", "password": "..." }`

---

## API Version

Current version: **v1**

All endpoints are prefixed with `/api/v1`

---

## Endpoints

### 1. Telemetry

#### POST /api/v1/telemetry

Submit 50Hz IMU (Inertial Measurement Unit) data for civic scoring.

**Request Body:**
```json
{
  "user_id": "uuid-of-driver",
  "match_id": "uuid-of-active-match",
  "readings": [
    {
      "timestamp": "2026-04-15T10:30:00.000Z",
      "gyro_z": 0.5236,
      "accel_x": 0.5,
      "accel_y": -0.2,
      "speed_mps": 15.5
    }
  ]
}
```

**Field Descriptions:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| user_id | string (UUID) | Yes | Driver submitting telemetry |
| match_id | string (UUID) | No | Associated active trip |
| readings | array | Yes | Array of IMU readings (max 50/sec) |
| readings[].timestamp | ISO 8601 | Yes | Reading timestamp |
| readings[].gyro_z | float | Yes | Z-axis rotation rate (rad/s) |
| readings[].accel_x | float | Yes | X-axis acceleration |
| readings[].accel_y | float | Yes | Y-axis acceleration |
| readings[].speed_mps | float | No | GPS speed (meters/second) |

**Response (202 Accepted):**
```json
{
  "status": "accepted",
  "batch_id": "uuid-batch-identifier",
  "readings_count": 50,
  "message": "Telemetry accepted for background processing"
}
```

**Processing:**
- Returns immediately (zero-lag for mobile clients)
- Background task processes IMU data asynchronously
- Swerve detection: `abs(gyro_z) > 1.5 rad/s`
- 60-second cooldown between swerve events
- Civic score updated via weighted rolling average

**Error Responses:**
- `400 Bad Request`: Invalid IMU data format
- `404 Not Found`: User or match not found
- `422 Validation Error`: Missing required fields

---

### 2. Commutes

#### GET /api/v1/commutes

List available commute offers with optional filtering.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| origin_lat | float | No | Origin latitude |
| origin_lon | float | No | Origin longitude |
| dest_lat | float | No | Destination latitude |
| dest_lon | float | No | Destination longitude |
| date | date | No | Departure date (YYYY-MM-DD) |
| radius | int | No | Search radius in meters (default: 500) |
| women_only | boolean | No | Filter for women-only commutes |

**Response (200 OK):**
```json
{
  "commutes": [
    {
      "id": "uuid-commute-id",
      "driver": {
        "id": "uuid-driver-id",
        "gender": "female",
        "civic_score": 95.5
      },
      "origin": {
        "lat": 17.4930,
        "lon": 78.4020,
        "address": "KPHB Phase 3, Hyderabad"
      },
      "destination": {
        "lat": 17.4430,
        "lon": 78.3770,
        "address": "Mindspace, HITEC City"
      },
      "departure": {
        "date": "2026-04-16",
        "time": "09:00:00"
      },
      "seats_available": 2,
      "is_women_only": false,
      "status": "active"
    }
  ],
  "total": 15,
  "radius_meters": 500
}
```

---

#### POST /api/v1/commutes

Create a new commute offer (driver offering a ride).

**Request Body:**
```json
{
  "driver_id": "uuid-driver-id",
  "origin": {
    "lat": 17.4930,
    "lon": 78.4020,
    "address": "KPHB Phase 3, Block A"
  },
  "destination": {
    "lat": 17.4430,
    "lon": 78.3770,
    "address": "Mindspace, Building 2"
  },
  "departure_date": "2026-04-16",
  "departure_time": "09:00:00",
  "seats_offered": 3,
  "is_women_only": false,
  "max_walking_distance": 500
}
```

**Response (201 Created):**
```json
{
  "id": "uuid-commute-id",
  "status": "active",
  "expires_at": "2026-04-16T08:45:00Z",
  "message": "Commute offer created successfully"
}
```

---

### 3. Commute Offers

#### POST /api/v1/commute-offers

Create a commute offer (passenger requesting a ride).

**Request Body:**
```json
{
  "passenger_id": "uuid-passenger-id",
  "origin": {
    "lat": 17.4930,
    "lon": 78.4020,
    "address": "KPHB Phase 3, Block B"
  },
  "destination": {
    "lat": 17.4430,
    "lon": 78.3770,
    "address": "Mindspace, Building 3"
  },
  "preferred_departure_date": "2026-04-16",
  "preferred_departure_time": "09:00:00",
  "is_women_only": true,
  "max_walking_distance": 500
}
```

**Response (201 Created):**
```json
{
  "id": "uuid-offer-id",
  "status": "pending",
  "message": "Commute offer created. Searching for matches..."
}
```

---

#### GET /api/v1/commute-offers/{offer_id}/matches

Find matching commutes for a passenger offer.

**Path Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| offer_id | string (UUID) | The commute offer ID |

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| radius_meters | int | 500 | Search radius in meters |

**Response (200 OK):**
```json
{
  "offer_id": "uuid-offer-id",
  "matches": [
    {
      "commute_id": "uuid-commute-id",
      "driver": {
        "id": "uuid-driver-id",
        "email": "driver@company.com",
        "gender": "female",
        "civic_score": 98.5
      },
      "origin_distance_m": 245,
      "destination_distance_m": 180,
      "departure_time_diff_min": 5,
      "seats_available": 2
    }
  ],
  "total_matches": 3,
  "search_radius_m": 500
}
```

**Safety Guarantee:**
- If `is_women_only=true` in the offer, only female drivers are returned
- Enforced at database level via hard-reject SQL clause
- Zero male drivers will ever appear in results

---

### 4. Matches

#### POST /api/v1/matches

Create a match between a commute and a commute offer.

**Request Body:**
```json
{
  "commute_id": "uuid-commute-id",
  "commute_offer_id": "uuid-offer-id",
  "passenger_id": "uuid-passenger-id",
  "driver_id": "uuid-driver-id"
}
```

**Response (201 Created):**
```json
{
  "match_id": "uuid-match-id",
  "status": "confirmed",
  "safety_snapshot": {
    "commute_was_women_only": false,
    "offer_was_women_only": true,
    "driver_gender": "female"
  },
  "message": "Match created successfully"
}
```

**Error Responses:**
- `409 Conflict`: Safety violation (e.g., male driver for women-only request)
- `400 Bad Request`: No seats available
- `404 Not Found`: Commute or offer not found

---

#### GET /api/v1/matches/{match_id}

Get details of a specific match.

**Response (200 OK):**
```json
{
  "id": "uuid-match-id",
  "commute": {
    "id": "uuid-commute-id",
    "origin": "KPHB Phase 3",
    "destination": "Mindspace"
  },
  "passenger": {
    "id": "uuid-passenger-id",
    "email": "passenger@company.com"
  },
  "driver": {
    "id": "uuid-driver-id",
    "email": "driver@company.com",
    "civic_score": 95.5
  },
  "status": "confirmed",
  "match_time": "2026-04-15T08:30:00Z"
}
```

---

#### PATCH /api/v1/matches/{match_id}

Update match status (confirm, complete, cancel).

**Request Body:**
```json
{
  "status": "completed",
  "reason": "Trip finished successfully"
}
```

**Status Values:**
- `pending`: Initial state
- `confirmed`: Passenger accepted the match
- `completed`: Trip finished
- `cancelled`: Trip cancelled by either party

---

### 5. Civic Score

#### GET /api/v1/civic-score/{user_id}

Get a user's civic score and history.

**Response (200 OK):**
```json
{
  "user_id": "uuid-user-id",
  "current_score": 92.5,
  "score_history": [
    {
      "score": 92.5,
      "swerve_events_24h": 1,
      "speeding_events_24h": 0,
      "calculated_at": "2026-04-15T00:00:00Z"
    }
  ],
  "ranking": {
    "percentile": 85,
    "total_drivers": 150
  }
}
```

---

### 6. Health Check

#### GET /health

Check API and database health.

**Response (200 OK):**
```json
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2026-04-15T10:30:00Z"
}
```

---

## Error Responses

All errors follow this format:

```json
{
  "detail": {
    "message": "Error description",
    "code": "ERROR_CODE",
    "field": "field_name (if applicable)"
  }
}
```

**Common Error Codes:**

| Code | HTTP Status | Description |
|------|-------------|-------------|
| VALIDATION_ERROR | 422 | Invalid input data |
| NOT_FOUND | 404 | Resource not found |
| SAFETY_VIOLATION | 409 | Hard-reject safety rule violated |
| UNAUTHORIZED | 401 | Authentication required |
| FORBIDDEN | 403 | Permission denied |
| CONFLICT | 409 | Resource conflict |

---

## Rate Limiting

**Not yet implemented** (see Future Work)

Planned limits:
- Telemetry: 100 requests/minute per user
- Matching: 20 requests/minute per user
- General: 1000 requests/hour per user

---

## Pagination

**Not yet implemented** (see Future Work)

For list endpoints, planned parameters:
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20, max: 100)

Response will include:
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "pages": 8
  }
}
```

---

## WebSocket (Future)

Real-time updates planned:
- `ws://localhost:8000/ws/matches/{user_id}`
- Events: `match_found`, `match_confirmed`, `match_cancelled`

---

## Testing the API

### Using curl

```bash
# Health check
curl http://localhost:8000/health

# Create telemetry batch
curl -X POST http://localhost:8000/api/v1/telemetry \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user-id",
    "readings": [
      {
        "timestamp": "2026-04-15T10:30:00Z",
        "gyro_z": 0.5,
        "accel_x": 0.1,
        "accel_y": 0.2
      }
    ]
  }'

# List commutes
curl "http://localhost:8000/api/v1/commutes?origin_lat=17.4930&origin_lon=78.4020&date=2026-04-16"
```

---

## SDKs (Future)

Planned official SDKs:
- **Flutter/Dart:** For mobile app
- **Python:** For backend integrations
- **JavaScript/TypeScript:** For web dashboards

---

*Document Version: 1.0*  
*Last Updated: April 15, 2026*
