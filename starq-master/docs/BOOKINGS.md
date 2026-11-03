# Booking Lifecycle

## Engine
- **Endpoint:** `POST /bookings`
- **Responsibilities:**
  1. Validates JWT user ownership of the incoming `vehicleId` and `addressId`.
  2. Submits variables to `PricingService` to independently recalculate quote pricing, stripping trust from Flutter client submissions entirely.
  3. Uses a PostgreSQL `$transaction` to atomically insert a `Booking` and all nested `BookingItem` and `BookingAddon` relationships (preventing split-brain records).
  4. Directly invokes the Razorpay SDK to create an Order ID (`amount` scaled to paise).
  5. Seeds a `Payment` record mapping the Razorpay order ID directly to the newly created Booking.
- **Initial Status:** `PENDING_PAYMENT`

## Address Validation
- Addresses are managed by `AddressesModule` and strict scoped checks are enforced for read/write paths.

## Idempotency
- Multiple API invocations are safeguarded by database transactions. Webhooks update states uniquely based on provider tracking IDs.
