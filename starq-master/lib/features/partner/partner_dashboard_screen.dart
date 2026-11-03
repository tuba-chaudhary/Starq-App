import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/starq_logo.dart';
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StarqLogo(height: 24),
            const SizedBox(width: 8),
            Text('Partner', style: AppTextStyles.subheading.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
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
