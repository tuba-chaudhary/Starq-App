# Partner App

## Overview
Phase 7 introduces the Partner Dashboard to the STARQ MVP. It provides a simple, dedicated operational interface for service partners without duplicating authentication logic or cluttering the core app.

## Authentication & Routing
The Partner App leverages the existing unified JWT-based backend authentication. 
When a user logs in, the `AppRouter` intercepts the user's role:
- If `role == 'PARTNER'`, they are redirected to `/partner-dashboard`.
- If `role == 'CUSTOMER'`, they are redirected to `/home`.

This prevents partners from accidentally wandering into customer flows and maintains a highly specific operational focus.

## Partner Dashboard
The dashboard (`PartnerDashboardScreen`) allows partners to manage their active availability and fulfill assigned bookings:
1. **Status Toggle:** Partners can toggle their presence between `AVAILABLE` and `OFFLINE`.
   - The UI enforces that partners who are currently `BUSY` (servicing an active booking) cannot toggle back to `AVAILABLE` until the service completes, avoiding overlapping allocations.
2. **Current Assignment View:** Displays the single active assigned booking fetched securely from `GET /partners/bookings`. It summarizes the service requested, the vehicle to service, and the location.
3. **Operational State Machine:** Displays contextual "Next Action" buttons that progress the booking strictly according to the unified backend lifecycle state machine.
   - *Start Journey* (`PARTNER_ASSIGNED` → `PARTNER_ON_THE_WAY`)
   - *Mark Arrived* (`PARTNER_ON_THE_WAY` → `PARTNER_ARRIVED`)
   - *Start Service* (`PARTNER_ARRIVED` → `SERVICE_STARTED`)
   - *Mark In Progress* (`SERVICE_STARTED` → `SERVICE_IN_PROGRESS`)
   - *Complete Service* (`SERVICE_IN_PROGRESS` → `SERVICE_COMPLETED`)

## Network Layer Enhancements
Added `patch` method support to `ApiClient` to securely communicate role status changes (`PATCH /partners/status`) and progressive booking state mutations (`PATCH /partners/bookings/:id/status`).

## Constraints
- Does not expose customer billing information.
- Razorpay, bookings generation, and vehicle CRUD logic remain physically isolated from the partner's workflow.
