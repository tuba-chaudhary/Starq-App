import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:starq_app/core/utils/formatters.dart';
import 'package:starq_app/core/utils/json_helpers.dart';
import 'package:starq_app/features/booking/data/booking_repository.dart';
import 'package:starq_app/features/booking/domain/booking_model.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/custom_button.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String bookingId;
  const LiveTrackingScreen({super.key, required this.bookingId});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _repo = BookingRepository();
  Map<String, dynamic> _data = {};
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetch();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final data = await _repo.tracking(widget.bookingId);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _data['booking'] != null ? Booking.fromJson(asJsonMap(_data['booking'])) : null;
    final loc = _data['location'] is Map ? asJsonMap(_data['location']) : null;
    final active = _data['tracking_active'] == true;
    final reason = _data['reason']?.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(booking?.bookingNumber ?? 'Tracking')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: active ? Colors.green : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(booking?.statusDisplay ?? 'Updating…', style: AppTextStyles.subheading),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active ? Colors.green.shade300 : Colors.amber.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        active ? Icons.gps_fixed : Icons.info_outline,
                        color: active ? Colors.green.shade800 : Colors.amber.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          active
                              ? 'Live GPS active. Showing verified coordinates from partner device.'
                              : (reason != null && reason.isNotEmpty
                                  ? reason
                                  : 'Live GPS is not active for this booking status.'),
                          style: TextStyle(
                            fontSize: 13,
                            color: active ? Colors.green.shade900 : Colors.amber.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (booking?.partner != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(booking!.partner!.name),
                    subtitle: Text('Rating ${booking.partner!.rating} · ${booking.partner!.completedJobs} jobs'),
                  ),
                if (loc != null) ...[
                  Text('Partner location', style: AppTextStyles.subheading),
                  Text('Lat ${loc['latitude']} · Lng ${loc['longitude']}'),
                  Text('Updated ${loc['recorded_at'] ?? ''}'),
                  const SizedBox(height: 8),
                  AppButton(
                    text: 'Open in maps',
                    outlined: true,
                    onPressed: () {
                      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${loc['latitude']},${loc['longitude']}');
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                if (booking != null)
                  Text('${booking.service?.name ?? ''} · ${AppFormatters.date(booking.scheduledDate)} · ${booking.scheduledTimeSlot}'),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Booking details',
                  onPressed: () => context.push('/booking-details', extra: widget.bookingId),
                ),
              ],
            ),
    );
  }
}
