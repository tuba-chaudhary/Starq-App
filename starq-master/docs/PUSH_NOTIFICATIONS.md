# Push Notifications (Phase 11)

## Overview
Phase 11 implements Firebase Cloud Messaging (FCM) to trigger critical lifecycle events natively on Customer and Partner devices.

## Architecture
- **Firebase Admin SDK (Backend):** NestJS handles all push notification delivery securely via `firebase-admin`. No secret keys are stored in the Flutter codebase or version control.
- **`Notification` Model:** Each pushed notification is mirrored to PostgreSQL so users have a persistent inbox (with read/unread state tracking).
- **`DeviceToken` Model:** Users' FCM tokens are securely managed, registered via `POST /notifications/device-token`, and auto-cleaned if a push fails due to an invalid or stale token.

## Trigger Points
- **Payment Captured / Booking Confirmed:** Customer receives a push confirming payment.
- **Partner Assigned:** 
  - Partner receives a "New Job Assigned" notification.
  - Customer receives a "Partner Assigned" notification.
- *Additional hooks can be freely added inside `partners.service.ts` or `bookings.service.ts` using `this.notificationsService.sendNotification(userId, title, body, type, bookingId)`*.

## Flutter Integration
- Flutter requests permissions natively using `firebase_messaging`.
- It fetches the device token via `FirebaseMessaging.instance.getToken()` and transmits it to the backend `POST /notifications/device-token` upon authentication.
- Deep-linking can be handled naturally since the `bookingId` is transmitted inside the FCM data payload.

## Idempotency & Safety
- **Duplicate Protection:** The `NotificationsService` natively guards against firing the exact same notification type for the exact same booking within a 5-minute window. This stops rapid re-clicks from spamming devices.
- **Token Cleanup:** Dead tokens are immediately purged from Postgres.

## Production Setup
For notifications to reach physical devices:
1. Ensure your Firebase Project is configured for iOS (APNs) and Android.
2. In the backend server `.env`, set:
   - `FIREBASE_PROJECT_ID="your-project-id"`
   - `FIREBASE_CLIENT_EMAIL="firebase-adminsdk-...@...iam.gserviceaccount.com"`
   - `FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"`
3. If these environment variables are absent, the backend safely falls back to Database-only persistence without crashing the server.
