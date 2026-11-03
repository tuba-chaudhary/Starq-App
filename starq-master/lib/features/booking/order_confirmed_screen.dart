import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';
import 'package:intl/intl.dart';

class OrderConfirmedScreen extends StatelessWidget {
  const OrderConfirmedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookingFlow = context.watch<BookingFlowProvider>();
    final garage = context.watch<GarageProvider>();

    final vehicle = bookingFlow.vehicle ?? garage.selected;
    final vehicleTitle = vehicle != null
        ? '${vehicle.displayName} (${vehicle.registrationNumber.isNotEmpty ? vehicle.registrationNumber : "Registered"})'
        : 'Registered Vehicle';

    final serviceTitle = bookingFlow.service?.name ?? 'Professional Doorstep Wash';
    final dateStr = bookingFlow.date != null
        ? DateFormat('EEE, d MMM yyyy').format(bookingFlow.date!)
        : DateFormat('EEE, d MMM yyyy').format(DateTime.now());
    final timeStr = bookingFlow.timeSlot ?? '02:00 PM - 03:00 PM';

    final addressStr = bookingFlow.address?.fullAddress ??
        'B-14, Sector 62, Noida, Uttar Pradesh 201309';

    final bookingRef = 'STQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Order Confirmed'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.check_circle, size: 52, color: Colors.green.shade600),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Booking Confirmed!',
                style: AppTextStyles.heading.copyWith(fontSize: 24, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              Text(
                'Reference ID: $bookingRef',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 20),

              // LIVE SERVICE STATUS BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Service On The Way',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Our verified partner is scheduled to arrive at your location on $dateStr.',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // MAP PREVIEW CARD
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.7,
                              child: Image.asset(
                                'assets/images/exterior_wash.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: Colors.blueGrey.shade50),
                              ),
                            ),
                          ),
                          Container(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, color: AppColors.primary, size: 36),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Doorstep Service Location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _detailRow(Icons.auto_awesome, 'Service', serviceTitle),
                          const Divider(height: 18),
                          _detailRow(Icons.directions_car, 'Vehicle', vehicleTitle),
                          const Divider(height: 18),
                          _detailRow(Icons.calendar_month, 'Date & Time', '$dateStr · $timeStr'),
                          const Divider(height: 18),
                          _detailRow(Icons.place, 'Address', addressStr),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ACTION BUTTONS
              AppButton(
                text: 'Live Service Tracking',
                trailingIcon: Icons.my_location,
                onPressed: () {
                  context.push('/live-tracking', extra: bookingRef);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Go to Home Dashboard',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}