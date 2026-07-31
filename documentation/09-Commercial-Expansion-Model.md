# Civic Link — Commercial Expansion Model
## Fuel Cost-Sharing Carpooling Platform
### Version 1.0 — Strategic Planning Document
### Status: PENDING — Activate only if civic/institutional model fails to gain traction

---

## 1. Executive Summary

Civic Link's current model targets verified institutional users (IT corridors, 
corporate campuses) with a trust-first carpooling platform. This document outlines 
the expansion strategy to a city-wide, public-facing, revenue-generating 
cost-sharing platform serving all metro city residents.

**Core Value Proposition:**
- Passengers: Commute at 40-60% of auto/cab cost
- Vehicle owners: Recover fuel costs on existing daily routes
- Platform: 8-12% transaction fee on every completed trip
- City: Reduced traffic, lower emissions, measurable civic impact

**Legal Framing: Fuel cost-sharing platform, not a transport aggregator.**
This distinction avoids Motor Vehicles Amendment Act 2019 aggregator 
licensing requirements.

**Target Cities (Phase 1):** Hyderabad
**Expansion Cities (Phase 2):** Bengaluru, Chennai, Pune, Mumbai

---

## 2. Why This Model Works

### The Numbers (Hyderabad example)

| Route | Distance | Public Transport | Cab | Civic Link (car) | Civic Link (bike) |
|-------|----------|-----------------|-----|-----------------|-------------------|
| Kukatpally → HiTech City | 12km | ₹60 | ₹200 | ₹40-50 | ₹25-30 |
| Miyapur → Gachibowli | 18km | ₹80 | ₹280 | ₹55-65 | ₹35-40 |
| Secunderabad → HITEC City | 22km | ₹90 | ₹340 | ₹65-75 | ₹40-50 |

### Driver Economics (Car, 2 passengers)
```
Daily commute: 25km round trip
Petrol cost: ₹150/day
Passengers contribute: ₹100 (₹50 each)
Platform fee (10%): ₹10
Driver net recovery: ₹90/day → ₹1,980/month
Annual fuel saving: ~₹23,760
```

### Platform Economics (1000 daily trips)
```
Average fare: ₹45
Platform fee (10%): ₹4.50/trip
Daily revenue: ₹4,500
Monthly revenue: ₹1,35,000
Annual revenue: ₹16,20,000
```

---

## 3. Legal Framework

### 3.1 Legal Position
Civic Link operates as a **technology platform facilitating fuel cost-sharing 
between private vehicle owners and passengers traveling the same route.**

This is distinct from:
- Taxi aggregators (Ola, Uber) — require state aggregator license
- Bike taxi services (Rapido) — require state-specific permits
- Contract carriage — requires commercial vehicle permit

### 3.2 Key Legal Distinctions
| Factor | Aggregator (Ola/Uber) | Civic Link Model |
|--------|----------------------|-----------------|
| Trip purpose | Dedicated commercial trip | Driver's existing daily commute |
| Driver income | Primary income source | Fuel cost recovery only |
| Pricing | Profit-based surge pricing | Cost-based fuel split |
| Vehicle type | Commercial permit required | Personal vehicle |
| Legal precedent | Motor Vehicles Act 2019 | Cost-sharing — grey area |

### 3.3 Reference Models
- **BlaBlaCar** (Europe) — established cost-sharing legal framework
- **Quick Ride** (Hyderabad/Bengaluru) — operating cost-sharing model in India
- **sRide** — similar model, acquired by Quick Ride

### 3.4 Legal Risks
| Risk | Severity | Mitigation |
|------|----------|-----------|
| State RTO treating platform as aggregator | High | Legal opinion letter, T&C clarity |
| Bike taxi ban in Telangana zones | Medium | Cars-only launch, bikes Phase 2 |
| Insurance gap on personal vehicles | Medium | Partner with Acko/Digit for ride insurance add-on |
| Driver treated as employee (gig worker laws) | Low | Pure P2P model, no employment relationship |

### 3.5 Recommended Legal Steps Before Launch
1. Obtain legal opinion from transport law firm (Hyderabad)
2. Register as Technology Intermediary under IT Act
3. Draft Terms clearly stating cost-sharing, not transport service
4. Engage with Telangana transport department proactively
5. Consider FICCI/CII carpooling policy advocacy

---

## 4. Trust & Verification Architecture

### 4.1 Passenger Verification
| Level | Method | Required For |
|-------|--------|-------------|
| L1 | Phone OTP | Account creation |
| L2 | Email verification | Booking trips |
| L3 | Government ID (Aadhaar) | Optional — builds trust score |

### 4.2 Driver Verification (Stricter)
| Level | Method | Required For |
|-------|--------|-------------|
| L1 | Phone OTP | Account creation |
| L2 | Driving License | Offering rides |
| L3 | Vehicle RC | Offering rides |
| L4 | Aadhaar / DigiLocker | Mandatory before first payout |
| L5 | Face match (selfie vs ID) | Mandatory before first payout |
| L6 | Bank account / UPI | Payout setup |

### 4.3 Verification APIs
| Document | API | Cost |
|----------|-----|------|
| Aadhaar OTP | UIDAI / Digio | ₹3-5/verification |
| Driving License | Sarathi API / Digio | ₹2-4/verification |
| Vehicle RC | Vahan API / Digio | ₹2-4/verification |
| Face match | AWS Rekognition / Surepass | ₹1-3/match |
| Bank account | Razorpay / Cashfree penny drop | ₹2-5/verification |

### 4.4 Trust Score Integration
Civic Link's existing CivicScore becomes the public trust signal:
- Driving behavior (existing telemetry engine)
- Trip completion rate
- Passenger ratings
- Verification level (higher = higher base score)
- Cancellation history

---

## 5. Payments Architecture

### 5.1 Payment Flow
```
Passenger books ride
        ↓
Payment held in escrow (Razorpay)
        ↓
Trip starts → both parties confirm
        ↓
Trip completes → driver confirms arrival
        ↓
15-minute window for disputes
        ↓
Funds released: Driver (90%) + Platform (10%)
        ↓
Driver payout: Instant UPI or wallet
```

### 5.2 Fare Calculation Engine
```
Base fare = distance_km × rate_per_km × vehicle_type_multiplier
                                                        
Vehicle rates (per km):
  Bike:        ₹2.50/km
  Hatchback:   ₹3.50/km  
  Sedan:       ₹4.00/km
  SUV:         ₹4.50/km

Per passenger fare = base_fare / seats_filled
Platform fee = per_passenger_fare × 0.10
Passenger pays = per_passenger_fare
Driver receives = (per_passenger_fare × passengers) × 0.90

Example: 12km sedan, 2 passengers
  Base fare = 12 × 4.00 = ₹48
  Per passenger = ₹24
  Platform fee = ₹2.40 per passenger
  Driver receives = ₹48 × 0.90 = ₹43.20
  Platform earns = ₹4.80
```

### 5.3 Payment Stack
| Component | Provider | Purpose |
|-----------|----------|---------|
| Payment gateway | Razorpay | UPI, cards, netbanking |
| Escrow | Razorpay Route | Hold funds during trip |
| Driver payout | Razorpay X | Instant bank transfer |
| Wallet (optional) | Razorpay Wallet | Driver earnings accumulation |
| Refunds | Razorpay Refund API | Cancellation refunds |

### 5.4 Cancellation Policy
| Scenario | Passenger Refund | Driver Compensation |
|----------|-----------------|---------------------|
| Passenger cancels > 30 min before | 100% | None |
| Passenger cancels < 30 min before | 50% | 25% of fare |
| Driver cancels | 100% | Penalty to CivicScore |
| No-show (passenger) | 0% | 50% of fare |
| No-show (driver) | 100% | Penalty + warning |

---

## 6. New Features Required

### 6.1 Backend — New Models
```python
Vehicle:
  id, user_id, type (bike/hatchback/sedan/suv),
  rc_number, rc_verified, seats, fuel_type,
  make, model, year, color

DriverProfile:
  id, user_id, license_number, license_verified,
  license_expiry, aadhaar_verified, face_verified,
  bank_verified, upi_id, is_active

Transaction:
  id, commute_id, passenger_id, driver_id,
  gross_amount, platform_fee, driver_payout,
  status (pending/held/released/refunded/disputed),
  razorpay_order_id, razorpay_payment_id,
  created_at, released_at

PricingRule:
  id, city, vehicle_type, rate_per_km,
  min_fare, effective_from, effective_to

DriverWallet:
  id, driver_id, balance, total_earned,
  total_withdrawn, last_payout_at

VerificationDocument:
  id, user_id, doc_type, doc_number,
  file_url, status (pending/verified/rejected),
  verified_by, verified_at, rejection_reason
```

### 6.2 Backend — New Endpoints
```
POST /drivers/register         — driver onboarding
POST /drivers/upload-document  — license, RC, Aadhaar upload
GET  /drivers/verification-status
POST /vehicles                 — add vehicle
GET  /pricing/estimate         — fare estimate before booking
POST /payments/initiate        — create Razorpay order
POST /payments/confirm         — webhook from Razorpay
POST /payments/release         — release escrow after trip
POST /payments/refund          — cancellation refund
GET  /wallet/balance           — driver wallet
POST /wallet/withdraw          — request payout
GET  /admin/verification-queue — documents pending review
POST /admin/verify-document    — approve/reject document
```

### 6.3 Flutter — New Screens
```
DriverOnboardingScreen    — vehicle + document upload flow
FareEstimateScreen        — cost breakdown before booking
PaymentScreen             — Razorpay SDK
ActiveTripScreen          — live status, SOS, share link
TripCompleteScreen        — confirmation + rating prompt
DriverEarningsScreen      — trip history, wallet, payout
DocumentUploadScreen      — ID/license/RC upload with camera
VerificationStatusScreen  — pending/approved/rejected docs
AdminVerificationScreen   — internal document review (admin only)
```

---

## 7. Safety Features (Required for Public Launch)

| Feature | Implementation | Priority |
|---------|---------------|----------|
| SOS button | Sends GPS + contacts to emergency numbers | Must have |
| Live trip sharing | Shareable link with real-time location | Must have |
| Emergency contacts | 2 contacts notified on SOS | Must have |
| Trip recording | Audio recording option during trip | High |
| Safe destination check | Confirm passenger reached safely | High |
| Driver background check | Police verification certificate | Medium |
| Insurance | Per-trip insurance via API | Medium |
| Panic alert to police | Integration with Dial 100 / ERSS 112 | Future |

---

## 8. Competitive Landscape

| Platform | Model | Status | Weakness |
|----------|-------|--------|----------|
| Quick Ride | Cost-sharing carpool | Active in Hyd/Blr | Poor UX, no real verification |
| BlaBlaCar India | Intercity carpool | Shut down 2020 | Couldn't crack intracity |
| sRide | Daily carpool | Acquired by Quick Ride | |
| Ola Share | Cab sharing | Discontinued | Regulatory pressure |
| Uber Pool | Cab sharing | Discontinued in India | Regulatory pressure |

**Civic Link's differentiation:**
- CivicScore trust layer (unique)
- Telemetry-based driving behavior verification (unique)
- Built for daily commutes not one-off trips
- Safety-first gender matching (existing)
- Govt/police pitch angle (existing civic model)

---

## 9. Go-To-Market Strategy

### Phase 1 — Hyderabad Soft Launch
- Target corridors: Miyapur → Gachibowli, Kukatpally → HiTech City,
  Secunderabad → Madhapur
- Driver acquisition: IT park parking lot campaigns, RWA partnerships
- Passenger acquisition: Referral program, office noticeboard
- Target: 500 drivers, 2000 passengers, 200 daily trips in 90 days

### Phase 2 — Hyderabad Scale
- Expand to all major corridors
- Introduce bike sharing (pending legal clarity)
- Target: 5000 drivers, 20000 passengers, 2000 daily trips

### Phase 3 — Second City
- Bengaluru (largest carpool market in India)
- Reuse entire platform, update pricing rules and corridors

---

## 10. Revenue Projections

| Stage | Daily Trips | Avg Fare | Platform Fee | Monthly Revenue |
|-------|------------|----------|-------------|----------------|
| Soft launch (Month 3) | 200 | ₹40 | 10% | ₹24,000 |
| Growth (Month 6) | 1,000 | ₹45 | 10% | ₹1,35,000 |
| Scale (Month 12) | 5,000 | ₹45 | 10% | ₹6,75,000 |
| City 2 (Month 18) | 15,000 | ₹45 | 10% | ₹20,25,000 |

---

## 11. What Stays From Current Civic Model

Everything built for the institutional model carries over:
- ✅ CivicScore engine + telemetry pipeline
- ✅ AES-256-GCM audit logging (critical for regulatory compliance)
- ✅ Gender safety matching logic
- ✅ Match lifecycle (request/confirm/start/complete/rate)
- ✅ Structured logging + Sentry monitoring
- ✅ Redis rate limiting + nginx
- ✅ CI/CD pipelines
- ✅ GDPR anonymization

What gets extended (not replaced):
- Verification: OTP → full KYC
- Trust: Company email → CivicScore + document verification
- Payments: Free → cost-sharing transactions

---

## 12. Activation Criteria

**Activate this model if ANY of the following:**
- Govt/police institutional pitch fails to gain traction within 6 months
- Institutional user growth stalls below 500 active users
- Investor requires revenue model for next funding round
- Competitor launches similar model in Hyderabad first

**Do NOT activate if:**
- Govt partnership is in active negotiation
- Institutional model shows >20% MoM growth
- Legal opinion advises against cost-sharing model

---

## 13. Open Questions (Resolve Before Activation)

1. Legal opinion on cost-sharing vs aggregator classification in Telangana
2. Insurance partner for per-trip coverage
3. Razorpay aggregator account (requires business registration)
4. DigiLocker / Aadhaar API access (requires UIDAI approval or licensed partner)
5. Police verification API or manual process for driver background checks
6. Bike taxi legal status in target corridors

---

*Document Status: DRAFT — For strategic planning only*
*Do not implement until activation criteria are met*
*Last updated: May 2026*
```
