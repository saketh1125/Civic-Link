import time
import json
import requests
import uuid
from datetime import datetime, timezone

def emulate_telemetry_batch(user_id, token, readings_count=10, broken_schema=True):
    base_url = 'http://localhost:8000'
    endpoint = '/api/v1/telemetry/telemetry' # Correcting path but test schema
    
    readings = []
    for _ in range(readings_count):
        if broken_schema:
            # CURRENT DART SCHEMA (As found in telemetry_isolate.dart)
            reading = {
                'timestamp': datetime.now(timezone.utc).isoformat(),
                'accel': {'x': 0.1, 'y': -0.2, 'z': 9.8},
                'gyro': {'x': 0.05, 'y': 0.02, 'z': 2.1}
            }
        else:
            # CORRECTED BACKEND SCHEMA
            reading = {
                'timestamp_ms': int(time.time() * 1000),
                'gyro_x': 0.05,
                'gyro_y': 0.02,
                'gyro_z': 2.1,
                'accel_x': 0.1,
                'accel_y': -0.2,
                'accel_z': 9.8
            }
        readings.append(reading)
    
    if broken_schema:
        # CURRENT DART PAYLOAD (Missing user_id, nested readings)
        payload = {'readings': readings}
    else:
        # CORRECTED PAYLOAD
        payload = {
            'user_id': user_id,
            'match_id': str(uuid.uuid4()),
            'readings': readings
        }
    
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    print(f"Transmitting JSON Batch ({len(readings)} readings):")
    print(json.dumps(payload, indent=2)[:500] + "...")
    
    start_time = time.time()
    resp = requests.post(f"{base_url}{endpoint}", json=payload, headers=headers)
    end_time = time.time()
    
    print(f"HTTP Status: {resp.status_code}")
    if resp.status_code != 202:
        print(f"Error Response: {resp.text}")
    
    return resp.status_code, end_time - start_time

def main():
    # 1. Setup - Login to get real token
    base_url = 'http://localhost:8000'
    login_payload = {
        "email_hash": "189e7834acc81d6bf9d872bf29917e57960b199d304d1c3ee9802ea72f89ab06",
        "email_domain": "hyderabadpolice.gov.in",
        "password": "securePassword123"
    }
    resp = requests.post(f"{base_url}/api/v1/auth/login/access-token", json=login_payload)
    if resp.status_code != 200:
        print("Login failed. Seed data might be missing.")
        return
    
    token = resp.json()['access_token']
    
    # Get user_id from /me
    resp = requests.get(f"{base_url}/api/v1/auth/me", headers={'Authorization': f'Bearer {token}'})
    user_id = resp.json()['id']
    print(f"Verified User ID: {user_id}")

    # 2. Run Emulation (1.5 seconds)
    print("\n--- VECTOR A: BATCHING VERIFICATION (Emulated) ---")
    batches_sent = 0
    start_test = time.time()
    
    # We send a batch every 200ms for 1.5 seconds
    while time.time() - start_test < 1.5:
        status, duration = emulate_telemetry_batch(user_id, token, broken_schema=False)
        batches_sent += 1
        time.sleep(0.2)
    
    print(f"\nTotal batches sent: {batches_sent}")
    print("Verification complete.")

if __name__ == "__main__":
    main()
