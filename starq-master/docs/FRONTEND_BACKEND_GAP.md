# STARQ Frontend-Backend Gap Analysis

> **Document**: Technical Gap Analysis & Architectural Discrepancy Report  
> **Project**: STARQ Doorstep Car & Bike Washing Platform  
> **Source Codebase**: `starq_app-` (Flutter Frontend Prototype)  
> **Target Production System**: Flutter App ↔ STARQ Backend API (Node.js/Go/Python) ↔ PostgreSQL Database  
> **Date**: September 20, 2026  

---

## 1. Executive Summary

The existing STARQ Flutter repository provides a polished visual presentation for primary onboarding, catalog exploration, date/time picking, and basic layout structure. However, there is a **complete disconnect between the current frontend prototype and the required enterprise-grade backend architecture**.

The current application functions as a self-contained, offline UI demonstrator. It lacks domain data models, network client configuration, secure credential storage, server-authoritative calculations, and payment gateway bindings.

This document identifies every gap between the current Flutter prototype and the production requirements across **Security, Business Rules, Screen Coverage, Data Contracts, and Operational Flows**.

---

## 2. Business Rules & Security Compliance Gaps

| Mandatory Business Rule | Current Prototype Implementation | Risk Level | Required Production Implementation |
|---|---|---|---|
| **1. Customer does NOT select service partner** | `BookingDetailsScreen` hardcodes "Rahul Kumar" (Rating 4.8). No selection UI exists in booking flow. | Low / Compliant | Retain customer opacity regarding partner selection. The booking flow must submit an unassigned booking to the backend; the backend dispatch engine assigns the partner based on geo-clustering, availability, and vehicle qualification. |
| **2. Backend calculates the final booking amount** | `BookingSummaryScreen` parses the raw price string via regex: `priceValue = int.tryParse(...)`, adds `convenienceFee = 30`, and computes points `(total * 0.1).round()`. | **CRITICAL VULNERABILITY** | **Strict Server Calculation**: The client submits only `{vehicle_id, service_id, add_on_ids[], address_id, slot_id, coupon_code}`. The backend queries the authoritative service/add-on catalog, applies vehicle size multipliers, taxes, convenience fees, and coupon discounts, returning the canonical signed summary and amount. |
| **3. Never trust prices from Flutter frontend** | `BookingSummaryScreen` forwards `'total': total` directly in route `extra` to `PaymentScreen`. | **CRITICAL VULNERABILITY** | All pricing sent to payment gateways must originate from the server-generated `order_id`. The client must NEVER send an `amount` parameter to Razorpay directly; it must only receive an `order_id` created by the backend. |
| **4. Razorpay secret NEVER exposed in Flutter** | No Razorpay integration present yet. | High (Must enforce) | Only `RAZORPAY_KEY_ID` (public key) is supplied to the Flutter client. `RAZORPAY_KEY_SECRET` must reside strictly in backend environment variables. |
| **5. Payment verified on the backend** | `PaymentScreen` simulates success upon tapping "Pay ₹279" by navigating directly to `/order-confirmed`. | **CRITICAL VULNERABILITY** | On payment success callback in Flutter, the client sends `{razorpay_order_id, razorpay_payment_id, razorpay_signature}` to `POST /api/v1/payments/verify`. Backend verifies SHA-256 HMAC signature using the server secret before updating the booking status to `confirmed`. |
| **6. Webhooks securely verified & idempotent** | No webhook endpoints exist. | High (Backend Requirement) | Backend must expose `POST /api/v1/payments/webhook`, verify the Razorpay webhook secret signature, and maintain an `idempotency_keys` / `processed_webhook_events` table to ignore duplicate delivery attempts. |
| **7. GPS tracking only for active bookings** | `BookingDetailsScreen` displays static partner details with dead call/chat buttons and zero live tracking. | Medium / Incomplete | GPS streams from partner mobile devices to WebSocket/API should only publish coordinates while a booking is in status `provider_on_the_way` or `arrived`. Once status moves to `service_started` or `completed`, partner location broadcasts terminate to protect partner privacy. |
| **8. Vehicle condition / damage consent auditable** | Completely absent from both screens and data flow. | **LEGAL / OPERATIONAL RISK** | Before washing begins, the partner app must take 4–6 photos of pre-existing scratches/dents and upload them. The customer app must present an in-app "Condition Review & Sign-off" modal with timestamped consent logged in PostgreSQL before wash execution. |

---

## 3. Screen-by-Screen Gap & Refactoring Analysis

### 3.1 Onboarding & Authentication Flow

| Screen | Existing UI Implementation | Missing Functional & Backend Requirements |
|---|---|---|
| **Onboarding** (`/onboarding`) | Single static image background with "Get Started" and "Create Account" buttons. | Multi-page carousel/PageView with progress indicator (as specified in Figma prompt); auto-login token check to redirect authenticated users directly to `/home`. |
| **Role Selection** (`/role-selection`) | Customer vs Service Provider cards. Provider triggers static snackbar. | Customer selection should store active role context; Provider selection should direct to the dedicated Service Provider Onboarding / Partner APK link. |
| **Sign In** (`/sign-in`) | Email & Password `TextField`s. "Sign In" navigates directly to `/home`. Empty callbacks for Google, Apple, and Forgot Password. | **1.** Integration with `POST /api/v1/auth/login`.<br>**2.** Phone + OTP login mechanism (`POST /api/v1/auth/otp/send` and `/verify`).<br>**3.** Secure token storage (`flutter_secure_storage`).<br>**4.** Form validation and error messaging.<br>**5.** Password reset workflow. |
| **Create Account** (`/create-account`) | Name, Email, Phone, Password inputs. CTA navigates to `/role-selection`. | **1.** `POST /api/v1/auth/register` integration.<br>**2.** Mobile number verification via SMS OTP.<br>**3.** Input validation (email format, 10-digit Indian phone number, strong password policy). |

---

### 3.2 Vehicle Management & Garage

| Screen | Existing UI Implementation | Missing Functional & Backend Requirements |
|---|---|---|
| **My Garage** (`/my-garage`) | Displays 2 hardcoded vehicles (Maruti Swift & KTM Duke). Tapping passes map to `/service-selection`. | **1.** `GET /api/v1/vehicles` to list customer vehicles from PostgreSQL.<br>**2.** Dynamic rendering of vehicle categories (Hatchback, Sedan, SUV, Bike).<br>**3.** Primary vehicle indicator badge.<br>**4.** Empty state for new accounts with no vehicles. |
| **Add Vehicle Screen** (*Missing*) | "Add New Vehicle" button on garage screen is a dead callback `{}`. | **Complete Screen Required**: Brand dropdown, Model selector, Vehicle Type selector (Hatchback/Sedan/SUV/Luxury/Bike), Registration Number input, Color, Fuel Type, and `POST /api/v1/vehicles`. |
| **Edit/Delete Vehicle** (*Missing*) | "Edit Vehicles" button is a dead callback `{}`. | **Complete Screen/Modal Required**: Update vehicle nickname, set primary vehicle (`PUT /api/v1/vehicles/:id`), and deletion (`DELETE /api/v1/vehicles/:id`) with cascade confirmation. |

---

### 3.3 Service Selection & Add-Ons

| Screen | Existing UI Implementation | Missing Functional & Backend Requirements |
|---|---|---|
| **Service Selection** (`/service-selection`) | Switches between 4 car services and 2 bike services based on `extra['vehicleType']`. Static hardcoded prices. | **1.** `GET /api/v1/services?vehicle_type={type}` fetching catalog and dynamic pricing.<br>**2.** Vehicle-tier pricing: SUVs cost more than hatchbacks.<br>**3.** Preserve full vehicle object in navigation state.<br>**4.** Display estimated duration from backend metadata. |
| **Service Details** (`/exterior-wash`, etc.) | Six separate files each instantiating `ServiceDetailTemplate` with static constants. Passes only title & price to next screen. | **1.** Refactor into a **single dynamic `ServiceDetailScreen`** driven by `service_id` or route parameter (`/services/:id`).<br>**2.** `GET /api/v1/services/:id` for description, detailed checklist, and high-res media.<br>**3.** **Add-on Selection Section**: List optional add-ons (Tyre Polish, Interior Fragrance, Engine Cleaning, etc.) with checkboxes and dynamic price updates.<br>**4.** Forward selected add-on IDs along with vehicle ID to scheduling. |

---

### 3.4 Location & Scheduling

| Screen | Existing UI Implementation | Missing Functional & Backend Requirements |
|---|---|---|
| **Date & Time** (`/select-date-time`) | Custom monthly calendar widget and 7 static time slots. Blocks past days only. | **1.** `GET /api/v1/bookings/available-slots?date={date}&pincode={pincode}`: Check live partner capacity.<br>**2.** Gray out fully booked or expired time slots.<br>**3.** Dynamic buffer logic: Disallow booking a slot less than 2 hours in advance.<br>**4.** Operational holiday / service cutoff hours check. |
| **Choose Location** (`/choose-location`) | 4 hardcoded Noida addresses with radio buttons. Search bar and "Add Location" are dead stubs. | **1.** `GET /api/v1/addresses` to list saved customer addresses.<br>**2.** Google Places Autocomplete API on search bar.<br>**3.** GPS "Use Current Location" button via `geolocator` and Google Geocoding API.<br>**4.** Pincode serviceability check (`GET /api/v1/service-areas/check?lat={lat}&lng={lng}`). If out of area, display polite unserviceable notice.<br>**5.** "Add New Address" modal/screen (`POST /api/v1/addresses`) with House No, Landmark, City, State, Pincode. |

---

### 3.5 Checkout, Payment & Confirmation

| Screen | Existing UI Implementation | Missing Functional & Backend Requirements |
|---|---|---|
| **Booking Summary** (`/booking-summary`) | Hardcoded vehicle details; regex client price calculation; hardcoded ₹30 convenience fee. | **1.** `POST /api/v1/bookings/quote`: Send vehicle, service, add-ons, address, slot, coupon to backend.<br>**2.** Display authoritative breakdown from server response: Base Price + Add-on Subtotals + Convenience Fee + GST (18%) - Coupon Discount = Total Payable.<br>**3.** Display calculated STARQ loyalty points from server response.<br>**4.** Coupon application input with `POST /api/v1/coupons/validate`. |
| **Payment Screen** (`/payment`) | Static radio buttons for UPI/Cards/Netbanking. "Pay" button routes to order confirmed without taking action. | **1.** `POST /api/v1/payments/create-order`: Backend creates Razorpay order with server-verified amount.<br>**2.** Launch native `Razorpay` checkout sheet using `razorpay_flutter`.<br>**3.** Handle `PAYMENT_SUCCESS`, `PAYMENT_ERROR`, and `PAYMENT_CANCELLED` events.<br>**4.** On success, verify signature on backend: `POST /api/v1/payments/verify`.<br>**5.** Only navigate forward once server confirms payment. |
| **Order Confirmed** (`/order-confirmed`) | **12-line placeholder** displaying only "Order Confirmed Screen". | **Complete Screen Required**: Green animated confirmation graphic, Order ID (`#STQ-XXXXXX`), Date/Time slot, Vehicle summary, Partner assignment notification ("Assigning best professional nearby..."), "Track Booking" button, and "Back to Home" button. |

---

### 3.6 Tracking, Service Lifecycle & History

| Screen | Existing UI Implementation | Missing Functional & Backend Requirements |
|---|---|---|
| **Live Tracking Screen** (*Missing*) | Completely non-existent. | **Complete Screen Required**:<br>**1.** Google Map displaying customer location, partner real-time location, and route polyline.<br>**2.** ETA calculation badge.<br>**3.** Partner summary card: Photo, Name, Rating, Completed Jobs count.<br>**4.** In-app calling (masked or direct) and in-app chat.<br>**5.** Live lifecycle status stepper:<br>   `Confirmed → Partner Assigned → On The Way → Arrived → Wash Started → Completed`. |
| **Service In-Progress & Inspection** (*Missing*) | Completely non-existent. | **Complete Screen/Sheet Required**:<br>**1.** Pre-wash vehicle condition check: Review partner's inspection photos (scratches/dents) and give customer digital sign-off.<br>**2.** Progress indicator (Foam wash → Detailing → Interior vacuum → Final inspection). |
| **Service Completed & Review** (*Missing*) | Completely non-existent. | **Complete Screen Required**:<br>**1.** Before/after wash photo gallery uploaded by partner.<br>**2.** Star rating (1 to 5 stars) + feedback tags ("Super Clean", "Punctual", "Careful").<br>**3.** Optional tip for partner via Razorpay.<br>**4.** `POST /api/v1/reviews`. |
| **Booking History** (*Missing*) | Profile menu and bottom nav show "coming soon" snackbars. | **Complete Screen Required** (`/bookings`):<br>**1.** Tabs for "Active" and "Past" bookings.<br>**2.** `GET /api/v1/bookings`.<br>**3.** Booking cards with status badge, date, service, price, and "Rebook" / "View Receipt" actions. |
| **Booking Details** (`/booking-details`) | Hardcodes past wash `# HOC688464` and dead buttons. | Update to accept dynamic `:bookingId`, fetching `GET /api/v1/bookings/:id`. Display invoice download button, partner details, and live status. |

---

### 3.7 Profile, Rewards & Support

| Screen | Existing UI Implementation | Missing Functional & Backend Requirements |
|---|---|---|
| **Home Dashboard** (`/home`) | Noida address, Honda City, Book a wash banner, service grid, upcoming booking card all hardcoded. | **1.** `GET /api/v1/customer/dashboard`: Fetch active vehicle, current location, next active booking card, and dynamic promo banners.<br>**2.** Upcoming booking card links dynamically to active tracking screen.<br>**3.** Notification bell badge with unread count. |
| **Profile Screen** (`/profile`) | "John Doe", "john.doe@gmail.com". Menu items are mostly dead stubs. Inconsistent bottom nav bar. | **1.** `GET /api/v1/profiles/me`: Dynamic profile info.<br>**2.** Edit personal details screen (`PUT /api/v1/profiles/me`).<br>**3.** Address Book management (`/addresses`).<br>**4.** Real logout: Clear secure storage, invalidate JWT, navigate to `/onboarding`. |
| **Starq Points & Rewards** (*Missing*) | Mentioned on summary screen and bottom nav; no screen exists. | **Complete Screen Required** (`/rewards`):<br>**1.** `GET /api/v1/rewards/balance`: Display current points.<br>**2.** Points transaction ledger (earned from bookings, redeemed on discounts).<br>**3.** Referral code sharing card. |
| **Wash Guide Screen** (`/wash-guide`) | 4 static video cards with category filter. Tapping shows "coming soon" snackbar. | Connect to backend CMS `GET /api/v1/wash-guides`. Embed YouTube or HLS video player (`youtube_player_flutter` or `video_player`). |

---

## 4. Missing Operations & Admin Requirements

The user prompt specifies that the target system must support complete Operations and Administration workflows. The current mobile repository contains **zero administration infrastructure**:

```
OPERATIONS / ADMIN CAPABILITIES NEEDED (BACKEND & ADMIN PORTAL)
├── Customer Management       (Inspect customer profiles, vehicles, booking history, lifetime value)
├── Partner Management        (Onboarding, KYC documents, service tools verification, active status)
├── Service Area Geofencing   (Define operational polygon zones, pincode coverage, surge pricing)
├── Catalog & Pricing Engine  (Define services, duration, base rates, vehicle-type multipliers, add-ons)
├── Booking Dispatch Engine   (Auto/manual partner assignment, booking queue, re-assignment on decline)
├── Payments & Refunds Desk   (Inspect Razorpay transaction IDs, reconcile webhooks, trigger partial/full refunds)
├── Live Operations Dashboard (Active partner location map, in-transit jobs, active wash statuses, escalations)
├── Review & Quality Audit    (Customer feedback moderation, partner rating trends, customer damage claims)
└── Loyalty & Coupons         (Create promotional promo codes, manage point conversion ratios)
```

---

## 5. Architectural Comparison Matrix

| Architectural Layer | Current Frontend Prototype | Target Production Architecture | Gap Severity |
|---|---|---|---|
| **Client Framework** | Flutter 3.41+ (Dart 3.11/3.13) | Flutter 3.41+ with null-safety and lint compliance | Low (SDK constraint fix needed) |
| **State Management** | Local `setState` + `go_router` route `extra` | Provider / Riverpod Feature-First Architecture | **High** (Needs refactoring) |
| **Data Layer** | Hardcoded in Dart widget trees | Clean Architecture (Models, DTOs, Repositories, Data Sources) | **High** (Needs creation) |
| **Network Client** | None | `Dio` client with JWT Interceptors, retry policies, base URL | **Critical** (Missing) |
| **Persistence** | None | `flutter_secure_storage` (Tokens) + `shared_preferences` (Cache/Flags) | **Critical** (Missing) |
| **Backend API** | None (Single dummy mock class) | REST / JSON API (Express/NestJS/FastAPI/Supabase) | **Critical** (Missing) |
| **Database** | None | PostgreSQL with Relational Integrity & RLS | **Critical** (Missing) |
| **Payment Gateway** | Fake radio buttons | Razorpay Standard Checkout SDK + Server Verification + Webhooks | **Critical** (Missing) |
| **Maps / Tracking** | None | Google Maps Flutter + Geolocation + Live Partner WebSockets | **Critical** (Missing) |
| **Push Notifications** | None | Firebase Cloud Messaging (FCM) for order status updates | **High** (Missing) |
| **Security Auditing** | None | Timestamped Pre-Wash Damage Photo Inspection Sign-Off | **High** (Missing) |

---
*End of Frontend-Backend Gap Analysis.*
