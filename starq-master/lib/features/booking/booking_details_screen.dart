import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/booking/domain/booking_model.dart' as bm;
import 'widgets/customer_tracking_map.dart';

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
                    const SizedBox(height: 16),
                    if (booking.partner != null && 
                        ['PARTNER_ASSIGNED', 'PARTNER_ON_THE_WAY', 'PARTNER_ARRIVED', 'SERVICE_STARTED', 'SERVICE_IN_PROGRESS']
                        .contains(booking.status.name.toUpperCase()))
                      SizedBox(
                        height: 250,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CustomerTrackingMap(
                            bookingId: booking.id,
                            destLat: booking.address?.latitude ?? 0.0,
                            destLng: booking.address?.longitude ?? 0.0,
                          ),
                        ),
                      ),
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
                                    Text('${booking.vehicle?.brand ?? ''} ${booking.vehicle?.model ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text('${booking.vehicle?.registrationNumber ?? ''}',
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
                              '${booking.address?.addressLine ?? ''}\n${booking.address?.city ?? ''}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount', style: AppTextStyles.subheading),
                        Text('₹${booking.finalTotalAmount}',
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
