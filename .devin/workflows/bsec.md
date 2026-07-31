---
auto_execution_mode: 3
description: Backend testing and security
---
Agent Mission: Backend Reliability & Safety Verification

PROJECT CONTEXT:
You are a Senior Backend Engineer for the Civic-Link Traffic-pooling project. This is a zero-liability, privacy-first infrastructure that optimizes commutes for 3D-rendering and AI-ML integration.  

GOAL STATE:
The command docker compose exec -u root api env PYTHONPATH=. python app/safety_stress_test.py must return:

    Total matches found: > 0.  

    Male drivers matched: 0 ✗.  

    Test passed: True ✅.  

📋 THE "GOLDEN RULES" (DO NOT DEVIATE)
1. Identity & Privacy (The "No-Email" Rule)

    The database must not store raw email addresses.  

    The User model uses email_hash (SHA-256) and email_domain.  

    Any code or test accessing user.email is broken and must be updated to use the hashed fields.  

2. Authentication (The 72-Byte Wall)

    Bcrypt has a hard limit of 72 bytes.  

    You must truncate passwords at the first line of get_password_hash and verify_password using: password.encode('utf-8')[:72].decode('utf-8', 'ignore').  

3. Data Integrity & Constraints

    Timezones: Use naive datetimes only (datetime.now()). PostgreSQL is configured as TIMESTAMP WITHOUT TIME ZONE.  

    Mandatory Fields: Every user in the seed must have a non-null company_name and employee_id.  

    Seeding: Ensure app/seed_kphb.py populates the database correctly before running matches.  

4. SQL Architecture (Positional Only)

    The match_service.py must use strictly positional parameters ($1, $2, etc.).  

    Mixing named parameters (like :offer_origin) with positional ones will crash the asyncpg driver.  

5. Async Lifecycle (Greenlet Safety)

    Every database I/O (commit, rollback, close) must be awaited.  

    If a transaction fails, you must await session.rollback() and await session.close() to prevent Transaction Poisoning.  

🔄 ITERATIVE TROUBLESHOOTING LOOP

    EXECUTE TEST: Run the safety stress test command.  

    DIAGNOSE:

        If AttributeError: email, fix the test's reporting logic.  

        If InFailedSQLTransactionError, fix the missing await or the commute_id linkage.  

        If ProgrammingError: syntax error at or near ":", fix the SQL parameters to be 100% positional.  

    REPAIR: Apply the surgical fix to the code.

    CLEAN PIPES: If you change dependencies, run docker compose down && docker compose up -d --build.

    REPEAT: Return to Step 1 until Test passed: True is achieved.  

🚀 Final Instructions for the Agent

When you start, check the /app/safety_audit.log or the console output to find the current crash point. Solve it using the rules above, then immediately re-test. Your job is not done until the safety report confirms zero male matches for women-only requests.