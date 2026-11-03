import os
import re

base_dir = r"c:\Users\SIDDDIQUI TABISH\Downloads\STARQ\starq_app-\lib"

# 1. Create PartnerProvider
provider_path = os.path.join(base_dir, "features", "providers", "partner_provider.dart")
partner_provider_code = """import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../booking/domain/booking_model.dart' as bm;

class PartnerProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  bm.Booking? _assignedBooking;
  bm.Booking? get assignedBooking => _assignedBooking;

  String _status = 'OFFLINE';
  String get status => _status;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  PartnerProvider(this._apiClient);

  Future<void> fetchAssignedBooking() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _apiClient.get('/partners/bookings');
      final list = (response.data as List).map((e) => bm.Booking.fromJson(e)).toList();
      _assignedBooking = list.isNotEmpty ? list.first : null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStatus() async {
      // In MVP we just toggle it or set it, but let's say we fetch it.
      // Wait, there's no GET /partners/status yet?
      // I will assume it's part of me or just default to OFFLINE, then user toggles.
  }

  Future<bool> setStatus(String newStatus) async {
    if (newStatus == 'AVAILABLE' && _assignedBooking != null) return false; // Prevent available if busy
    _isLoading = true;
    notifyListeners();
    try {
      await _apiClient.patch('/partners/status', data: {'status': newStatus});
      _status = newStatus;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateBookingStatus(String bookingId, String newStatus) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiClient.patch('/partners/bookings/$bookingId/status', data: {'status': newStatus});
      await fetchAssignedBooking();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
"""
os.makedirs(os.path.dirname(provider_path), exist_ok=True)
with open(provider_path, "w", encoding="utf-8") as f:
    f.write(partner_provider_code)

# 2. Add PartnerProvider to main.dart
main_path = os.path.join(base_dir, "..", "lib", "main.dart")
with open(main_path, "r", encoding="utf-8") as f:
    main_code = f.read()

if "PartnerProvider" not in main_code:
    main_code = main_code.replace("import 'package:starq_app/features/providers/address_provider.dart';", "import 'package:starq_app/features/providers/address_provider.dart';\nimport 'package:starq_app/features/providers/partner_provider.dart';")
    provider_registration = """        ChangeNotifierProvider(
          create: (_) => AddressProvider(apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => PartnerProvider(apiClient),
        ),"""
    main_code = main_code.replace("""        ChangeNotifierProvider(
          create: (_) => AddressProvider(apiClient),
        ),""", provider_registration)
    with open(main_path, "w", encoding="utf-8") as f:
        f.write(main_code)


# 3. Create PartnerDashboardScreen
dashboard_path = os.path.join(base_dir, "features", "partner", "partner_dashboard_screen.dart")
os.makedirs(os.path.dirname(dashboard_path), exist_ok=True)
dashboard_code = """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/features/providers/partner_provider.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:starq_app/features/booking/domain/booking_model.dart' as bm;

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartnerProvider>().fetchAssignedBooking();
    });
  }

  String _getNextActionStatus(bm.BookingStatus currentStatus) {
    if (currentStatus == bm.BookingStatus.partnerAssigned) return 'PARTNER_ON_THE_WAY';
    if (currentStatus == bm.BookingStatus.providerOnTheWay) return 'PARTNER_ARRIVED';
    if (currentStatus == bm.BookingStatus.arrived) return 'SERVICE_STARTED';
    if (currentStatus == bm.BookingStatus.serviceStarted) return 'SERVICE_IN_PROGRESS';
    if (currentStatus == bm.BookingStatus.serviceInProgress) return 'SERVICE_COMPLETED';
    return '';
  }

  String _getNextActionLabel(bm.BookingStatus currentStatus) {
    if (currentStatus == bm.BookingStatus.partnerAssigned) return 'Start Journey';
    if (currentStatus == bm.BookingStatus.providerOnTheWay) return 'Mark Arrived';
    if (currentStatus == bm.BookingStatus.arrived) return 'Start Service';
    if (currentStatus == bm.BookingStatus.serviceStarted) return 'Mark In Progress';
    if (currentStatus == bm.BookingStatus.serviceInProgress) return 'Complete Service';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PartnerProvider>();
    final auth = context.watch<AuthProvider>();
    final booking = provider.assignedBooking;
    final partnerName = auth.currentUser?.fullName ?? 'Partner';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Partner Dashboard', style: AppTextStyles.subheading),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.logout();
            },
          )
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.fetchAssignedBooking(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Hello, $partnerName', style: AppTextStyles.heading),
                    Row(
                      children: [
                        Text(provider.status, style: AppTextStyles.body),
                        Switch(
                          value: provider.status == 'AVAILABLE' || provider.status == 'BUSY',
                          onChanged: (val) {
                            if (provider.status == 'BUSY') return; // Cannot toggle if busy
                            provider.setStatus(val ? 'AVAILABLE' : 'OFFLINE');
                          },
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                if (booking == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text('No assigned bookings at the moment.', style: AppTextStyles.body),
                    ),
                  )
                else
                  _buildActiveBookingCard(context, provider, booking),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveBookingCard(BuildContext context, PartnerProvider provider, bm.Booking booking) {
    final nextStatus = _getNextActionStatus(booking.status);
    final nextLabel = _getNextActionLabel(booking.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.textDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Assignment', style: AppTextStyles.subheading.copyWith(color: Colors.white)),
          const SizedBox(height: 12),
          Text('Service: ${booking.service?.name ?? 'Wash'}', style: AppTextStyles.body.copyWith(color: Colors.white70)),
          Text('Vehicle: ${booking.vehicle?.brand ?? ''} ${booking.vehicle?.registrationNumber ?? ''}', style: AppTextStyles.body.copyWith(color: Colors.white70)),
          Text('Location: ${booking.address?.addressLine ?? ''}, ${booking.address?.city ?? ''}', style: AppTextStyles.body.copyWith(color: Colors.white70)),
          const SizedBox(height: 20),
          Text('Status: ${booking.statusDisplay}', style: AppTextStyles.subheading.copyWith(color: AppColors.primaryLight)),
          const SizedBox(height: 20),
          if (nextStatus.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: provider.isLoading ? null : () => provider.updateBookingStatus(booking.id, nextStatus),
                child: provider.isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(nextLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
"""
with open(dashboard_path, "w", encoding="utf-8") as f:
    f.write(dashboard_code)


# 4. Update AppRoutes for Partner Dashboard
routes_path = os.path.join(base_dir, "app", "router", "app_routes.dart")
with open(routes_path, "r", encoding="utf-8") as f:
    routes_code = f.read()

if "partner_dashboard_screen.dart" not in routes_code:
    routes_code = routes_code.replace("import 'package:starq_app/features/profile/profile_screen.dart';", "import 'package:starq_app/features/profile/profile_screen.dart';\nimport 'package:starq_app/features/partner/partner_dashboard_screen.dart';")
    
    # Update redirect logic for PARTNER role
    redirect_logic = """
      if (isAuth && isAuthRoute) {
        if (authProvider.currentUser?.role == 'PARTNER') {
          return '/partner-dashboard';
        }
        return '/home';
      }
"""
    routes_code = re.sub(r"if \(isAuth && isAuthRoute\) \{\s*return '/home';\s*\}", redirect_logic.strip(), routes_code)
    
    # Add Partner Route
    partner_route = """      GoRoute(
        path: '/partner-dashboard',
        builder: (context, state) => const PartnerDashboardScreen(),
      ),"""
    routes_code = routes_code.replace("routes: [", "routes: [\n" + partner_route)
    
    with open(routes_path, "w", encoding="utf-8") as f:
        f.write(routes_code)

print("Partner Flutter App Updated.")
