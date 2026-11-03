# GPS + Live Partner Tracking (Phase 10)

## Architecture
- **Backend Model**: Added `PartnerLocation` to PostgreSQL which securely tracks location history linked to the current active booking (`bookingId`).
- **REST Endpoints**:
  - `PATCH /partners/location`: For Partners to emit GPS pings. Validates coordinates and enforces they have an actively assigned booking.
  - `GET /bookings/:id/partner-location`: For Customers to fetch the most recent partner location. Rejects fetch if the booking isn't currently active (e.g. `COMPLETED`).
- **Partner App**: 
  - Tracks GPS only when working (`_startTracking()` in `PartnerProvider`).
  - Stops tracking automatically when jobs are completed or cancelled (`_stopTracking()`).
- **Customer App**:
  - Shows `CustomerTrackingMap` widget polling the backend periodically (every 10 seconds).
  - Uses Google Maps Flutter with a blue marker for the partner and red marker for the service destination.

## Permissions & Configuration
- **Android**: `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>` is already verified.
- **iOS**: Uses `NSLocationWhenInUseUsageDescription`.
- **Google Maps**: Uses standard `google_maps_flutter`. You will need to inject an Android `AndroidManifest.xml` meta-data `<meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_KEY"/>` or an iOS `AppDelegate.swift` key injection to enable map rendering physically.

## Known Limitations
- The tracker uses simple polling instead of WebSockets. Polling every 10 seconds scales reasonably well for MVP and removes the necessity for Redis or Socket.io.
- Historical route data is logged, but the frontend only visualizes the single most recent ping.
