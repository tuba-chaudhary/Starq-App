import 'package:go_router/go_router.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';

// Onboarding & Auth
import 'package:starq_app/features/auth/onboarding_screen.dart';
import 'package:starq_app/features/auth/role_selection_screen.dart';
import 'package:starq_app/features/auth/sign_in_screen.dart';
import 'package:starq_app/features/auth/create_account_screen.dart';

// Home & Profile
import 'package:starq_app/features/home/home_dashboard_screen.dart';
import 'package:starq_app/features/vehicles/my_garage_screen.dart';
import 'package:starq_app/features/profile/profile_screen.dart';
import 'package:starq_app/features/partner/partner_dashboard_screen.dart';
import 'package:starq_app/features/admin/admin_dashboard_screen.dart';

// Services
import 'package:starq_app/features/services/service_selection_screen.dart';
import 'package:starq_app/features/services/exterior_wash_screen.dart';
import 'package:starq_app/features/services/interior_wash_screen.dart';
import 'package:starq_app/features/services/full_detailing_screen.dart';
import 'package:starq_app/features/services/premium_wash_screen.dart';
import 'package:starq_app/features/services/wash_guide_screen.dart';

// Booking flow
import 'package:starq_app/features/booking/choose_location_screen.dart';
import 'package:starq_app/features/booking/select_date_time_screen.dart';
import 'package:starq_app/features/booking/booking_summary_screen.dart';
import 'package:starq_app/features/booking/booking_details_screen.dart';
import 'package:starq_app/features/payments/payment_screen.dart';
import 'package:starq_app/features/booking/order_confirmed_screen.dart';

import 'package:starq_app/features/services/bucket_wash_screen.dart';
import 'package:starq_app/features/services/pressure_wash_screen.dart';
import 'package:starq_app/features/booking/bookings_history_screen.dart';
import 'package:starq_app/features/points/rewards_screen.dart';
import 'package:starq_app/features/vehicles/add_vehicle_screen.dart';
import 'package:starq_app/features/addresses/add_address_screen.dart';
import 'package:starq_app/features/addresses/saved_addresses_screen.dart';
import 'package:starq_app/features/tracking/live_tracking_screen.dart';
import 'package:starq_app/features/reviews/review_screen.dart';
import 'package:starq_app/features/legal/legal_screen.dart';
import 'package:starq_app/features/vehicles/vehicle_consent_screen.dart';
import 'package:starq_app/features/auth/splash_screen.dart';
import 'package:starq_app/features/partner_onboarding/screens/partner_onboarding_wizard_screen.dart';
import 'package:starq_app/features/partner_onboarding/screens/partner_status_screen.dart';

GoRouter createAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authProvider,
    redirect: (context, state) {
      if (authProvider.isLoading) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }

      final isAuth = authProvider.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/create-account' ||
          state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/role-selection' ||
          state.matchedLocation == '/partner-onboarding';

      if (state.matchedLocation == '/splash') {
        if (isAuth) {
          if (authProvider.currentUser?.role == 'PARTNER' && (authProvider.currentUser?.isApprovedPartner ?? false)) {
            return '/partner-dashboard';
          } else if (authProvider.currentUser?.role == 'ADMIN') {
            return '/admin-dashboard';
          }
          return '/home';
        } else {
          return '/onboarding';
        }
      }

      if (!isAuth && !isAuthRoute) {
        return '/sign-in';
      }

      if (isAuth && (state.matchedLocation == '/sign-in' || state.matchedLocation == '/create-account' || state.matchedLocation == '/onboarding')) {
        if (authProvider.currentUser?.role == 'PARTNER' && (authProvider.currentUser?.isApprovedPartner ?? false)) {
          return '/partner-dashboard';
        } else if (authProvider.currentUser?.role == 'ADMIN') {
          return '/admin-dashboard';
        }
        return '/home';
      }

      // Guard partner dashboard: only approved partners can enter
      if (isAuth && state.matchedLocation == '/partner-dashboard') {
        if (!(authProvider.currentUser?.isApprovedPartner ?? false)) {
          return '/partner-status';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/admin-dashboard',

        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/partner-dashboard',
        builder: (context, state) => const PartnerDashboardScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/partner-onboarding',
        builder: (context, state) => const PartnerOnboardingWizardScreen(),
      ),
      GoRoute(
        path: '/partner-status',
        builder: (context, state) => PartnerStatusScreen(
          initialData: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/create-account',
        builder: (context, state) => const CreateAccountScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeDashboardScreen(),
      ),
      GoRoute(
        path: '/my-garage',
        builder: (context, state) => const MyGarageScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/service-selection',
        builder: (context, state) => ServiceSelectionScreen(
          data: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/exterior-wash',
        builder: (context, state) => ExteriorWashScreen(
          data: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/interior-wash',
        builder: (context, state) => InteriorWashScreen(
          data: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/full-detailing',
        builder: (context, state) => FullDetailingScreen(
          data: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/premium-wash',
        builder: (context, state) => PremiumWashScreen(
          data: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/wash-guide',
        builder: (context, state) => const WashGuideScreen(),
      ),
      GoRoute(
        path: '/select-date-time',
        builder: (context, state) => SelectDateTimeScreen(
          data: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/choose-location',
        builder: (context, state) => ChooseLocationScreen(
          data: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/booking-summary',
        builder: (context, state) => BookingSummaryScreen(
          data: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/booking-details',
        builder: (context, state) => const BookingDetailsScreen(),
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) => const PaymentScreen(),
      ),
      GoRoute(
        path: '/order-confirmed',
        builder: (context, state) => const OrderConfirmedScreen(),
      ),
      GoRoute(
        path: '/bucket-wash',
        builder: (context, state) => BucketWashScreen(
          data: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/pressure-wash',
        builder: (context, state) => PressureWashScreen(
          data: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const BookingsHistoryScreen(),
      ),
      GoRoute(
        path: '/rewards',
        builder: (context, state) => const RewardsScreen(),
      ),
      GoRoute(
        path: '/add-vehicle',
        builder: (context, state) => const AddVehicleScreen(),
      ),
      GoRoute(
        path: '/add-address',
        builder: (context, state) => const AddAddressScreen(),
      ),
      GoRoute(
        path: '/saved-addresses',
        builder: (context, state) => const SavedAddressesScreen(),
      ),
      GoRoute(
        path: '/live-tracking',
        builder: (context, state) => LiveTrackingScreen(
          bookingId: state.extra is String ? state.extra as String : '',
        ),
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) => ReviewScreen(
          bookingId: state.extra is String ? state.extra as String : '',
        ),
      ),
      GoRoute(
        path: '/legal-terms',
        builder: (context, state) => const LegalScreen(title: 'Terms & Conditions'),
      ),
      GoRoute(
        path: '/legal-privacy',
        builder: (context, state) => const LegalScreen(title: 'Privacy Policy'),
      ),
      GoRoute(
        path: '/legal-refund',
        builder: (context, state) => const LegalScreen(title: 'Cancellation & Refund Policy'),
      ),
      GoRoute(
        path: '/vehicle-consent',
        builder: (context, state) => const VehicleConsentScreen(),
      ),
    ],
  );
}