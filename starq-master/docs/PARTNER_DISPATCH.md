# Partner Dispatch

## Overview
This document describes the Partner Dispatch and Booking Status workflow implemented in Phase 6 of the STARQ MVP.

## Partner Model
The `Partner` model extends the base `User` model, acting as a profile for service partners. 
- `isActive` indicates if the partner's account is currently active on the platform.
- `status` (`AVAILABLE`, `BUSY`, `OFFLINE`) tracks their real-time dispatch availability.
- `serviceArea` allows geo-fencing (currently a string field for MVP).

## Automatic Partner Assignment
Upon successful Razorpay test payment (verified via `/payments/verify`):
1. The booking status transitions from `PENDING_PAYMENT` to `CONFIRMED`.
2. The `PaymentsService` delegates to `AssignmentsService.autoAssign()`.
3. The booking transitions to `ASSIGNMENT_PENDING`.
4. The system queries for the first `AVAILABLE` partner.
5. If found, a transaction:
   - Updates the booking to `PARTNER_ASSIGNED`.
   - Assigns the `partnerId`.
   - Transitions the partner's status to `BUSY` to prevent overlapping bookings.
   - Logs the transition in `BookingStatusHistory`.
6. If no partner is available, the booking remains in `ASSIGNMENT_PENDING`.

## Booking Status Lifecycle
Bookings proceed through the following verified states:
`DRAFT` -> `PENDING_PAYMENT` -> `CONFIRMED` -> `ASSIGNMENT_PENDING` -> `PARTNER_ASSIGNED` -> `SERVICE_STARTED` -> `COMPLETED`.

## Partner API
Partners can access the system using their JWT token:
- `GET /partners/bookings`: Lists all active/upcoming bookings assigned to them.
- `PATCH /partners/status`: Updates their availability (`AVAILABLE`, `BUSY`, `OFFLINE`).
- `PATCH /partners/bookings/:id/status`: Updates a booking's status. Verified to strictly only allow updates if the booking is assigned to the authenticated partner.
