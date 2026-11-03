# Admin / Ops Dashboard (Phase 12)

## Overview
This phase introduces the Admin role and operations dashboard for the STARQ platform. The system operates natively via the existing NestJS backend and Flutter app, leveraging `JWT` and `@Roles('ADMIN')` for robust security.

## Backend Architecture
- **AdminModule**: Isolates administrative endpoints away from consumer APIs.
- **RolesGuard**: Added `@Roles('ADMIN')` decorator to ensure no CUSTOMER or PARTNER can forge admin privileges. The JWT strategy extracts the role accurately from the database.
- **Features**:
  - `GET /admin/bookings`
  - `GET /admin/bookings/:id`
  - `GET /admin/partners`
  - `GET /admin/partners/:id`
  - `PATCH /admin/bookings/:id/assign-partner`
  - `PATCH /admin/bookings/:id/reassign-partner`
  - `PATCH /admin/bookings/:id/cancel`
- **Idempotency & Safety**: All mutations (cancellation, assignment, reassignment) use Prisma `$transaction` scopes. If a partner is reassigned, their status elegantly toggles back to `AVAILABLE` while the newly chosen partner flips to `BUSY`.

## Rules & Limitations
- **Manual Assignment**: Can only be performed if the booking is `CONFIRMED` or `ASSIGNMENT_PENDING`, and the partner is `AVAILABLE`.
- **Cancellation**: Cannot cancel if the service has already begun (`SERVICE_STARTED` onwards). If a payment is captured, it moves to `REFUND_PENDING` logically. (Physical Razorpay refunds must be dispatched natively via Razorpay Dashboard as requested to avoid spoofing).
- **Notifications**: Automated notifications inherently trigger on reassignments or admin cancellations (e.g., both the customer and partner are immediately alerted).

## Flutter Integration
- **AdminProvider**: Encapsulates state for the Admin layout, preventing bleed-over into consumer code.
- **AdminDashboardScreen**: Displays a tabbed interface (Bookings / Partners) for swift overview operations. Admin can tap a booking context menu to manually assign a partner or cancel directly.
- **Routing**: `app_routes.dart` intercepts login natively and diverts users with the `ADMIN` role exactly to the Ops dashboard, preventing them from bypassing into consumer carts or partner screens.
