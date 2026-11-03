# Phase 10: GPS & Live Tracking Audit

## 1. Current State
- The PostgreSQL database using Prisma handles authentication, vehicle management, pricing, checkout, and partner state toggling safely.
- No historical `PartnerLocation` model currently exists.
- The Flutter application lacks `geolocator` or `google_maps_flutter` dependencies.
- Bookings maintain a status lifecycle (`ASSIGNMENT_PENDING`, `PARTNER_ON_THE_WAY`, etc.), which correctly sets the stage for tracking.

## 2. Database Action Plan
- Add `PartnerLocation` model to `backend/prisma/schema.prisma`.
- Attributes: `id`, `partnerId`, `bookingId`, `latitude`, `longitude`, `accuracy`, `heading`, `speed`, `recordedAt`, `createdAt`.
- Establish relations mapping `PartnerLocation` to `Partner` and `Booking`.
- Introduce indexes on `partnerId`, `bookingId`, and `recordedAt` for fast polling retrieval.
- Only log new updates or replace the latest update (upsert is usually sufficient, but storing history might be preferred depending on scope; MVP dictates simple polling fetching the latest record, so we will use UPSERT/Create logic optimizing for latest fetch).

## 3. Backend Action Plan
- **PATCH `/partners/location`**: To allow authenticated Partners to post their location securely (must have an active `BUSY` status and active booking).
- **GET `/bookings/:id/partner-location`**: To allow authenticated Customers to fetch the most recent partner location reliably.

## 4. Flutter Action Plan
- **Dependencies**: Add `geolocator` and `google_maps_flutter`.
- **Permissions**: Ensure `AndroidManifest.xml` and `Info.plist` request Foreground GPS access.
- **Service**: Implement `LocationService` isolating all hardware GPS operations.
- **Provider**: Build `LocationProvider` mapped to Partner/Customer state to manage Start/Stop background tracking gracefully tied explicitly to active booking contexts.
- **UI Maps**: Build a basic mapping interface showing the partner's icon dynamically overlayed on `google_maps_flutter`.

## 5. Security & Privacy
- Backend will stringently reject location updates if the partner is not actively assigned to a booking.
- Customers attempting to fetch coordinates for bookings they do not own will encounter 403 Forbidden.
- No keys will be statically hardcoded into the binary.
