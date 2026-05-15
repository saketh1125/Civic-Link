#!/usr/bin/env python3
"""
Civic-Link Telemetry Simulator

Simulates a 22-second commute with 50Hz IMU data transmission to test the
Civic Score algorithm (EMA: S_new = S_old * 0.85 + event_score * 0.15).

Phases:
  - 0-10s:  Cruising (normal driving, low variance)
  - 10-12s: Aggressive Swerve (high gyro/accel spikes)
  - 12-22s: Recovery (return to baseline)

Usage:
  1. Ensure the FastAPI backend is running on localhost:8000
  2. Run: python app/telemetry_sim.py
  3. Watch the civic_score drop during Phase 2 and recover in Phase 3

Requirements:
  pip install aiohttp
"""

import asyncio
import aiohttp
import random
import uuid
from datetime import datetime, timezone
from typing import Dict, Any

# Configuration
API_ENDPOINT = "http://localhost:8000/api/v1/telemetry/ingest"
DRIVER_ID = "test-driver-uuid-12345678"
SAMPLE_RATE_HZ = 50
SAMPLE_INTERVAL = 1.0 / SAMPLE_RATE_HZ  # 0.02 seconds
TOTAL_DURATION = 22  # seconds

# Phase boundaries
PHASE_1_END = 10.0   # Cruising ends
PHASE_2_END = 12.0   # Aggressive Swerve ends


def generate_payload(elapsed_time: float, sequence: int) -> Dict[str, Any]:
    """Generate IMU payload based on current simulation phase."""
    
    # Determine phase
    if elapsed_time < PHASE_1_END:
        # Phase 1: Cruising - normal driving
        accel = {
            "x": random.gauss(0.0, 0.1),
            "y": random.gauss(9.8, 0.2),  # Gravity
            "z": random.gauss(0.0, 0.1)
        }
        gyro = {
            "x": random.gauss(0.0, 0.05),
            "y": random.gauss(0.0, 0.05),
            "z": random.uniform(-0.1, 0.1)  # Gentle turns
        }
        
    elif elapsed_time < PHASE_2_END:
        # Phase 2: Aggressive Swerve - sudden lane change
        # Simulate hard cornering with high lateral forces
        accel = {
            "x": random.gauss(2.5, 0.5),   # Forward acceleration spike
            "y": random.gauss(6.0, 1.5),   # Reduced gravity feel due to lateral force
            "z": random.gauss(3.0, 0.8)    # Vertical jolt
        }
        gyro = {
            "x": random.gauss(0.2, 0.1),
            "y": random.gauss(-0.3, 0.15),
            "z": random.choice([random.uniform(1.8, 2.5), random.uniform(-2.5, -1.8)])  # Sharp yaw
        }
        
    else:
        # Phase 3: Recovery - return to normal
        accel = {
            "x": random.gauss(0.0, 0.15),
            "y": random.gauss(9.8, 0.25),
            "z": random.gauss(0.0, 0.15)
        }
        gyro = {
            "x": random.gauss(0.0, 0.06),
            "y": random.gauss(0.0, 0.06),
            "z": random.uniform(-0.12, 0.12)
        }
    
    # Simulate GPS movement along a route
    base_lat = 17.4065
    base_lon = 78.4772
    progress = elapsed_time / TOTAL_DURATION
    
    gps = {
        "lat": base_lat + (progress * 0.01) + random.gauss(0, 0.0001),
        "lon": base_lon + (progress * 0.01) + random.gauss(0, 0.0001),
        "speed_kmh": 45.0 if elapsed_time < PHASE_2_END < elapsed_time else 35.0 + random.gauss(0, 3)
    }
    
    return {
        "driver_id": DRIVER_ID,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "accel": accel,
        "gyro": gyro,
        "gps": gps
    }


async def transmit_sample(session: aiohttp.ClientSession, elapsed_time: float, sequence: int) -> None:
    """Transmit a single telemetry sample to the backend."""
    payload = generate_payload(elapsed_time, sequence)
    
    try:
        async with session.post(API_ENDPOINT, json=payload) as response:
            if response.status == 200:
                data = await response.json()
                civic_score = data.get("civic_score")
                phase = "CRUISING" if elapsed_time < PHASE_1_END else "SWERVE" if elapsed_time < PHASE_2_END else "RECOVERY"
                
                if civic_score is not None and sequence % 50 == 0:  # Log every second
                    print(f"[{phase:8}] t={elapsed_time:5.2f}s | seq={sequence:4} | Civic Score: {civic_score:.4f}")
            else:
                error_text = await response.text()
                print(f"[ERROR] HTTP {response.status}: {error_text[:100]}")
                
    except aiohttp.ClientConnectorError:
        print(f"[ERROR] Connection refused - is the server running?")
    except asyncio.TimeoutError:
        print(f"[ERROR] Request timeout at t={elapsed_time:.2f}s")
    except Exception as e:
        print(f"[ERROR] {type(e).__name__}: {str(e)[:80]}")


async def run_simulation() -> None:
    """Run the 22-second telemetry simulation at 50Hz."""
    print("=" * 60)
    print("Civic-Link Telemetry Simulator")
    print("=" * 60)
    print(f"Driver ID: {DRIVER_ID}")
    print(f"Endpoint: {API_ENDPOINT}")
    print(f"Duration: {TOTAL_DURATION}s | Rate: {SAMPLE_RATE_HZ}Hz | Total samples: {TOTAL_DURATION * SAMPLE_RATE_HZ}")
    print("-" * 60)
    print("Phases:")
    print(f"  0.00s - {PHASE_1_END:.2f}s : CRUISING (normal driving)")
    print(f"  {PHASE_1_END:.2f}s - {PHASE_2_END:.2f}s : AGGRESSIVE SWERVE (anomaly)")
    print(f"  {PHASE_2_END:.2f}s - {TOTAL_DURATION:.2f}s : RECOVERY (EMA recovery)")
    print("=" * 60)
    print()
    
    connector = aiohttp.TCPConnector(limit=10, enable_cleanup_closed=True)
    timeout = aiohttp.ClientTimeout(total=5, connect=2)
    
    async with aiohttp.ClientSession(
        connector=connector,
        timeout=timeout,
        headers={"Content-Type": "application/json"}
    ) as session:
        start_time = asyncio.get_event_loop().time()
        sequence = 0
        
        while True:
            elapsed = asyncio.get_event_loop().time() - start_time
            
            if elapsed >= TOTAL_DURATION:
                break
            
            # Fire-and-forget with controlled concurrency
            await transmit_sample(session, elapsed, sequence)
            
            sequence += 1
            
            # Maintain strict 50Hz timing
            next_sample_time = start_time + (sequence * SAMPLE_INTERVAL)
            sleep_duration = next_sample_time - asyncio.get_event_loop().time()
            
            if sleep_duration > 0:
                await asyncio.sleep(sleep_duration)
    
    print()
    print("=" * 60)
    print(f"Simulation complete. Total samples transmitted: {sequence}")
    print("=" * 60)


if __name__ == "__main__":
    try:
        asyncio.run(run_simulation())
    except KeyboardInterrupt:
        print("\n[ABORT] Simulation interrupted by user")
    except Exception as e:
        print(f"\n[FATAL] {type(e).__name__}: {e}")
