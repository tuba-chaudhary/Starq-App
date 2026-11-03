# Payments & Razorpay

## Architecture
We use a **Server-to-Server Webhook + Client Checkout** model to ensure payment tampering is impossible.

1. **Order Generation (`backend/src/bookings`)**
   - The backend SDK generates an `order_id` using `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET`.
   - The key secret is strictly maintained on the server.
2. **Client Initialization (`lib/features/booking/payment_service.dart`)**
   - Flutter initializes `Razorpay()` using *only* the public `key_id` and the generated `order_id`.
   - On completion, it routes the user based on success or failure but **does not dictate actual database state**.
3. **Webhook Verification (`backend/src/payments/`)**
   - Razorpay fires events to `POST /payments/webhook`.
   - **Signature Verification:** The payload is verified using HMAC SHA256 against `RAZORPAY_WEBHOOK_SECRET`.
   - **Idempotency Check:** If the mapped `Payment` record is already marked `captured`, the event is safely ignored to prevent double-confirmations.
   - **State Update:** If valid and uncaptured, `Payment` becomes `captured`, and the associated `Booking` translates to `CONFIRMED`.

## Security Rules
- NEVER check in `.env` containing live secrets.
- NEVER embed `RAZORPAY_KEY_SECRET` in Dart code.
- Always run webhook signature checks.
