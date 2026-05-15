import hashlib
import requests
import json

def hash_email(email):
    normalized = email.lower().strip()
    at_index = normalized.rfind('@')
    domain = normalized[at_index + 1:]
    email_hash = hashlib.sha256(normalized.encode()).hexdigest()
    return email_hash, domain

def main():
    base_url = 'http://localhost:8000'
    raw_email = 'officer@hyderabadpolice.gov.in'
    password = 'securePassword123'
    
    email_hash, email_domain = hash_email(raw_email)
    
    payload = {
        'email_hash': email_hash,
        'email_domain': email_domain,
        'password': password,
        'phone_number': '+91-100',
        'full_name': 'Officer John',
        'gender': 'male',
        'company_name': 'Hyderabad Police',
        'employee_id': 'HP-1234',
    }
    
    print("--- EMULATED DART PAYLOAD ---")
    print(json.dumps(payload, indent=2))
    
    # Registration
    try:
        # Check if user already exists, delete if so to ensure 201
        # (This is just for clean test execution)
        
        resp = requests.post(f"{base_url}/api/v1/auth/register", json=payload)
        print(f"Registration Status: {resp.status_code}")
        
        # Login
        login_payload = {
            'email_hash': email_hash,
            'email_domain': email_domain,
            'password': password,
        }
        resp_login = requests.post(f"{base_url}/api/v1/auth/login/access-token", json=login_payload)
        print(f"Login Status: {resp_login.status_code}")
        if resp_login.status_code == 200:
            token = resp_login.json().get('access_token')
            print(f"Token stored: {token[:15]}...")
            
    except Exception as e:
        print(f"Handshake failed: {e}")

if __name__ == "__main__":
    main()
