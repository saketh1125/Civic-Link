---
auto_execution_mode: 3
description: Overall tasks
---
# WORKFLOW: backlog (Civic-Link Master Roadmap)

## ✅ PHASE 1: Data & Privacy Layer (COMPLETED)
- [x] Define PostGIS schema with TIMESTAMP WITHOUT TIME ZONE.
- [x] Implement Bcrypt 72-byte truncation limit.
- [x] Eradicate raw emails (implement email_hash & email_domain).

## ✅ PHASE 2: Matching Engine & Safety (COMPLETED)
- [x] Build positional-only SQL parameter binding ($1, $2).
- [x] Lock down async lifecycle (`greenlet_spawn` / `rollback` fixes).
- [x] Verify Hard-Reject Safety Logic (0 male drivers matched for women-only requests).

## ✅ PHASE 3: Telemetry Engine (COMPLETED)
- [x] Build EMA Civic Score backend algorithm (S_new = S_old * 0.85 + event * 0.15).
- [x] Ingest 50Hz JSON payloads via asyncio without timeouts.
- [x] Verify score degradation on swerves and mathematical recovery.

---

## 🚀 PHASE 4: Flutter Integration (ACTIVE - Use `flutterint` workflow)

**Milestone 4.1: Zero-Liability Auth Handshake** (<- WE ARE HERE)
- [ ] Kimi: Generate `privacy_crypto.dart` (SHA-256 hashing) and `auth_service.dart` (Dio network calls).
- [ ] Gemini CLI: Test login execution to verify raw email is NEVER sent to the backend.

**Milestone 4.2: 50Hz IMU Telemetry Engine (Critical Path)**
- [ ] Kimi: Generate `telemetry_isolate.dart` using `sensors_plus`.
- [ ] Kimi: Implement buffer logic (batch 10 readings per 200ms) to reduce HTTP overhead while maintaining 50Hz density.
- [ ] Gemini CLI: Verify the Flutter Isolate can transmit data without blocking the main UI thread.

**Milestone 4.3: Real-Time Civic Score UI**
- [ ] Kimi: Build a dynamic dashboard using `fl_chart` and `flutter_riverpod` or `bloc`.
- [ ] Kimi: Map score thresholds to UI colors (Green/Cruising, Yellow/Warning, Red/Aggressive).
- [ ] Gemini CLI: Verify UI state updates seamlessly when the backend pushes a new score.

---

## 🏁 PHASE 5: The Police Pitch Demo Prep
- [ ] End-to-End System Test (Live phone -> Backend -> Database -> Live UI update).
- [ ] Polish UI transitions and error states.
- [ ] Final architecture freeze.