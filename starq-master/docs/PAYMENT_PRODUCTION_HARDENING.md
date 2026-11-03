# Production Payment Hardening

## Overview
Phase 8 hardens the STARQ Razorpay integration, verifying signatures safely, handling idempotency, and safeguarding environment credentials before deployment.

## Audited Flow
- `POST /payments/verify`: A synchronous hook hit by the Flutter frontend after a Razorpay Checkout succeeds natively.
- `POST /payments/webhook`: An asynchronous hook hit by Razorpay's servers to report backend-verified events (`payment.captured`, `payment.failed`).

## Security & Idempotency Improvements
1. **Signature Verification Enforced**: 
   - Both `/verify` and `/webhook` mathematically validate payload integrity using HMAC SHA-256 against their respective secrets (`RAZORPAY_KEY_SECRET` for orders, `RAZORPAY_WEBHOOK_SECRET` for webhooks).
   - In `payments.service.ts`, if the `RAZORPAY_WEBHOOK_SECRET` is missing entirely from the `.env`, the system now aggressively throws a `BadRequestException` rather than bypassing security. This prevents unauthenticated access if an environment is misconfigured.
2. **Database Idempotency**: 
   - `handleWebhook` now queries the associated `Payment` record and strictly short-circuits if the state is already `'captured'`. 
   - The synchronous `verifyPayment` does the exact same check.
   - If both the async webhook and the sync frontend call hit the API simultaneously, the database state handles it cleanly.
3. **Assignment Idempotency**: 
   - `AssignmentsService.autoAssign` explicitly enforces that the booking status must be exactly `CONFIRMED`.
   - If it runs twice (once triggered by the client, once triggered by the webhook), the second run hits the `!= CONFIRMED` block and aborts safely. This strictly prevents duplicate partner assignments or overlapping booking state rewrites.

## Environment Safety
- Verified that the backend `.gitignore` properly excludes `.env` and `.env.*`. No secrets will accidentally leak into version control.
- Verified that the Flutter `.env` contains strictly the *public* `RAZORPAY_KEY_ID`. The private Secret is physically inaccessible from the mobile binary.

## Webhook Endpoint Status
- The endpoint is active at `POST /payments/webhook`.
- **Note:** Because the backend is currently running on `localhost:3000` (development), Razorpay's external servers physically cannot reach it yet. Before launching, a public URL (e.g. AWS, Render, Heroku) or a local tunneling service (e.g., ngrok) must be registered in the Razorpay Webhook Dashboard.
