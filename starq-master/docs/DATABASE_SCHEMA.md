# STARQ Database Schema

## Entities Overview

### Users & Authentication
- **User**: Core customer accounts.
- **Address**: Saved customer addresses.
- **Vehicle**: User's saved vehicles (`vehicle_types`: CAR, BIKE).

### Catalog & Pricing
- **Service**: Base washing services.
- **ServiceVariant**: Pricing tiers (e.g., Default, Sedan, SUV).
- **ServiceAddon**: Additional optional items.

### Bookings & Operations
- **Booking**: Main order entity connecting User, Vehicle, Address, and Partner.
- **BookingItem**: Specific services booked at locked-in prices.
- **BookingAddon**: Selected add-ons at locked-in prices.
- **BookingStatusHistory**: Audit log of all state transitions.
- **Payment**: Payment ledger tracking transactions.

### Partners (Washers)
- **Partner**: Washer profile, ratings, completed jobs.
- **PartnerAvailability**: Scheduling constraints for dispatch.

### Customer Engagement
- **Review**: Ratings and feedback linked to Bookings.
- **PointsLedger**: Rewards system tracking points additions/deductions.

## Booking State Machine
Bookings flow strictly through these states:
- `DRAFT`
- `PENDING_PAYMENT`
- `PAYMENT_PROCESSING`
- `PAYMENT_FAILED`
- `CONFIRMED`
- `ASSIGNMENT_PENDING`
- `PARTNER_ASSIGNED`
- `PARTNER_ON_THE_WAY`
- `PARTNER_ARRIVED`
- `SERVICE_STARTED`
- `SERVICE_IN_PROGRESS`
- `SERVICE_COMPLETED`
- `CUSTOMER_FEEDBACK_PENDING`
- `COMPLETED`
- `CANCELLED`
- `REFUND_PENDING`
- `REFUNDED`
