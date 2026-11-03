# STARQ Codebase Analysis

> **Application**: STARQ Doorstep Car & Bike Washing Platform  
> **Repository**: [https://github.com/tuba-chaudhary/starq_app-](https://github.com/tuba-chaudhary/starq_app-)  
> **Analysis Date**: September 20, 2026  
> **Mode**: Complete Read-Only Codebase Inspection  
> **Status**: Existing UI Prototype Analyzed — Zero Source Code Modified  

---

## Executive Summary

The STARQ Flutter repository (`starq_app-`) contains a clean, well-styled UI prototype covering the core customer-facing booking journey, home dashboard, vehicle list, and service presentation. The visual design follows modern automotive aesthetics with a consistent color palette (Black `#080808`, White `#FFFFFF`, and Primary Red `#D91F1E`).

However, the codebase is currently a **static UI prototype with mock data and zero backend connectivity**. Specifically:
1. There are **no domain models, no repositories, and no API client** (no `http` or `dio`).
2. State management is **not implemented** (`provider: ^6.1.0` is in `pubspec.yaml`, but unused; navigation state is passed as raw `Map<String, dynamic>?` via `go_router`'s `extra`).
3. Business logic is either missing or implemented insecurely on the client (e.g., frontend calculates booking amounts and loyalty points).
4. Critical screens in the customer flow are either empty stubs (e.g., `OrderConfirmedScreen` is 12 lines of text) or completely missing (Partner Live Tracking, Vehicle Add/Edit, Rating & Reviews, Booking History, Add-ons).
5. Native configurations (Android `AndroidManifest.xml` and iOS `Info.plist`) lack essential permissions for Internet, GPS location, and notifications.

---

## 30-Point Comprehensive Technical Analysis

### 1. Flutter / Dart Version & Environment
- **Local Flutter SDK Installed**: `Flutter 3.41.7 • channel stable • Dart 3.11.5 • DevTools 2.54.2`.
- **Repository `pubspec.yaml` Specification**:
  ```yaml
  environment:
    sdk: ^3.13.2
  ```
- **Repository `pubspec.lock` Specification**:
  ```yaml
  sdks:
    dart: ">=3.13.2 <4.0.0"
    flutter: ">=3.38.4"
  ```
- **Critical Compatibility Finding**:
  Running `flutter analyze` or `flutter pub get` on the machine with Flutter 3.41.7 (Dart 3.11.5) fails with:
  ```text
  The current Dart SDK version is 3.11.5.
  Because starq_app requires SDK version ^3.13.2, version solving failed.
  ```
  The SDK constraint `^3.13.2` requires Dart >=3.13.2. To compile on standard Flutter stable channels without forced upgrades, the constraint should be normalized (e.g. `>=3.11.0 <4.0.0`) once modifications are approved.

---

### 2. `lib/` Directory Structure

The repository structure is flat and organized strictly by widget type:

```
lib/
├── main.dart                          # App entry point, MaterialApp.router setup
├── routes/
│   └── app_routes.dart                # GoRouter route declarations (22 routes)
├── screens/                           # 21 screen implementations
│   ├── booking_details_screen.dart    # Hardcoded active booking details
│   ├── booking_summary_screen.dart    # Summary & client price calculation
│   ├── bucket_wash_screen.dart        # Bike bucket wash details
│   ├── choose_location_screen.dart    # Hardcoded saved locations list
│   ├── create_account_screen.dart     # Registration UI
│   ├── exterior_wash_screen.dart      # Car exterior wash details
│   ├── full_detailing_screen.dart     # Car full detailing details
│   ├── home_dashboard_screen.dart     # Main customer dashboard
│   ├── interior_wash_screen.dart      # Car interior wash details
│   ├── my_garage_screen.dart          # 2 hardcoded vehicles
│   ├── onboarding_screen.dart         # Intro landing screen
│   ├── order_confirmed_screen.dart    # 12-line placeholder stub
│   ├── payment_screen.dart            # Mock payment method selector
│   ├── premium_wash_screen.dart       # Car premium wash details
│   ├── pressure_wash_screen.dart      # Bike pressure wash details
│   ├── profile_screen.dart            # User profile & account menu
│   ├── role_selection_screen.dart     # Customer vs Provider selector
│   ├── select_date_time_screen.dart   # Calendar & time slot selector
│   ├── service_selection_screen.dart  # Car vs Bike service catalog
│   ├── sign_in_screen.dart            # Sign in form
│   └── wash_guide_screen.dart         # Educational video list
├── services/
│   └── auth_service.dart              # Single mock dummy service
├── theme/
│   └── app_theme.dart                 # AppColors, AppTextStyles, ThemeData
├── utils/
│   └── page_transitions.dart          # Unused smooth fade-slide transition
└── widgets/
    ├── bottom_nav_bar.dart            # AppBottomNav & NavItem
    ├── custom_button.dart             # AppButton & HoverCard
    ├── custom_text_field.dart         # CustomTextField
    ├── service_detail_template.dart   # Reusable service detail layout
    └── starq_logo.dart                # STARQ logo image display
```

**Missing Structural Layers**:
- No `models/` directory.
- No `providers/`, `bloc/`, or `controllers/` for state management.
- No `repositories/` or `data_sources/`.
- No `network/` or `api/` (no HTTP client, no interceptors, no base URL).
- No `storage/` (no local cache, no secure storage).
- No `constants/` or `core/` architecture.

---

### 3. All Screens / Pages (21 Screens Analyzed)

| # | Screen File | Route | Functional Status | Key Observations |
|---|---|---|---|---|
| 1 | `onboarding_screen.dart` | `/onboarding` | UI Only | Background image + gradient, CTA buttons to sign-in and create-account. |
| 2 | `role_selection_screen.dart` | `/role-selection` | UI Only | Customer selection routes to `/sign-in`; Service Provider triggers "Provider flow coming in next batch" snackbar. |
| 3 | `sign_in_screen.dart` | `/sign-in` | UI Only | Email/password fields. "Sign In" hard-navigates directly to `/home`. Forgot password, Google, Apple buttons are unhandled empty callbacks `{}`. |
| 4 | `create_account_screen.dart` | `/create-account` | UI Only | Full name, email, phone, password inputs. CTA navigates directly to `/role-selection`. No validation, no API call. |
| 5 | `home_dashboard_screen.dart` | `/home` | UI Only | Fixed header, hardcoded Noida address, hardcoded Honda City vehicle card, "Book a Wash" banner, service grid, hardcoded upcoming booking card. Bottom nav tabs: Home, Bookings (snackbar), Rewards (snackbar), Wash Guide. |
| 6 | `my_garage_screen.dart` | `/my-garage` | Mock Data | 2 hardcoded vehicles (Maruti Suzuki Swift & KTM Duke). Tapping passes vehicle info via `extra` to `/service-selection`. "Add New Vehicle" and "Edit Vehicles" buttons have empty `{}` callbacks. |
| 7 | `profile_screen.dart` | `/profile` | Mock Data | Hardcoded user (John Doe). Menu items for Garage, Past Bookings, Address, Support, Settings. Log out routes to `/onboarding`. Bottom nav tabs differ from Home screen. |
| 8 | `service_selection_screen.dart` | `/service-selection` | Mock Data | Evaluates `data?['vehicleType'] == 'bike'`. Displays 4 car services or 2 bike services. Tapping routes to individual service screens, but drops vehicle metadata. |
| 9 | `exterior_wash_screen.dart` | `/exterior-wash` | Static UI | Uses `ServiceDetailTemplate` with static price `₹249`, duration `45 min`, checklist. |
| 10 | `interior_wash_screen.dart` | `/interior-wash` | Static UI | Uses `ServiceDetailTemplate` with static price `₹399`, duration `60 min`, checklist. |
| 11 | `full_detailing_screen.dart` | `/full-detailing` | Static UI | Uses `ServiceDetailTemplate` with static price `₹999`, duration `120 min`, multi-section checklist. |
| 12 | `premium_wash_screen.dart` | `/premium-wash` | Static UI | Uses `ServiceDetailTemplate` with static price `₹1299`, duration `90 min`, checklist. |
| 13 | `bucket_wash_screen.dart` | `/bucket-wash` | Static UI | Bike service. `ServiceDetailTemplate` with `₹149`, duration `20 min`. |
| 14 | `pressure_wash_screen.dart` | `/pressure-wash` | Static UI | Bike service. `ServiceDetailTemplate` with `₹199`, duration `30 min`. |
| 15 | `wash_guide_screen.dart` | `/wash-guide` | Static UI | 4 static video cards with category filter chips. Tapping card triggers "Video coming soon" snackbar. No media player. |
| 16 | `select_date_time_screen.dart` | `/select-date-time` | Local State Only | Custom monthly grid calendar, past date disabling, hardcoded time slots (`08:00 AM` to `05:00 PM`). Passes selection to `/choose-location`. |
| 17 | `choose_location_screen.dart` | `/choose-location` | Mock Data | 4 hardcoded Noida locations with radio selection. Search bar does nothing. "Add New Location" does nothing. No map/GPS. Passes selection to `/booking-summary`. |
| 18 | `booking_summary_screen.dart` | `/booking-summary` | Mock Data & Client Math | Hardcodes vehicle as `Honda City · KA 01 AB 1234` regardless of what was selected. Calculates total on client (`price + 30`). Calculates points on client (`total * 0.1`). |
| 19 | `payment_screen.dart` | `/payment` | Mock UI | Selectable list of mock payment methods (UPI, Card, Net Banking, Wallets). "Pay" button routes to `/order-confirmed`. No payment gateway. |
| 20 | `order_confirmed_screen.dart` | `/order-confirmed` | Stub Only | 12 lines: `Scaffold(body: Center(child: Text('Order Confirmed Screen')))`. No booking ID, no details, no actions. |
| 21 | `booking_details_screen.dart` | `/booking-details` | Hardcoded Mock | Static booking `# HOC688464`, conflicting vehicle labels, partner `Rahul Kumar` with dead Call/Chat buttons. "Book Again" button pushes `/service-selection`. |

---

### 4. Navigation & Routing Architecture
- Router: `go_router: ^14.0.0` defined in `lib/routes/app_routes.dart`.
- 22 routes registered with standard `builder:` functions.
- `lib/utils/page_transitions.dart` defines `buildPageWithTransition()` with a custom `FadeTransition` and `SlideTransition`, but **none** of the routes in `app_routes.dart` actually use it; all use default platform transitions.
- **Routing Data Passing Defects**:
  - `SelectDateTimeScreen`, `ChooseLocationScreen`, `BookingSummaryScreen`, and `ServiceSelectionScreen` accept `state.extra as Map<String, dynamic>?`.
  - **Defect 1**: `/payment` route does NOT forward `state.extra` to `PaymentScreen`:
    ```dart
    GoRoute(
      path: '/payment',
      builder: (context, state) => const PaymentScreen(), // extra is lost!
    ),
    ```
    Even though `PaymentScreen` accepts `this.data`, `data` is always null!
  - **Defect 2**: `/booking-details` does NOT accept `extra` or query/path parameters (e.g. `/booking-details/:id`), making dynamic booking inspection impossible.
  - **Defect 3**: Direct deep linking will fail because downstream screens (`BookingSummaryScreen`, `ChooseLocationScreen`, `SelectDateTimeScreen`) depend on non-null `extra` dictionary keys.
  - **Defect 4**: Navigating from `ServiceDetailTemplate` pushes `/select-date-time` with only `serviceTitle` and `servicePrice`, permanently losing the selected vehicle ID/plate.

---

### 5. Reusable Widgets & Components
1. **`AppButton` (`lib/widgets/custom_button.dart`)**:
   - High quality interactive button with hover animations (`MouseRegion`), press animations, optional outline mode, and trailing icons.
2. **`HoverCard` (`lib/widgets/custom_button.dart`)**:
   - Wraps tiles in a subtle translateY (-2px) and elevation drop shadow on hover. Clean and reusable.
3. **`CustomTextField` (`lib/widgets/custom_text_field.dart`)**:
   - Thin wrapper around `TextField` with `controller` and `obscureText`.
   - **Gaps**: Lacks validation display, input formatters (e.g., phone numbers, number plates), error styling, suffix/prefix widgets, and focus node management.
4. **`ServiceDetailTemplate` (`lib/widgets/service_detail_template.dart`)**:
   - Reusable scaffold for service details (hero image, title, price, duration, rating, included items).
   - Directly calls `context.push('/select-date-time', extra: {...})`.
5. **`StarqLogo` (`lib/widgets/starq_logo.dart`)**:
   - Renders `assets/images/logo.png` with configurable font-equivalent sizing.
6. **`AppBottomNav` (`lib/widgets/bottom_nav_bar.dart`)**:
   - Custom navigation bar with active icon tinting and "coming soon" snackbar fallback for null routes.
   - **Inconsistency**: In `home_dashboard_screen.dart`, tab 4 is "wash guide" (`/wash-guide`). In `profile_screen.dart`, tab 4 is "profile" (`/profile`). Tab 2 ("bookings") and Tab 3 ("rewards") have null routes in both.

---

### 6. State Management
- Dependency declared: `provider: ^6.1.0`.
- **Current Utilization**: **0%**.
- No `ChangeNotifier`, `ValueNotifier`, `Bloc`, `Cubit`, or `Riverpod` providers exist.
- `main.dart` contains no `MultiProvider` or state injectors:
  ```dart
  void main() {
    runApp(const MyApp());
  }
  ```
- All mutable screen data relies on ephemeral `StatefulWidget` (`setState`) or raw map arguments passed between routes.
- When an app is terminated or backgrounded, all booking workflow progress is wiped.

---

### 7. Domain Models
- **Status**: **Completely Missing**.
- There is not a single Dart model class in the codebase.
- Data structures are unstructured `Map<String, dynamic>` literals:
  ```dart
  // Example from my_garage_screen.dart:
  final vehicles = [
    {
      'image': 'car image.png',
      'name': 'Maruti Suzuki Swift (ZXi+)',
      'plate': 'KA 01 AB 1234 · Hatchback · Red',
      'vehicleType': 'car',
    },
    ...
  ];
  ```
- Required models missing: `UserModel`, `VehicleModel`, `ServiceItemModel`, `AddOnModel`, `AddressModel`, `BookingModel`, `PaymentModel`, `PartnerModel`, `ReviewModel`, `RewardTransactionModel`.

---

### 8. Services & API Layer
- **Status**: **Non-existent API Client**.
- The `lib/services/` directory contains only `auth_service.dart`:
  ```dart
  class AuthService {
    Future<bool> login(String email, String password) async {
      await Future.delayed(const Duration(seconds: 1));
      return true; // dummy — backend lead will replace this
    }
    Future<bool> signup(String name, String email, String password) async {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
  }
  ```
- Even this dummy service is never invoked by `SignInScreen` or `CreateAccountScreen`.
- No HTTP client package (`dio` or `http`) is installed.
- No network timeout handling, no token interceptor, no retry logic, no API error mapping.

---

### 9. Authentication
- UI screens: `SignInScreen`, `CreateAccountScreen`, `RoleSelectionScreen`.
- **Gaps**:
  - Tapping "Sign In" performs `context.go('/home')` without email/password validation or credential transmission.
  - Tapping "Create Account" performs `context.go('/role-selection')` without saving the user.
  - "Forgot password?" is an empty callback.
  - Social login buttons ("Google", "Apple") are empty callbacks.
  - No OTP / Phone number verification screens exist (despite being specified in the Figma prompt as the core login mechanism for Indian consumers).
  - No JWT token storage (`flutter_secure_storage`).
  - No session refresh or logout logic (logout just navigates to `/onboarding`).

---

### 10. Vehicle Management (My Garage)
- Screen: `MyGarageScreen` (`lib/screens/my_garage_screen.dart`).
- Displays 2 static vehicles:
  1. Maruti Suzuki Swift (ZXi+) - KA 01 AB 1234 (Car)
  2. KTM Duke 390 - KA 01 AB 5678 (Bike)
- Tapping a vehicle selects it and forwards to `/service-selection`.
- **Gaps**:
  - "Add New Vehicle" has empty `onPressed: () {}`.
  - "Edit Vehicles" has empty `onPressed: () {}`.
  - No form to add brand, model, variant, registration plate, fuel type, or color.
  - No vehicle deletion or "set as primary" functionality.
  - No vehicle category taxonomy (Hatchback, Sedan, SUV, MUV, Luxury, Scooter, Motorcycle, Superbike).

---

### 11. Service Selection
- Screen: `ServiceSelectionScreen` (`lib/screens/service_selection_screen.dart`).
- Supports Car vs Bike logic based on `vehicleType`.
- **Car Services Listed**:
  - Exterior Wash (₹249 · 45 min)
  - Interior Cleaning (₹399 · 60 min)
  - Full Detailing (₹999 · 2-3 hrs)
  - Premium Wash (₹1299 · 90 min)
- **Bike Services Listed**:
  - Bucket Wash (₹149 · 20 min)
  - Pressure Wash (₹199 · 30 min)
- **Gaps**:
  - Hardcoded pricing in UI widgets.
  - Prices do not vary by vehicle size/category (e.g. SUV vs Hatchback).
  - Tapping a service pushes `/exterior-wash`, etc., without carrying forward the selected vehicle information.

---

### 12. Add-Ons
- **Status**: **Completely Missing in UI**.
- The product specification calls for optional add-ons:
  - Tyre Polish
  - Interior Fragrance
  - Engine Bay Cleaning
  - Paint Protection / Wax Coat
  - Rain Repellent Windshield Treatment
- None of the service screens or booking summary screens contain add-on selection toggles, checkboxes, or price calculations.

---

### 13. Address & Location
- Screen: `ChooseLocationScreen` (`lib/screens/choose_location_screen.dart`).
- Contains 4 hardcoded Noida addresses:
  - Home: Sector 62, Noida, UP
  - Work: Sector 18, Noida, UP
  - John's Home: Sector 50, Noida, UP
  - Parents Home: Sector 15, Noida, UP
- **Gaps**:
  - Search bar is an unmanaged `TextField` with no autocomplete or listener.
  - "Add New Address" is an empty callback.
  - No Google Maps widget (`google_maps_flutter`).
  - No GPS geolocation (`geolocator`) or reverse geocoding.
  - No serviceability check (verifying if STARQ operates in that pincode/geofence).

---

### 14. Date & Time Selection
- Screen: `SelectDateTimeScreen` (`lib/screens/select_date_time_screen.dart`).
- Custom month calendar calculating days and blocking past dates.
- Static time slots: `08:00 AM`, `09:00 AM`, `10:00 AM`, `11:00 AM`, `01:00 PM`, `03:00 PM`, `05:00 PM`.
- **Gaps**:
  - Slots are completely static; no backend capacity/availability check.
  - Cannot detect if all partner slots are booked for a given time window.
  - No buffer time calculation (e.g. minimum 2 hours from current time).

---

### 15. Booking Flow & Pipeline
- **Existing Flow**:
  1. `HomeDashboardScreen` / `MyGarageScreen`
  2. `ServiceSelectionScreen`
  3. Individual Service Detail (`ExteriorWashScreen`, etc.)
  4. `SelectDateTimeScreen`
  5. `ChooseLocationScreen`
  6. `BookingSummaryScreen`
  7. `PaymentScreen`
  8. `OrderConfirmedScreen` (stub)
- **Gaps**:
  - Data passing between screens is brittle and drops metadata.
  - No draft booking record is created on the backend.
  - No booking expiration timer.

---

### 16. Booking Summary
- Screen: `BookingSummaryScreen` (`lib/screens/booking_summary_screen.dart`).
- Hardcodes vehicle as `Honda City · KA 01 AB 1234`.
- Client parses service price regex, adds ₹30 convenience fee, and computes `points = (total * 0.1).round()`.
- **Critical Violation**:
  - Frontend calculates the price and convenience fee.
  - Any client can tamper with the amount sent to payment.

---

### 17. Payment Screen
- Screen: `PaymentScreen` (`lib/screens/payment_screen.dart`).
- Displays hardcoded total (defaulting to ₹279 if route extra was dropped).
- Mock radio buttons for UPI, Credit/Debit Card, Net Banking, Wallets.
- "Pay" button pushes `/order-confirmed`.
- **Gaps**:
  - Zero payment gateway integration (Razorpay SDK not installed).
  - No order generation, no checkout sheet, no payment signature verification.

---

### 18. Confirmation Screen
- Screen: `OrderConfirmedScreen` (`lib/screens/order_confirmed_screen.dart`).
- Contains:
  ```dart
  class OrderConfirmedScreen extends StatelessWidget {
    const OrderConfirmedScreen({super.key});
    @override
    Widget build(BuildContext context) {
      return const Scaffold(
        body: Center(child: Text('Order Confirmed Screen')),
      );
    }
  }
  ```
- **Gaps**: Entire screen needs to be built from scratch to display Order ID, date/time, vehicle, partner assignment status, and "Track Partner" CTA.

---

### 19. Partner Tracking & Live GPS
- Screen: `BookingDetailsScreen` (`lib/screens/booking_details_screen.dart`).
- Hardcodes a past/active wash (`# HOC688464`), partner `Rahul Kumar`, and dead Call/Chat buttons.
- **Gaps**:
  - No live GPS tracking screen.
  - No map showing customer location and partner location.
  - No live ETA, no status progression stepper (Assigned → En Route → Arrived → Wash Started → Wash Completed).
  - No WebSocket, Supabase Realtime, or polling mechanism.

---

### 20. Profile & Account
- Screen: `ProfileScreen` (`lib/screens/profile_screen.dart`).
- Hardcoded user info ("John Doe", "john.doe@gmail.com").
- Menu items: My Profile, My Garage, Address Booked, Past Bookings, Help & Support, Settings.
- "Edit" button and 4 out of 6 menu items are non-functional stubs.
- Inconsistent bottom navigation bar compared to Home.

---

### 21. Booking History
- **Status**: **Missing**.
- Tab 2 on the bottom navigation ("bookings") triggers a "coming soon" snackbar.
- Past Bookings on the profile screen mistakenly routes to the single static `BookingDetailsScreen`.
- No list of Active Bookings, Completed Bookings, or Cancelled Bookings.

---

### 22. Reviews & Ratings
- **Status**: **Missing**.
- Static ratings (e.g. 4.8, 4.9) are displayed on service detail and partner cards.
- There is no rating dialog, review submission form, star selector, or photo upload mechanism for completed washes.

---

### 23. Starq Points & Rewards
- **Status**: **Missing**.
- Tab 3 on bottom navigation ("rewards") triggers "coming soon" snackbar.
- Booking summary mentions "You'll earn X STARQ points", but there is no wallet, points balance, points redemption, or transaction history.

---

### 24. Assets & Media
- Directory: `assets/images/` (12 files):
  - `logo.png`, `onboarding_logo.png`, `onbording_picture.png` (note typo: `onbording`)
  - `car image.png`, `bike image.png` (note spaces in filenames)
  - `exterior_wash.png`, `interior_cleaning.png`, `full_detailing.png`, `premium_wash.png`
  - `Bike_Bucket_wash.png`, `Bike_Pressure_Wash.png`, `videos.png`
- **Gaps**:
  - No vector icons or SVGs (`flutter_svg` not installed).
  - Asset filenames contain spaces and spelling mistakes that will cause issues on Linux/CI/CD release builds.
  - No placeholder images for dynamically fetched vehicle models or partner profile photos.

---

### 25. Dependencies (`pubspec.yaml`)
Current dependencies:
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  go_router: ^14.0.0
  google_fonts: ^6.2.0
  provider: ^6.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```
**Missing Packages Required for Production**:
- `dio` or `http`: REST API communication.
- `flutter_secure_storage`: Secure JWT / refresh token persistence.
- `shared_preferences`: Local user preferences.
- `razorpay_flutter`: Doorstep payment checkout.
- `google_maps_flutter`: Live partner tracking and map pin selection.
- `geolocator`: GPS user location detection.
- `intl`: Currency and date/time formatting.
- `cached_network_image`: Dynamic vehicle, service, and partner image caching.
- `flutter_svg`: Scalable vector graphics.
- `flutter_dotenv`: Environment variable management.

---

### 26. Environment & Configuration
- **Status**: **Missing**.
- No `.env` or `.env.example` file.
- No `Environment` class or configuration flavor setup.
- API base URLs, Razorpay Key IDs, Google Maps API keys are completely absent.

---

### 27. Hardcoded / Mock Data Inventory
1. **User Profile**: "John Doe", "john.doe@gmail.com".
2. **Vehicles**: Maruti Suzuki Swift (`KA 01 AB 1234 · Hatchback · Red`), KTM Duke 390 (`KA 01 AB 5678 · Bike · Black`).
3. **Addresses**: 4 static Noida locations (Sector 62, Sector 18, Sector 50, Sector 15).
4. **Service Catalog**: Hardcoded titles, fixed prices (₹149 to ₹1299), durations, and feature lists.
5. **Booking Details**: ID `# HOC688464`, date `21 May, 2025 · 10:00 AM`, partner `Rahul Kumar` (rating 4.8).
6. **Time Slots**: 7 static hourly strings.
7. **Pricing Math**: Convenience fee ₹30, 10% loyalty points.
8. **Wash Guide**: 4 static video descriptions with zero video playback URLs.

---

### 28. TODOs & Incomplete Functionality
- `AuthService.login()`: `// dummy — backend lead will replace this`.
- `RoleSelectionScreen`: Service Provider role triggers "Provider flow coming in next batch" snackbar.
- `WashGuideScreen`: Video cards trigger "Video coming soon" snackbar.
- `ChooseLocationScreen`: Location search and "Add New Location" do nothing.
- `MyGarageScreen`: "Add New Vehicle" and "Edit Vehicles" do nothing.
- `ProfileScreen`: "Edit", "Address Booked", "Help & Support", "Settings" do nothing.
- `BookingDetailsScreen`: Call and Chat icon buttons have empty callbacks.
- `OrderConfirmedScreen`: Contains only placeholder text widget.
- `test/widget_test.dart`: Default template counter smoke test (fails to run).

---

### 29. Existing Backend & API References
- **Status**: **Zero endpoints referenced**.
- No URLs, no REST controllers, no GraphQL queries, no WebSocket clients.
- The app operates in complete isolation as an offline mock prototype.

---

### 30. Android & iOS Native Configuration
- **Android** (`android/app/src/main/AndroidManifest.xml`):
  - Application ID: `com.example.starq_app` (needs change to production package name, e.g. `com.starq.customer`).
  - **Permissions missing**:
    - `<uses-permission android:name="android.permission.INTERNET"/>` (Cannot make API calls or load network images!)
    - `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>`
    - `<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>`
    - `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
  - Gradle: Java 17, Kotlin JVM 17.
- **iOS** (`ios/Runner/Info.plist`):
  - Bundle ID: `com.example.starqApp`.
  - **Permissions missing**:
    - `NSLocationWhenInUseUsageDescription`
    - `NSLocationAlwaysAndWhenInUseUsageDescription`
    - `NSCameraUsageDescription` (needed for vehicle condition pre-wash inspection photos)
    - `NSPhotoLibraryUsageDescription`
- **Desktop/Web**: Linux, macOS, Web, and Windows runners exist, but are not targeted for the mobile customer app.

---
*End of Codebase Analysis.*
