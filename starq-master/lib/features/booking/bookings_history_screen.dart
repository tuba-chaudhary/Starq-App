import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starq_app/core/utils/formatters.dart';
import 'package:starq_app/core/errors/app_exception.dart';
import 'package:starq_app/features/booking/data/booking_repository.dart';
import 'package:starq_app/features/booking/domain/booking_model.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/bottom_nav_bar.dart';

class BookingsHistoryScreen extends StatefulWidget {
  const BookingsHistoryScreen({super.key});

  @override
  State<BookingsHistoryScreen> createState() => _BookingsHistoryScreenState();
}

class _BookingsHistoryScreenState extends State<BookingsHistoryScreen> {
  final _repo = BookingRepository();
  List<Booking> _items = [];
  bool _loading = true;
  String? _error;
  String _tab = 'active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _repo.list();
      // Deduplicate bookings by ID
      final Map<String, Booking> uniqueMap = {};
      for (final b in items) {
        if (b.id.isNotEmpty) {
          uniqueMap[b.id] = b;
        }
      }
      final deduped = uniqueMap.values.toList();

      if (mounted) {
        setState(() {
          _items = deduped;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e is AppException
            ? e.message
            : 'Could not load bookings. Please check your connection and retry.';
        setState(() {
          _loading = false;
          _error = errorMsg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawActive = _items.where((b) => b.isActive || b.status == BookingStatus.pendingPayment).toList();
    final List<Booking> active = [];
    final confirmedKeys = <String>{};
    for (final b in rawActive) {
      if (b.isActive && b.status != BookingStatus.pendingPayment) {
        final key = '${b.service?.id ?? b.service?.name}_${b.scheduledDate}_${b.scheduledTimeSlot}';
        confirmedKeys.add(key);
        active.add(b);
      }
    }
    for (final b in rawActive) {
      if (b.status == BookingStatus.pendingPayment) {
        final key = '${b.service?.id ?? b.service?.name}_${b.scheduledDate}_${b.scheduledTimeSlot}';
        if (!confirmedKeys.contains(key)) {
          active.add(b);
        }
      }
    }

    final completed = _items.where((b) => b.isCompleted || b.status == BookingStatus.customerFeedbackPending).toList();
    final cancelled = _items.where((b) => b.status == BookingStatus.cancelled || b.status == BookingStatus.refunded || b.status == BookingStatus.refundPending).toList();
    final shown = _tab == 'active' ? active : _tab == 'completed' ? completed : cancelled;

    Widget bodyContent;
    if (_loading && _items.isEmpty) {
      bodyContent = const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else if (_error != null && _items.isEmpty) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 14),
              Text('Unable to Load Bookings', style: AppTextStyles.subheading),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.body.copyWith(color: AppColors.textLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      bodyContent = Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _chip('active', 'Active (${active.length})'),
                _chip('completed', 'Completed (${completed.length})'),
                _chip('cancelled', 'Cancelled (${cancelled.length})'),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No Bookings in this Category', style: AppTextStyles.subheading),
                          const SizedBox(height: 6),
                          Text(
                            'Book a wash from the Home screen to view your schedule here.',
                            style: AppTextStyles.body.copyWith(color: AppColors.textLight),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final b = shown[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => context.push('/booking-details', extra: b.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.local_car_wash, color: AppColors.primary, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            b.bookingNumber,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: b.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              b.statusDisplay,
                                              style: TextStyle(
                                                color: b.isActive ? Colors.green.shade700 : AppColors.textLight,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        b.service?.name ?? 'Wash Service',
                                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${AppFormatters.date(b.scheduledDate)} · ${b.scheduledTimeSlot}',
                                        style: AppTextStyles.body.copyWith(color: AppColors.textLight, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppFormatters.currency(b.finalTotalAmount),
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: bodyContent,
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1, items: customerNavItems),
    );
  }

  Widget _chip(String id, String label) {
    final selected = _tab == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primaryLight,
        onSelected: (_) => setState(() => _tab = id),
      ),
    );
  }
}
