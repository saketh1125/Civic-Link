# Civic-Link DPI — Flutter UI Specification

> **Version:** 1.0  
> **Date:** 2026-05-16  
> **Status:** Planning — no code changes in this session

---

## Step 0 — Codebase Inventory

### Existing Screens (2)
| File | Screen | Notes |
|------|--------|-------|
| `lib/main.dart` | `LoginScreen` | Inline class, 431 lines. Full login form with email/password, server error banner, loading state. Uses `authProvider.notifier.login()`. |
| `lib/ui/screens/dashboard_screen.dart` | `DashboardScreen` | 359 lines. Civic score display (animated number, score bar, fl_chart line chart). Calls `civicScoreProvider.notifier.startTelemetry()`. No quick actions, no navigation. |

### Missing Screens (10)
`RegistrationScreen`, `CommuteCreateScreen`, `CommuteSearchScreen`, `CommuteDetailScreen`, `MyCommutesScreen`, `MyMatchesScreen`, `MatchDetailScreen`, `RatingScreen`, `ProfileScreen`, `SettingsScreen`

### Existing Providers (3)
| Provider | Type | State Shape |
|----------|------|-------------|
| `authServiceProvider` | `Provider<AuthService>` | Singleton service instance |
| `authProvider` | `NotifierProvider<AuthNotifier, AuthState>` | `{userId?, accessToken?, isAuthenticated}` |
| `civicScoreProvider` | `NotifierProvider<CivicScoreNotifier, CivicScoreState>` | `{currentScore, scoreHistory[]}` |

### Existing Services (2)
| Service | Purpose |
|---------|---------|
| `AuthService` | Zero-Liability auth (SHA-256 email hashing), Dio HTTP client, `FlutterSecureStorage` persistence, 401 interceptor, `checkSessionValidity()` |
| `TelemetryService` | 50Hz IMU isolate, batch transmission to `/telemetry/telemetry`, score ingestion to `/civic-score/ingest`, retry queue |

### Existing Models/DTOs (Flutter)
| Class | Location |
|-------|----------|
| `AuthState` | `providers/auth_provider.dart` |
| `AuthResult<T>` | `services/auth_service.dart` |
| `LoginResponse` | `services/auth_service.dart` |
| `RegisterResponse` | `services/auth_service.dart` |
| `CivicScoreState` | `providers/civic_score_provider.dart` |
| `IMUReading` | `services/telemetry_isolate.dart` |
| `TelemetryBatch` | `services/telemetry_isolate.dart` |
| `TelemetryCommand` (sealed) | `services/telemetry_isolate.dart` |
| `TelemetryStatus` (sealed) | `services/telemetry_isolate.dart` |

### Shared Widgets
**None.** No `lib/ui/widgets/` directory exists.

### Dependencies (`pubspec.yaml`)
| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^3.3.1 | State management |
| `dio` | ^5.9.2 | HTTP client |
| `crypto` | ^3.0.7 | SHA-256 email hashing |
| `flutter_secure_storage` | ^10.1.0 | Token persistence |
| `sensors_plus` | ^7.0.0 | IMU sensor access |
| `fl_chart` | ^1.2.0 | Score chart |
| `cupertino_icons` | ^1.0.8 | Icon font |

**Notable absences:** No navigation library (`go_router`, `auto_route`), no maps package, no form validation package, no date/time picker package.

### Available Backend Endpoints (18)
| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/v1/auth/register` | No | Register user |
| POST | `/api/v1/auth/login/access-token` | No | Login |
| POST | `/api/v1/auth/verify` | Yes | Verify account (placeholder) |
| GET | `/api/v1/auth/me` | Yes | Get profile |
| POST | `/api/v1/telemetry/telemetry` | Yes | Submit IMU batch |
| POST | `/api/v1/commutes` | Yes | Create commute offer |
| GET | `/api/v1/commutes/my` | Yes | List driver's commutes |
| GET | `/api/v1/commutes/{id}` | Yes | Commute details |
| POST | `/api/v1/commutes/{id}/cancel` | Yes | Cancel commute |
| POST | `/api/v1/commutes/offers` | Yes | Create passenger offer |
| POST | `/api/v1/matches/{commute_id}/request` | Yes | Request match |
| POST | `/api/v1/matches/{match_id}/confirm` | Yes | Confirm match |
| GET | `/api/v1/matches/my` | Yes | List user's matches |
| GET | `/api/v1/matches/{match_id}` | Yes | Match details |
| POST | `/api/v1/matches/{match_id}/rate` | Yes | Rate match |
| POST | `/api/v1/civic-score/ingest` | Yes | Ingest telemetry samples |
| GET | `/api/v1/civic-score/me` | Yes | Get civic score |
| GET | `/api/v1/civic-score/history` | Yes | Score history |
| GET | `/health` | No | Health check |

---

## 1. App Architecture Overview

### Navigation Strategy

**Current:** Manual `Navigator.pushReplacement` with `MaterialPageRoute`. No named routes, no `go_router`, no `Navigator 2.0`.

```dart
// LoginScreen → DashboardScreen
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => const DashboardScreen()),
);
```

**Recommendation:** Introduce `go_router` for the full UI build. It provides:
- Named routes with type-safe parameters (`/commute/:id`)
- Redirect guards for auth (replaces manual token checks)
- Deep link support
- Declarative routing that scales to 12+ screens

Until `go_router` is added, the pattern is: each screen constructs the next screen widget directly and uses `Navigator.push` or `Navigator.pushReplacement`.

### State Management Pattern

**Riverpod 3.x** with `NotifierProvider` for both auth and civic score.

| Screen | Consumed Providers |
|--------|-------------------|
| `LoginScreen` | `authProvider` |
| `DashboardScreen` | `authProvider`, `civicScoreProvider` |

All providers are scoped at the root `ProviderScope`. No `ProviderScope` overrides or testing scopes are configured.

### Folder Structure Convention

```
civic_link/lib/
├── main.dart              # Entry point, MyApp, LoginScreen (inline), theme constants
├── providers/
│   ├── auth_provider.dart
│   └── civic_score_provider.dart
├── services/
│   ├── auth_service.dart
│   └── telemetry_isolate.dart
├── ui/
│   └── screens/
│       └── dashboard_screen.dart
└── utils/
    └── privacy_crypto.dart
```

**Missing directories:** `lib/models/`, `lib/ui/widgets/`, `lib/utils/` (only `privacy_crypto.dart` exists).

### Theme and Design Tokens

Defined in `main.dart` as module-level constants:

| Token | Value | Usage |
|-------|-------|-------|
| `kPrimaryBlack` | `#0A0A0A` | Scaffold background, button foreground |
| `kAccentGreen` | `#00E676` | CTA buttons, score color (≥90), accent |
| `kSecondaryGrey` | `#1A1A2E` | Secondary surfaces |
| `kHintGrey` | `#6B6B80` | Hint text, icons |
| `kInputFill` | `#141428` | Input field background |

Dashboard defines its own palette:
| Token | Value | Usage |
|-------|-------|-------|
| `kDashboardBackground` | `#0A0A0A` | Dashboard scaffold |
| `kCivicScoreGreen` | `#00E676` | Score ≥ 90 (CRUISING) |
| `kCivicScoreYellow` | `#FFFFEA00` | Score 70–89 (WARNING) |
| `kCivicScoreRed` | `#FFFF1744` | Score < 70 (ALERT) |

**Theme configuration:** `ThemeData.dark().copyWith()` with custom `InputDecorationTheme` (filled, 12px radius), `ElevatedButtonThemeData` (green, 52px height, bold), and `TextTheme` (headlineLarge 42px, headlineMedium 22px).

**Note:** `kBaseUrl` is hardcoded as `'http://192.168.1.9:8000'` — see Section 9 for flags.

### Auth Guard Pattern

**Current:** `DashboardScreen.initState` checks:
1. `authState.accessToken != null && !isEmpty` → if empty, logout + redirect to `LoginScreen`
2. `checkSessionValidity()` (local JWT decode) → if expired, logout + redirect to `LoginScreen`
3. Only then starts telemetry

There is no centralized auth guard. Each protected screen must repeat this pattern.

---

## 2. Screen Inventory

| # | Screen | Route | Auth Required | Status | Provider(s) | Backend Endpoint(s) |
|---|--------|-------|--------------|--------|-------------|---------------------|
| 1 | `LoginScreen` | `/login` (implicit) | No | **Exists** — full | `authProvider` | `POST /auth/login/access-token` |
| 2 | `DashboardScreen` | `/dashboard` (implicit) | Yes | **Exists** — partial (score only, no actions) | `authProvider`, `civicScoreProvider` | `POST /civic-score/ingest` (via telemetry) |
| 3 | `RegistrationScreen` | `/register` | No | **Missing** | `authProvider` | `POST /auth/register` |
| 4 | `CommuteCreateScreen` | `/commute/create` | Yes | **Missing** | `commuteProvider` (new) | `POST /commutes` |
| 5 | `CommuteSearchScreen` | `/commute/search` | Yes | **Missing** | `commuteSearchProvider` (new) | **BACKEND BLOCKER** — no search endpoint |
| 6 | `CommuteDetailScreen` | `/commute/:id` | Yes | **Missing** | `commuteDetailProvider` (new) | `GET /commutes/{id}`, `POST /matches/{commute_id}/request` |
| 7 | `MyCommutesScreen` | `/commutes/my` | Yes | **Missing** | `myCommutesProvider` (new) | `GET /commutes/my`, `POST /commutes/{id}/cancel` |
| 8 | `MyMatchesScreen` | `/matches/my` | Yes | **Missing** | `matchProvider` (new) | `GET /matches/my`, `POST /matches/{match_id}/confirm` |
| 9 | `MatchDetailScreen` | `/matches/:id` | Yes | **Missing** | `matchDetailProvider` (new) | `GET /matches/{match_id}`, `POST /matches/{match_id}/rate` |
| 10 | `RatingScreen` | `/matches/:id/rate` | Yes | **Missing** | `matchProvider` (new) | `POST /matches/{match_id}/rate` |
| 11 | `ProfileScreen` | `/profile` | Yes | **Missing** | `authProvider`, `civicScoreProvider` | `GET /auth/me`, `GET /civic-score/history`, **BACKEND BLOCKER** — `PUT /auth/me` missing |
| 12 | `SettingsScreen` | `/settings` | Yes | **Missing** | `authProvider` | None (local only + `logout()`) |

---

## 3. Screen Specifications

### 3.1 LoginScreen

**Route:** `/login` (implicit via `MyApp.home`)  
**Status:** ✅ Exists — audited  
**File:** `lib/main.dart:194–431`

**Audit against spec:**
- ✅ Email field with validation (regex `^[^@]+@[^@]+\.[^@]+$`)
- ✅ Password field (obscureText)
- ✅ Server error banner (red container with icon)
- ✅ Loading state (CircularProgressIndicator in button)
- ✅ Uses `authProvider.notifier.login()` (not direct `AuthService`)
- ✅ Navigates to `DashboardScreen` on success via `pushReplacement`
- ❌ No "Forgot password" link (backend has no password reset endpoint either)
- ❌ No link to RegistrationScreen (doesn't exist yet)
- ❌ No "Remember me" toggle (tokens are persisted automatically via `FlutterSecureStorage`)

**Missing features to add later:** Registration link, forgot password (when backend supports).

---

### 3.2 RegistrationScreen

**Route:** `/register`  
**Status:** ❌ Missing  
**Provider:** `authProvider` (existing `register()` method already implemented)

**Fields:**
| Field | Type | Validation |
|-------|------|------------|
| Full Name | Text | Required, min 2 chars |
| Email | Text | Required, valid format |
| Password | Password | Required, min 8 chars |
| Phone Number | Phone | Required, format `+XX-XXXXX-XXXXX` |
| Gender | Dropdown | Required: male / female / undisclosed |
| Company Name | Text | Required |
| Employee ID | Text | Optional |

**API Call:** `POST /api/v1/auth/register` via `authProvider.notifier.register()`

**Flow:**
1. User fills form → submit
2. On success: show "Account created — verify your email" screen (verification is placeholder flow)
3. Navigate to `LoginScreen`

**Note:** `AuthNotifier.register()` already exists at `auth_provider.dart:77–101`. It calls `AuthService.register()` which hashes email via `PrivacyCrypto`. After registration, `isAuthenticated` is set to `false` (user must login separately).

---

### 3.3 DashboardScreen

**Route:** `/dashboard` (implicit via `MyApp.home`)  
**Status:** ⚠️ Exists — partial  
**File:** `lib/ui/screens/dashboard_screen.dart`

**Audit against spec:**
- ✅ Civic score animated number display (TweenAnimationBuilder, 300ms)
- ✅ Color-coded thresholds (Green ≥90, Yellow ≥70, Red <70)
- ✅ Score bar indicator (horizontal progress bar)
- ✅ fl_chart line chart with 20-point history
- ✅ Auth guard in `initState` (token check + expiry check)
- ✅ Telemetry lifecycle (`startTelemetry` on load)
- ❌ No score tier badge text (backend returns `excellent/good/fair/poor/critical`, dashboard uses `CRUISING/WARNING/ALERT`)
- ❌ No recent trip count
- ❌ No quick actions (Find Ride, Offer Ride buttons)
- ❌ No navigation to other screens
- ❌ No profile/settings access
- ❌ No logout button

**Required additions:**
- Quick action buttons: "Offer Ride" → `CommuteCreateScreen`, "Find Ride" → `CommuteSearchScreen`
- Bottom navigation bar or drawer for: My Commutes, My Matches, Profile, Settings
- Score tier badge using backend tier labels
- Trip count from `GET /civic-score/me` (currently not called — telemetry provides local score only)

---

### 3.4 CommuteCreateScreen

**Route:** `/commute/create`  
**Status:** ❌ Missing  
**Provider:** `commuteProvider` (new `AsyncNotifier`)

**Fields:**
| Field | Type | Notes |
|-------|------|-------|
| Origin Address | Text | Manual text entry (no map yet) |
| Destination Address | Text | Manual text entry |
| Departure Date | Date picker | Default: today |
| Departure Time | Time picker | Default: next hour |
| Available Seats | Number stepper | 1–total_seats, default 1 |
| Total Seats | Number stepper | 1–8, default 4 |
| Women Only | Toggle switch | Default: false |
| Commute Type | Dropdown | one_time / recurring |
| Recurring Days | Multi-select | Only if recurring (Mon–Fri) |

**API Call:** `POST /api/v1/commutes`

**Request shape:**
```json
{
  "origin_lat": 17.4930,
  "origin_lon": 78.4020,
  "destination_lat": 17.4430,
  "destination_lon": 78.3770,
  "origin_address": "KPHB Phase 3",
  "destination_address": "Mindspace",
  "departure_date": "2026-04-16",
  "departure_time": "09:00:00",
  "available_seats": 2,
  "total_seats": 4,
  "is_women_only": false,
  "commute_type": "one_time"
}
```

**BACKEND BLOCKER:** The endpoint requires `origin_lat`, `origin_lon`, `destination_lat`, `destination_lon` but the UI has no map picker. **Resolution:** Use hardcoded KPHB coordinates as defaults, or add a simple map package later.

**Navigation:** On success → `MyCommutesScreen` or back to `DashboardScreen`.

---

### 3.5 CommuteSearchScreen

**Route:** `/commute/search`  
**Status:** ❌ Missing  
**Provider:** `commuteSearchProvider` (new `AsyncNotifier`)

**BACKEND BLOCKER:** No `GET /commutes/search` endpoint exists. The closest available endpoint is `GET /commutes/my` (driver's own commutes only).

**Filter inputs (when backend exists):**
| Filter | Type |
|--------|------|
| Origin area | Text |
| Destination area | Text |
| Date | Date picker |
| Time window | Range (±30 min) |

**Results list item:** Driver name, CivicScore badge, route summary, seats available, departure time.

**Navigation:** Tap result → `CommuteDetailScreen`.

**Workaround for Phase 2:** Use `GET /commutes/my` to show the user's own commutes as a placeholder until search endpoint is built.

---

### 3.6 CommuteDetailScreen

**Route:** `/commute/:id`  
**Status:** ❌ Missing  
**Provider:** `commuteDetailProvider` (new `AsyncNotifier`)

**API Calls:**
- `GET /api/v1/commutes/{id}` — load commute details
- `POST /api/v1/matches/{commute_id}/request` — request match (primary action)

**Content:**
- Commute info: origin, destination, date, time, seats
- Driver profile: name, gender, CivicScore badge
- Safety indicators: women-only badge
- Action button: "Request Match" (disabled if no seats, or if safety violation)

**Error handling:** 403 → show "Safety restriction: this commute is women-only"

---

### 3.7 MyCommutesScreen

**Route:** `/commutes/my`  
**Status:** ❌ Missing  
**Provider:** `myCommutesProvider` (new `AsyncNotifier`)

**API Calls:**
- `GET /api/v1/commutes/my` — list commutes
- `POST /api/v1/commutes/{id}/cancel` — cancel action

**Layout:** Tab view or segmented control:
- Tab 1: "Offered Rides" (commutes user created as driver)
- Tab 2: "Requested Rides" (commute_offers user created as passenger)

**List item:** Route summary, status badge (active/pending/completed/cancelled), date, matched passenger count.

**Actions:** Cancel (driver only), View Details → `CommuteDetailScreen`.

---

### 3.8 MyMatchesScreen

**Route:** `/matches/my`  
**Status:** ❌ Missing  
**Provider:** `matchProvider` (new `AsyncNotifier`)

**API Calls:**
- `GET /api/v1/matches/my` — list matches
- `POST /api/v1/matches/{match_id}/confirm` — confirm action (driver)

**Layout:** Filtered by status tabs: Pending, Confirmed, In Progress, Completed.

**List item:** Co-passenger name, route, status, departure time, CivicScore badge.

**Actions:**
- Pending → "Confirm" (driver) / "Waiting" (passenger)
- Confirmed → "View Details" → `MatchDetailScreen`
- Completed → "Rate" → `RatingScreen`

---

### 3.9 MatchDetailScreen

**Route:** `/matches/:id`  
**Status:** ❌ Missing  
**Provider:** `matchDetailProvider` (new `AsyncNotifier`)

**API Call:** `GET /api/v1/matches/{match_id}`

**Content:**
- Match status badge
- Co-passenger info (name, CivicScore)
- Route details (origin, destination)
- Pickup radius in meters
- Safety flags (women-only status at match time)

**Actions by status:**
| Status | Driver Action | Passenger Action |
|--------|--------------|-----------------|
| pending | Confirm / Cancel | Cancel |
| confirmed | Start trip | View details |
| in_progress | Complete | View details |
| completed | Rate | Rate → `RatingScreen` |
| cancelled | — | — |

---

### 3.10 RatingScreen

**Route:** `/matches/:id/rate`  
**Status:** ❌ Missing  
**Provider:** `matchProvider` (reuse from MyMatches)

**API Call:** `POST /api/v1/matches/{match_id}/rate`

**Fields:**
| Field | Type | Validation |
|-------|------|------------|
| Driver Rating | Star selector (1–5) | Required |
| Driver Review | Text field | Optional, max 1000 chars |
| Passenger Rating | Star selector (1–5) | Required (if driver) |
| Passenger Review | Text field | Optional, max 1000 chars |

**Flow:** Submit → show "Thank you" → navigate to `DashboardScreen`.

---

### 3.11 ProfileScreen

**Route:** `/profile`  
**Status:** ❌ Missing  
**Providers:** `authProvider`, `civicScoreProvider`

**API Calls:**
- `GET /api/v1/auth/me` — load profile
- `GET /api/v1/civic-score/history` — chart data
- **BACKEND BLOCKER:** `PUT /api/v1/auth/me` — edit profile (does not exist)

**Content:**
- Name, email domain, verification status badge
- CivicScore history chart (reuse fl_chart from DashboardScreen)
- Score tier, total trips, swerve count, speeding count

**Edit mode:** Blocked until `PUT /auth/me` endpoint exists. Show profile as read-only with "Edit" button disabled + tooltip "Coming soon".

---

### 3.12 SettingsScreen

**Route:** `/settings`  
**Status:** ❌ Missing  
**Provider:** `authProvider`

**Content:**
- Logout button → `authProvider.notifier.logout()` → navigate to `LoginScreen`
- Notification preferences (local toggle only — no backend endpoint)
- Delete account placeholder (links to anonymization flow — backend has `scripts/anonymize_data.py`)
- App version display (`1.0.0+1` from `pubspec.yaml`)

---

## 4. Riverpod Provider Plan

### Existing Providers (reuse)

| Provider | Type | State | Methods |
|----------|------|-------|---------|
| `authProvider` | `NotifierProvider<AuthNotifier, AuthState>` | `{userId?, accessToken?, isAuthenticated}` | `login()`, `register()`, `logout()`, `restoreSession()`, `checkSessionValidity()` |
| `civicScoreProvider` | `NotifierProvider<CivicScoreNotifier, CivicScoreState>` | `{currentScore, scoreHistory[]}` | `startTelemetry()`, `stopTelemetry()`, `updateScore()`, `refreshScore()`, `reset()`, `setHistory()` |

### New Providers (create)

| Provider | Type | State Shape | Methods | Depends On |
|----------|------|-------------|---------|------------|
| `commuteProvider` | `AsyncNotifierProvider` | `CommuteCreateState {form, isLoading, error}` | `createCommute()` | `authProvider` (for token) |
| `commuteSearchProvider` | `AsyncNotifierProvider` | `List<CommuteSummary>` | `search(origin, dest, date)`, `refresh()` | `authProvider` |
| `commuteDetailProvider` | `Family AsyncNotifierProvider` | `CommuteDetail {commute, driver, isLoading}` | `load(id)`, `requestMatch()` | `authProvider` |
| `myCommutesProvider` | `AsyncNotifierProvider` | `MyCommutes {offered[], requested[]}` | `load()`, `cancel(id)` | `authProvider` |
| `matchProvider` | `AsyncNotifierProvider` | `MatchList {items[], isLoading}` | `load()`, `confirm(id)`, `cancel(id)` | `authProvider` |
| `matchDetailProvider` | `Family AsyncNotifierProvider` | `MatchDetail {match, isLoading}` | `load(id)`, `rate(driverRating, passengerRating, reviews)` | `authProvider` |
| `profileProvider` | `AsyncNotifierProvider` | `Profile {user, score, history[]}` | `load()`, `refreshScoreHistory()` | `authProvider`, `civicScoreProvider` |

### Provider Dependency Graph

```
authProvider (root)
├── commuteProvider
├── commuteSearchProvider
├── commuteDetailProvider
├── myCommutesProvider
├── matchProvider
├── matchDetailProvider
└── profileProvider
    └── civicScoreProvider (root)
```

All new providers depend on `authProvider` for the JWT token. The `civicScoreProvider` is independent but consumed by `profileProvider` for history data.

---

## 5. Shared Widget Library

All widgets are to be created in `lib/ui/widgets/`.

### CivicScoreBadge

| Prop | Type | Description |
|------|------|-------------|
| `score` | `double` | Score value (0–100) |
| `size` | `CivicScoreBadgeSize` | small / medium / large |
| `showTier` | `bool` | Whether to display tier label |

**Used by:** DashboardScreen, CommuteSearchScreen, CommuteDetailScreen, MyMatchesScreen, ProfileScreen

**Design:** Circular badge with score number, color-coded (Green ≥90, Yellow ≥70, Red <70). Small: 32px, Medium: 48px, Large: 72px.

---

### CommuteCard

| Prop | Type | Description |
|------|------|-------------|
| `commute` | `CommuteSummary` | Commute data |
| `onTap` | `VoidCallback?` | Tap handler |
| `showDriverScore` | `bool` | Whether to show CivicScore badge |

**Used by:** CommuteSearchScreen, MyCommutesScreen

**Design:** Card with origin → destination arrow, departure time, seats badge, women-only indicator, driver score badge.

---

### MatchCard

| Prop | Type | Description |
|------|------|-------------|
| `match` | `MatchSummary` | Match data |
| `onTap` | `VoidCallback?` | Tap handler |
| `actions` | `List<Widget>` | Contextual action buttons |

**Used by:** MyMatchesScreen

**Design:** Card with passenger/driver name, status chip (pending/confirmed/completed), route summary, action buttons row.

---

### LoadingOverlay

| Prop | Type | Description |
|------|------|-------------|
| `isLoading` | `bool` | Whether to show overlay |
| `message` | `String?` | Optional loading text |

**Used by:** All screens with async operations

**Design:** Full-screen semi-transparent black overlay with centered CircularProgressIndicator and optional text.

---

### ErrorBanner

| Prop | Type | Description |
|------|------|-------------|
| `message` | `String` | Error text |
| `onDismiss` | `VoidCallback?` | Dismiss handler |
| `type` | `ErrorType` | error / warning / info |

**Used by:** All screens with form submission or API calls

**Design:** Colored banner (red for error, yellow for warning, blue for info) with icon and dismiss button.

---

### AuthGuard

| Prop | Type | Description |
|------|------|-------------|
| `child` | `Widget` | Protected screen content |
| `redirectRoute` | `String` | Route to redirect to (default: `/login`) |

**Used by:** All protected screens (Dashboard, CommuteCreate, CommuteSearch, CommuteDetail, MyCommutes, MyMatches, MatchDetail, Rating, Profile, Settings)

**Behavior:** Watches `authProvider`. If `!isAuthenticated`, redirects to login. If token is expired, calls `logout()` then redirects.

---

## 6. Navigation Flow

### ASCII Navigation Map

```
[LoginScreen] ──────────────────────────────────────────────┐
     │                                                       │
     │ (login success)                                       │
     ▼                                                       │
[DashboardScreen]                                            │
     │                                                       │
     ├── [Offer Ride] ──► [CommuteCreateScreen] ──► [MyCommutesScreen]
     │                                                           │
     ├── [Find Ride] ──► [CommuteSearchScreen] ──► [CommuteDetailScreen]
     │                                                           │
     │                                                           ▼
     │                                                    [Request Match]
     │                                                           │
     │                                                           ▼
     │                                                    [MyMatchesScreen]
     │                                                           │
     │                        ┌──────────────────────────────────┤
     │                        │                                  │
     │                        ▼                                  ▼
     │               [MatchDetailScreen]                   [RatingScreen]
     │                        │                                  │
     │                        └──────────────┬───────────────────┘
     │                                       │
     │                                       ▼
     │                                [DashboardScreen]
     │
     ├── [Profile] ──► [ProfileScreen] ──► [SettingsScreen]
     │
     └── [Settings] ──► [SettingsScreen] ──► (logout) ──► [LoginScreen]
```

### Auth Guard Boundaries

**Public routes (no auth):** `LoginScreen`, `RegistrationScreen`

**Protected routes (auth required):** `DashboardScreen`, `CommuteCreateScreen`, `CommuteSearchScreen`, `CommuteDetailScreen`, `MyCommutesScreen`, `MyMatchesScreen`, `MatchDetailScreen`, `RatingScreen`, `ProfileScreen`, `SettingsScreen`

### Back Stack Behavior

| Flow | Back Behavior |
|------|--------------|
| Login → Dashboard | `pushReplacement` (back exits app) |
| Dashboard → CommuteCreate → MyCommutes | Standard push stack (back returns to previous) |
| CommuteSearch → CommuteDetail → Request Match → MyMatches | Standard push stack |
| MyMatches → MatchDetail → Rate → Dashboard | `pushReplacement` after rating |
| Any → Settings → Logout → Login | `pushAndRemoveUntil` (clear stack) |

---

## 7. Missing Backend Endpoints (Flutter Blockers)

| # | Endpoint | Method | Blocks Screen | Priority | Notes |
|---|----------|--------|---------------|----------|-------|
| 1 | `/api/v1/commutes/search` | GET | CommuteSearchScreen | **HIGH** | No search/filter endpoint exists. Current endpoints only return user's own commutes (`/commutes/my`). |
| 2 | `/api/v1/auth/me` (update) | PUT | ProfileScreen (edit mode) | **MEDIUM** | `GET /auth/me` exists. PUT for profile updates does not. Profile can be read-only until this is built. |
| 3 | `/api/v1/auth/password-reset` | POST | LoginScreen (forgot password) | **LOW** | No password recovery flow exists anywhere. |
| 4 | `/api/v1/notifications/preferences` | GET/PUT | SettingsScreen (notification toggles) | **LOW** | Settings can use local-only toggles for now. |

### Endpoint Gap Analysis

**Available but not yet consumed by Flutter:**
- `POST /api/v1/auth/verify` — Account verification (Flutter has no verification screen)
- `POST /api/v1/commutes/offers` — Passenger ride request (no UI for creating offers)
- `POST /api/v1/matches/{match_id}/confirm` — Match confirmation (no UI for drivers to confirm)
- `GET /api/v1/civic-score/history` — Score history (Dashboard shows local telemetry history, not backend history)

---

## 8. Build Order

### Phase 1 — Core Auth Flow

**Prerequisites:** None (auth endpoints already exist)

| Step | Item | Type |
|------|------|------|
| 1.1 | `RegistrationScreen` | Screen |
| 1.2 | Link Registration from `LoginScreen` | Navigation |
| 1.3 | `AuthGuard` widget | Shared Widget |
| 1.4 | `ErrorBanner` widget | Shared Widget |
| 1.5 | `LoadingOverlay` widget | Shared Widget |
| 1.6 | Audit `LoginScreen` — add registration link | Existing Screen |

**Backend endpoints needed:** `POST /auth/register` ✅ exists, `POST /auth/login/access-token` ✅ exists

---

### Phase 2 — Commute Flow

**Prerequisites:** Phase 1 complete, `commuteProvider` built

| Step | Item | Type |
|------|------|------|
| 2.1 | `commuteProvider` | Provider |
| 2.2 | `CommuteCreateScreen` | Screen |
| 2.3 | `commuteDetailProvider` | Provider |
| 2.4 | `CommuteDetailScreen` | Screen |
| 2.5 | `CommuteCard` widget | Shared Widget |
| 2.6 | `CivicScoreBadge` widget | Shared Widget |
| 2.7 | Dashboard quick action buttons | Existing Screen |
| 2.8 | `CommuteSearchScreen` (stub — uses `/commutes/my` as placeholder) | Screen |

**Backend endpoints needed:** `POST /commutes` ✅ exists, `GET /commutes/{id}` ✅ exists, `GET /commutes/my` ✅ exists

**BACKEND BLOCKER:** `GET /commutes/search` — CommuteSearchScreen will show user's own commutes as placeholder until search endpoint is built.

---

### Phase 3 — Match Flow

**Prerequisites:** Phase 2 complete, `matchProvider` built

| Step | Item | Type |
|------|------|------|
| 3.1 | `matchProvider` | Provider |
| 3.2 | `myCommutesProvider` | Provider |
| 3.3 | `MyCommutesScreen` | Screen |
| 3.4 | `MyMatchesScreen` | Screen |
| 3.5 | `matchDetailProvider` | Provider |
| 3.6 | `MatchDetailScreen` | Screen |
| 3.7 | `MatchCard` widget | Shared Widget |
| 3.8 | `RatingScreen` | Screen |

**Backend endpoints needed:** `GET /commutes/my` ✅ exists, `POST /commutes/{id}/cancel` ✅ exists, `GET /matches/my` ✅ exists, `POST /matches/{match_id}/confirm` ✅ exists, `GET /matches/{match_id}` ✅ exists, `POST /matches/{match_id}/rate` ✅ exists, `POST /matches/{commute_id}/request` ✅ exists

---

### Phase 4 — Profile & Settings

**Prerequisites:** Phase 3 complete

| Step | Item | Type |
|------|------|------|
| 4.1 | `profileProvider` | Provider |
| 4.2 | `ProfileScreen` (read-only) | Screen |
| 4.3 | `SettingsScreen` | Screen |
| 4.4 | Bottom navigation bar or drawer | Navigation |
| 4.5 | Dashboard navigation integration | Existing Screen |

**Backend endpoints needed:** `GET /auth/me` ✅ exists, `GET /civic-score/history` ✅ exists

**BACKEND BLOCKER:** `PUT /auth/me` — ProfileScreen will be read-only until this endpoint exists.

---

### Phase 5 — Polish & Future

| Step | Item | Type | Notes |
|------|------|------|-------|
| 5.1 | `go_router` migration | Navigation | Replace manual Navigator calls |
| 5.2 | Maps integration | Feature | Requires `google_maps_flutter` or `flutter_map` |
| 5.3 | Push notifications (FCM) | Feature | Backend + Flutter setup |
| 5.4 | Flavor/environment config | Infrastructure | Replace hardcoded `kBaseUrl` |
| 5.5 | Profile edit mode | Screen | Requires `PUT /auth/me` |
| 5.6 | Commute search with filters | Screen | Requires `GET /commutes/search` |

---

## 9. Open Questions & Flags

### 🔴 BACKEND BLOCKERS

1. **`GET /commutes/search` missing** — CommuteSearchScreen cannot function without a search/filter endpoint. The current backend only exposes `/commutes/my` (user's own commutes). **Impact:** Blocks Phase 2 commute discovery. **Workaround:** Show user's own commutes as placeholder.

2. **`PUT /auth/me` missing** — ProfileScreen cannot support profile editing. **Impact:** Profile is read-only. **Workaround:** Show profile as read-only with disabled "Edit" button.

### 🟡 Architecture Flags

3. **`kBaseUrl` hardcoded** — `main.dart:14` has `const kBaseUrl = 'http://192.168.1.9:8000'`. This is device-specific and will break for other developers or production. **Recommendation:** Use `flutter_dotenv` or flavor-based configuration (`dev`, `staging`, `prod`) before multi-developer use.

4. **No navigation library** — All navigation is manual `Navigator.pushReplacement`. With 12 screens this becomes unmaintainable. **Recommendation:** Add `go_router` in Phase 5 (or earlier if team prefers).

5. **No `lib/models/` directory** — All DTOs are scattered across `services/` and `providers/`. **Recommendation:** Create a dedicated `models/` directory for backend response types (Commute, Match, UserProfile, etc.) before Phase 2.

### 🟢 Future Considerations

6. **Maps integration** — No map dependency in `pubspec.yaml`. CommuteCreateScreen currently requires manual coordinate entry. **Options:** `google_maps_flutter` (requires API key), `flutter_map` + OpenStreetMap (free), or continue with text-only address entry + hardcoded coordinates.

7. **Push notifications** — No FCM setup. Match confirmations, ride reminders, and safety alerts would benefit from push notifications. **Flag as Phase 5.**

8. **Telemetry endpoint mismatch** — `telemetry_isolate.dart:275` posts to `/api/v1/telemetry/telemetry` but the backend endpoint is `/api/v1/telemetry/telemetry` (confirmed in API reference). The duplicate `/telemetry/telemetry` path segment appears intentional based on the router prefix (`/telemetry`) + endpoint path (`/telemetry`). **Verify this is correct.**

9. **LoginScreen doesn't retrieve userId** — `auth_service.dart:169` attempts to extract `user_id` or `id` from the login response, but the backend `POST /auth/login/access-token` only returns `{access_token, token_type, expires_in}`. The `userId` will be `null` after login. **Impact:** `civicScoreProvider.startTelemetry()` receives `userId: 'unknown'`. **Fix:** Either modify backend to return `user_id` in login response, or call `GET /auth/me` after login to retrieve the user ID.

---

*Document Version: 1.0*  
*Last Updated: May 16, 2026*
