import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/booking/payment_service.dart';
import 'package:starq_app/core/config/env_config.dart';
import 'package:starq_app/features/points/points_repository.dart';

class BookingSummaryScreen extends StatefulWidget {
  final Map<String, dynamic>? data;
  const BookingSummaryScreen({super.key, this.data});

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _isSubmitting = false;
  String? _checkoutIdempotencyKey;

  @override
  void initState() {
    super.initState();
    _checkoutIdempotencyKey = 'starq_idem_${DateTime.now().millisecondsSinceEpoch}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<BookingProvider>(context, listen: false);
      final rawVId = widget.data?['vehicleId'] as String?;
      final sId = widget.data?['serviceId'] as String? ?? provider.selectedService?.id;
      final vehicleType = (widget.data?['vehicleType'] as String?)?.toLowerCase();
      final serviceCategory = (widget.data?['serviceCategory'] as String?)?.toUpperCase();
      final vehicleCategory = (widget.data?['vehicleCategory'] as String?)?.toLowerCase();

      String? vId = (rawVId != null && rawVId.isNotEmpty) ? rawVId : null;
      if (vId == null && provider.selectedVehicle != null) {
        final isBike = vehicleType == 'bike' || serviceCategory == 'BIKE';
        final vehicleIsBike = provider.selectedVehicle!.isBike;
        if (isBike == vehicleIsBike) {
          vId = provider.selectedVehicle!.id;
        }
      }

      if (sId != null && sId.isNotEmpty) {
        provider.getQuote(
          vehicleId: vId,
          serviceId: sId,
          vehicleCategory: vehicleCategory,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BookingProvider>(context);
    final quote = provider.currentQuote;

    final serviceTitle = quote?.serviceName.isNotEmpty == true
        ? quote!.serviceName
        : (widget.data?['serviceTitle'] ?? provider.selectedService?.name ?? 'Service');
    final servicePrice = widget.data?['servicePrice'];
    final vehicleCategory = (widget.data?['vehicleCategory'] as String?)?.toLowerCase();
    final rawVId = widget.data?['vehicleId'] as String?;
    final vehicleLabel = widget.data?['vehicleLabel'] ?? 'Vehicle';
    final vehiclePlate = widget.data?['vehiclePlate'] ?? 'Plate';

    final String vehicleDisplayText;
    if (rawVId != null && rawVId.isNotEmpty) {
      vehicleDisplayText = '$vehicleLabel · $vehiclePlate';
    } else if (provider.selectedVehicle != null) {
      vehicleDisplayText = '${provider.selectedVehicle!.make} ${provider.selectedVehicle!.model} · ${provider.selectedVehicle!.licensePlate ?? ''}';
    } else {
      vehicleDisplayText = '${(vehicleCategory ?? 'Vehicle').toUpperCase()} · Details required';
    }
    final date = widget.data?['date'] as DateTime?;
    final time = widget.data?['time'] ?? '--';
    final locationLabel = widget.data?['locationLabel'] ?? 'Location';
    final locationAddress = widget.data?['locationAddress'] ?? '';

    final priceValue = quote != null
        ? quote.basePrice.toInt()
        : (servicePrice != null
            ? (int.tryParse(servicePrice.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
            : 0);
    const convenienceFee = 0;
    final total = quote != null
        ? quote.total.toInt()
        : priceValue;
    final points = pointsForAmount(total);

    final dateStr = date != null
        ? '${date.day} ${_monthShort(date.month)}, ${date.year}'
        : 'Not selected';

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
                      Text('Booking Summary', style: AppTextStyles.subheading),
                      Text('Review your booking details', style: AppTextStyles.body),
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row(Icons.directions_car_outlined, 'vehicle',
                              vehicleDisplayText),
                          const SizedBox(height: 12),
                          _row(Icons.auto_awesome, 'service', serviceTitle),
                          const SizedBox(height: 12),
                          _row(Icons.calendar_today_outlined, 'date & time',
                              '$dateStr · $time'),
                          const SizedBox(height: 12),
                          _row(Icons.location_on_outlined, 'location',
                              '$locationLabel\n$locationAddress'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Price Breakdown', style: AppTextStyles.subheading),
                    const SizedBox(height: 10),
                    _priceRow(serviceTitle.toString().toLowerCase(), '₹$priceValue'),
                    if (quote != null && quote.addonsTotal > 0) ...[
                      const SizedBox(height: 8),
                      _priceRow('add-ons', '₹${quote.addonsTotal.toInt()}'),
                    ],
                    const SizedBox(height: 8),
                    _priceRow('convenience fee', '₹$convenienceFee'),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: AppTextStyles.subheading),
                        Text('₹$total',
                            style: AppTextStyles.subheading
                                .copyWith(color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.card_giftcard, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    style: AppTextStyles.body,
                                    children: [
                                      const TextSpan(text: "Estimated Earning: "),
                                      TextSpan(
                                        text: '~$points STARQ points',
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '5 points per ₹100 paid • Awarded after service completion and payment',
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.stars_outlined, color: Colors.grey.shade500),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Redeem STARQ Points',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '1 pt = ₹1 (up to 30% off) • Coming soon at checkout',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Coming Soon',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Test Mode Guidance Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                              const SizedBox(width: 6),
                              Text(
                                'Razorpay Test Mode Active',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• For UPI: enter "success@razorpay"\n• For Card: enter "4111 1111 1111 1111" (any date/cvv)\n(Do not use real bank UPI IDs in test mode)',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 16, color: AppColors.textLight),
                          const SizedBox(width: 6),
                          Text('100% Secure Payment · encrypted checkout',
                              style: AppTextStyles.body.copyWith(fontSize: 11)),
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
                text: _isSubmitting ? 'Processing...' : 'Continue to Payment',
                isLoading: _isSubmitting,
                onPressed: () async {
                  if (_isSubmitting) return;
                  final provider = Provider.of<BookingProvider>(context, listen: false);
                  final dataParams = widget.data ?? {};
                  final rawAddressId = dataParams['addressId'] as String?;
                  final addressId = (rawAddressId != null && rawAddressId.trim().isNotEmpty) ? rawAddressId.trim() : null;

                  if (addressId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a valid service address to continue'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final date = dataParams['date'] as DateTime? ?? DateTime.now();

                  String? serviceId = (dataParams['serviceId'] as String?)?.trim();
                  if (serviceId == null || serviceId.isEmpty) {
                    serviceId = provider.selectedService?.id.trim();
                  }
                  if (serviceId == null || serviceId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a valid service to continue'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() => _isSubmitting = true);
                  try {
                    final rawVId = dataParams['vehicleId'] as String?;
                    final vehicleType = (dataParams['vehicleType'] as String?)?.toLowerCase();
                    final serviceCategory = (dataParams['serviceCategory'] as String?)?.toUpperCase();
                    final vehicleCategory = (dataParams['vehicleCategory'] as String?)?.toLowerCase();
                    String? vId = (rawVId != null && rawVId.isNotEmpty) ? rawVId : null;
                    if (vId == null && provider.selectedVehicle != null) {
                      final isBike = vehicleType == 'bike' || serviceCategory == 'BIKE';
                      final vehicleIsBike = provider.selectedVehicle!.isBike;
                      if (isBike == vehicleIsBike) {
                        vId = provider.selectedVehicle!.id;
                      }
                    }

                    final rawPlate = dataParams['vehiclePlate'] as String?;
                    final hasVehicleDetails = (vId != null && vId.isNotEmpty) || (rawPlate != null && rawPlate.trim().isNotEmpty);

                    if (!hasVehicleDetails) {
                      setState(() => _isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please add your ${vehicleCategory?.toUpperCase() ?? 'vehicle'} details to complete booking'),
                          backgroundColor: Colors.orange.shade800,
                        ),
                      );
                      await context.push('/add-vehicle', extra: {'category': vehicleCategory});
                      return;
                    }

                    final bookingRes = await provider.createBooking(
                      addressId,
                      date,
                      vehicleId: vId,
                      serviceId: serviceId,
                      vehicleCategory: vehicleCategory,
                      idempotencyKey: _checkoutIdempotencyKey,
                    );
                    if (!context.mounted) return;

                    if (bookingRes == null || bookingRes['orderId'] == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(provider.error ?? 'Failed to create booking. Please verify service and address.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final orderId = bookingRes['orderId'].toString();

                    // If mock/test order in development, verify directly
                    if (orderId.startsWith('order_mock_')) {
                      await provider.verifyPayment(
                        orderId,
                        'pay_test_${DateTime.now().millisecondsSinceEpoch}',
                        'sig_test_mock',
                      );
                      if (context.mounted) {
                        context.go('/order-confirmed');
                      }
                      return;
                    }

                    final paymentService = PaymentService();
                    paymentService.onSuccess = (response) async {
                      await provider.verifyPayment(
                        response.orderId ?? orderId,
                        response.paymentId ?? '',
                        response.signature ?? '',
                      );
                      if (context.mounted) {
                        context.go('/order-confirmed');
                      }
                    };
                    paymentService.onFailure = (response) {
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Payment Status'),
                            ],
                          ),
                          content: Text(
                            response.message != null && response.message!.contains('UPI')
                                ? 'You entered an invalid UPI ID for test mode.\n\nIn Razorpay Test Mode, please use:\nsuccess@razorpay'
                                : (response.message ?? 'Payment was cancelled or failed. Please retry.'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    };
                    paymentService.openCheckout(
                      orderId: orderId,
                      amount: (quote?.total ?? (bookingRes['booking']?['totalAmount'] as num?)?.toDouble() ?? total.toDouble()),
                      keyId: EnvConfig.razorpayKeyId,
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _isSubmitting = false);
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
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

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body),
        Text(value, style: const TextStyle(color: AppColors.textDark)),
      ],
    );
  }

  String _monthShort(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month - 1];
  }
}