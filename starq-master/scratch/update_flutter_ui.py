import os
import re

base_dir = r"c:\Users\SIDDDIQUI TABISH\Downloads\STARQ\starq_app-\lib"

# 1. Update BookingProvider
provider_path = os.path.join(base_dir, "features", "providers", "booking_provider.dart")
with open(provider_path, "r", encoding="utf-8") as f:
    provider_code = f.read()

provider_code = provider_code.replace("class BookingProvider extends ChangeNotifier {", "import '../booking/domain/booking_model.dart' as bm;\n\nclass BookingProvider extends ChangeNotifier {\n  bm.Booking? _activeBooking;\n  bm.Booking? get activeBooking => _activeBooking;")

fetch_active_booking = """
  Future<void> fetchActiveBooking() async {
    try {
      final response = await _apiClient.get('/bookings');
      final list = (response.data as List).map((e) => bm.Booking.fromJson(e)).toList();
      _activeBooking = list.firstWhere((b) => b.isActive, orElse: () => list.isNotEmpty ? list.first : null as dynamic);
      if (_activeBooking != null) {
          final detailResponse = await _apiClient.get('/bookings/${_activeBooking!.id}');
          _activeBooking = bm.Booking.fromJson(detailResponse.data);
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }
"""
provider_code = provider_code.replace("Future<void> fetchCatalog() async {", fetch_active_booking + "\n  Future<void> fetchCatalog() async {")
with open(provider_path, "w", encoding="utf-8") as f:
    f.write(provider_code)


# 2. Update BookingDetailsScreen
details_path = os.path.join(base_dir, "features", "booking", "booking_details_screen.dart")
details_code = """import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/booking/domain/booking_model.dart' as bm;

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchActiveBooking();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final booking = provider.activeBooking;

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back_ios_new,
                        size: 18, color: AppColors.textDark),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Booking Details', style: AppTextStyles.subheading),
                      Text('# ${booking.bookingNumber.isNotEmpty ? booking.bookingNumber : booking.id.substring(0,8)}', style: AppTextStyles.body),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressIndicator(booking.status),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.directions_car),
                                  ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${booking.vehicle?.make ?? ''} ${booking.vehicle?.model ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text('${booking.vehicle?.licensePlate ?? ''}',
                                        style: const TextStyle(color: AppColors.textLight)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28),
                          _row(Icons.auto_awesome, 'service', booking.service?.name ?? 'Wash'),
                          const SizedBox(height: 12),
                          _row(Icons.location_on_outlined, 'location',
                              '${booking.address?.line1 ?? ''}\\n${booking.address?.city ?? ''}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount', style: AppTextStyles.subheading),
                        Text('\u20b9${booking.finalTotalAmount}',
                            style: AppTextStyles.subheading
                                .copyWith(color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (booking.partner != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Icon(Icons.person, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(booking.partner!.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 14),
                                      const SizedBox(width: 4),
                                      Text('${booking.partner!.rating}', style: AppTextStyles.body),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                                onPressed: () {},
                                icon: Icon(Icons.call_outlined, color: AppColors.primary)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppButton(
                text: 'Refresh',
                onPressed: () => provider.fetchActiveBooking(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProgressIndicator(bm.BookingStatus status) {
    String currentStatus = 'Confirmed';
    if (status == bm.BookingStatus.partnerAssigned) currentStatus = 'Partner Assigned';
    if (status == bm.BookingStatus.providerOnTheWay) currentStatus = 'Partner On The Way';
    if (status == bm.BookingStatus.arrived) currentStatus = 'Arrived';
    if (status == bm.BookingStatus.serviceStarted || status == bm.BookingStatus.serviceInProgress) currentStatus = 'In Progress';
    if (status == bm.BookingStatus.completed || status == bm.BookingStatus.serviceCompleted) currentStatus = 'Completed';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12)
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Status: $currentStatus', style: AppTextStyles.subheading.copyWith(color: AppColors.primary)),
          )
        ]
      )
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textLight),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.body.copyWith(fontSize: 12)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ],
          ),
        ),
      ],
    );
  }
}
"""
with open(details_path, "w", encoding="utf-8") as f:
    f.write(details_code)

# 3. Update Home Dashboard
dashboard_path = os.path.join(base_dir, "features", "home", "home_dashboard_screen.dart")
with open(dashboard_path, "r", encoding="utf-8") as f:
    dashboard_code = f.read()

# Add provider import
dashboard_code = dashboard_code.replace("import 'package:starq_app/app/theme/app_theme.dart';", "import 'package:starq_app/app/theme/app_theme.dart';\nimport 'package:provider/provider.dart';\nimport 'package:starq_app/features/providers/booking_provider.dart';")

# Change to StatefulWidget to fetch active booking on init
dashboard_code = dashboard_code.replace("class HomeDashboardScreen extends StatelessWidget {", """class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});
  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}
class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchActiveBooking();
    });
  }""")

dashboard_code = dashboard_code.replace("  const HomeDashboardScreen({super.key});\n\n  @override\n  Widget build(BuildContext context) {", "  @override\n  Widget build(BuildContext context) {\n    final provider = context.watch<BookingProvider>();\n    final activeBooking = provider.activeBooking;")

# Replace Upcoming bookings banner
upcoming_section = """              // Upcoming bookings
              if (activeBooking != null)
              HoverCard(
                onTap: () => context.push('/booking-details'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.textDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Active Booking',
                                style: AppTextStyles.subheading
                                    .copyWith(color: Colors.white, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('${activeBooking.statusDisplay}',
                                style: AppTextStyles.body
                                    .copyWith(color: Colors.white70)),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/booking-details'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('View Details',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),"""

dashboard_code = re.sub(r"// Upcoming bookings.*?const SizedBox\(height: 12\),", upcoming_section + "\n              const SizedBox(height: 12),", dashboard_code, flags=re.DOTALL)

with open(dashboard_path, "w", encoding="utf-8") as f:
    f.write(dashboard_code)

print("Updated Flutter screens.")
