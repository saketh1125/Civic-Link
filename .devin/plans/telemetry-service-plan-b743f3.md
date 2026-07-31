# 50Hz IMU Telemetry Engine - Implementation Plan

Create a production-ready Dart Isolate-based telemetry service for Civic-Link that batches IMU sensor data at 50Hz and transmits to the backend without blocking the UI thread.

## Implementation Strategy

### File: `lib/services/telemetry_isolate.dart`

**1. Data Models**
- `IMUReading` class: Represents a single sensor reading with timestamp, accelerometer (x,y,z), and gyroscope (x,y,z)
- `TelemetryBatch` class: Container for multiple IMU readings with serialization helpers

**2. Isolate Communication Protocol**
- `TelemetryCommand` sealed class with subtypes: `StartTelemetry`, `StopTelemetry`
- `TelemetryState` class: Manages isolate lifecycle and port communication
- Bidirectional port setup: Main isolate sends commands via `SendPort`, worker isolate returns status/errors via `ReceivePort`

**3. Top-Level Isolate Entry Point (`_telemetryIsolateEntry`)**
- Receives initial handshake with `SendPort` for communication back to main isolate
- Sets up internal `ReceivePort` for command listening
- Initializes `sensors_plus` streams (`userAccelerometerEvents`, `gyroscopeEvents`)
- Combines accelerometer and gyroscope data at ~20ms intervals (50Hz target)
- Buffers readings into batches of configurable size (default: 10 readings)
- On batch full: attempts network transmission via Dio
- **Retry Logic**: Failed batches enter retry queue (max 50 batches). Successful transmission clears retry queue.
- **Memory Safety**: Strict cap on retry queue prevents OOM in extended dead zones.

**4. TelemetryService Class**
- Constructor: `baseUrl` (required), `authToken` (required), `batchSize` (default 10), `flushIntervalMs` (default 200)
- `start()` method: Spawns isolate with initial auth token, establishes port handshake
- `stop()` method: Sends stop command via `SendPort`, terminates isolate cleanly
- `updateToken()` method: Allows token refresh without stopping/restarting the isolate
- `SendPort` caching for command dispatch

**5. Error Handling Strategy**
- **Sensor Errors**: Log and continue (don't crash the isolate)
- **Network Errors**: Push to retry queue, continue collecting new data
- **Dio Timeouts**: Treat as retryable error, don't clear active buffer
- **Non-retryable errors (4xx)**: Log error, discard batch, continue
- **Memory pressure**: When retry queue hits 50 batches, drop oldest (FIFO)

**6. Payload Format**
```json
{
  "readings": [
    {
      "timestamp": "2026-05-04T07:20:15.123Z",
      "accel": {"x": 0.0, "y": 0.0, "z": 0.0},
      "gyro": {"x": 0.0, "y": 0.0, "z": 0.0}
    }
  ]
}
```

**7. HTTP Configuration**
- Endpoint: `POST /api/v1/telemetry/ingest`
- Headers: `Authorization: Bearer <token>`, `Content-Type: application/json`
- Dio timeout: 10 seconds connect, 10 seconds receive

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Token passed at spawn | Isolates don't share memory; cannot read FlutterSecureStorage |
| Token update method | Allows seamless token refresh without stopping data collection |
| FIFO retry queue drop | Oldest data is least valuable for "Civic Score" EMA calculation |
| Hard 50 batch cap | ~10 seconds of data max; prevents OOM in dead zones |
