---
auto_execution_mode: 3
description: Flutter phase 4
---
# WORKFLOW: flutterint (Phase 4 Execution Protocol)

## PHASE SETUP
1. Identify the current active milestone from the `backlog`.
2. Ensure Flutter environment is clean (`flutter clean`, `flutter pub get`).
3. Ensure local Docker backend is running for integration testing.

## STEP 1: CODE GENERATION (KIMI K2.5)
Feed Kimi the precise architectural prompt for the current milestone. 
*Constraint Checklist for Kimi:*
[ ] No UI code unless explicitly requested.
[ ] Strictly enforce Zero-Liability rules (no raw PII transmission).
[ ] Use production-ready error handling (DioExceptions, Isolate crashes).
[ ] Output only clean, commented Dart files.

## STEP 2: IMPLEMENTATION (SOLO DEV)
1. Copy Kimi's output into the respective `lib/` directories.
2. Resolve any missing package imports in `pubspec.yaml`.
3. Run `flutter analyze` to ensure zero syntax or linting errors.

## STEP 3: VERIFICATION (GEMINI CLI)
Feed Gemini CLI the testing prompt. 
*Gemini CLI Mission:*
1. Execute a headless Dart test script or trigger the specific function via CLI.
2. Monitor the backend Docker logs to verify the network payload matches the privacy/performance constraints.
3. Output a Pass/Fail verdict with a technical summary.

## STEP 4: ITERATION & ADVANCEMENT
*   **IF FAIL:** Pipe the Gemini CLI error report directly back to Kimi with the prompt: "Fix these errors adhering to the original constraints." Repeat Steps 2-3.
*   **IF PASS:** Mark milestone complete in `backlog`. Move to the next milestone.