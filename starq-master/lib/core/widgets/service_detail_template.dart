import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/models/service_model.dart';

/// Shared layout for Exterior Wash / Interior Wash / Full Detailing /
/// Premium Wash detail screens — each of those screens is just this
/// template with different data passed in.
class ServiceDetailTemplate extends StatelessWidget {
  final String image;
  final String title;
  final String price;
  final String duration;
  final String rating;
  final String description;
  final Map<String, List<String>> included; // section title -> items
  final String? serviceId;
  final Map<String, dynamic>? extraData;

  const ServiceDetailTemplate({
    super.key,
    required this.image,
    required this.title,
    required this.price,
    required this.duration,
    this.rating = '4.8',
    required this.description,
    required this.included,
    this.serviceId,
    this.extraData,
  });  @override
  Widget build(BuildContext context) {
    final displayTitle = extraData?['packageTitle'] as String? ?? extraData?['serviceTitle'] as String? ?? title;
    BookingProvider? provider;
    try {
      provider = Provider.of<BookingProvider>(context, listen: false);
    } catch (_) {}

    final String displayPrice;
    if (extraData?['servicePrice'] != null && extraData!['servicePrice'].toString().isNotEmpty) {
      displayPrice = extraData!['servicePrice'].toString();
    } else {
      Service? matched;
      final effectiveServiceId = serviceId ?? extraData?['serviceId'] as String?;
      if (provider != null) {
        if (effectiveServiceId != null && effectiveServiceId.isNotEmpty) {
          matched = provider.services.where((s) => s.id == effectiveServiceId).firstOrNull;
        }
        if (matched == null) {
          matched = provider.services.where((s) => s.name.trim().toLowerCase() == title.trim().toLowerCase()).firstOrNull;
        }
      }
      if (matched != null && matched.variants.isNotEmpty) {
        final p = matched.variants.first.price.toInt();
        displayPrice = p >= 1000
            ? '₹${p ~/ 1000},${(p % 1000).toString().padLeft(3, '0')}'
            : '₹$p';
      } else {
        displayPrice = price;
      }
    }
    final displayDesc = extraData?['description'] as String? ?? description;
    Map<String, List<String>> displayInclusions;
    final rawInclusions = extraData?['inclusions'];
    if (rawInclusions is Map) {
      displayInclusions = rawInclusions.map(
        (key, value) => MapEntry(
          key.toString(),
          (value as List).map((e) => e.toString()).toList(),
        ),
      );
    } else if (rawInclusions is List) {
      displayInclusions = {
        'Included Services': rawInclusions.map((e) => e.toString()).toList(),
      };
    } else {
      displayInclusions = included;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 1.1,
                          child: Image.asset(
                            'assets/images/$image',
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.local_car_wash,
                                  size: 60, color: Colors.grey),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              child: IconButton(
                                onPressed: () => context.pop(),
                                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  displayTitle,
                                  style: AppTextStyles.heading.copyWith(fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                displayPrice,
                                style: AppTextStyles.heading
                                    .copyWith(color: AppColors.primary, fontSize: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(duration, style: AppTextStyles.body),
                              const SizedBox(width: 12),
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(rating, style: AppTextStyles.body),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(displayDesc, style: AppTextStyles.body),
                          const SizedBox(height: 20),
                          Text("What's Included", style: AppTextStyles.subheading),
                          const SizedBox(height: 12),
                          ...displayInclusions.entries.map((entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (entry.key.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          entry.key,
                                          style: AppTextStyles.body.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                    ...entry.value.map((item) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.check_circle,
                                                  size: 16, color: AppColors.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item,
                                                  style: AppTextStyles.body.copyWith(fontSize: 13),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: AppButton(
                text: 'Book This Service',
                onPressed: () {
                  final provider = Provider.of<BookingProvider>(context, listen: false);
                  String? effectiveServiceId = serviceId ?? extraData?['serviceId'] as String?;
                  Service? resolvedService;

                  // 1. If explicit serviceId was provided, verify it exists in catalog
                  if (effectiveServiceId != null && effectiveServiceId.isNotEmpty) {
                    for (final s in provider.services) {
                      if (s.id == effectiveServiceId) {
                        resolvedService = s;
                        break;
                      }
                    }
                  }

                  // 2. If not yet resolved by ID, match strictly by exact name or package content
                  if (resolvedService == null) {
                    for (final s in provider.services) {
                      if (s.name.trim().toLowerCase() == title.trim().toLowerCase() ||
                          s.name.trim().toLowerCase() == displayTitle.trim().toLowerCase() ||
                          displayTitle.trim().toLowerCase().contains(s.name.trim().toLowerCase())) {
                        resolvedService = s;
                        effectiveServiceId = s.id;
                        break;
                      }
                    }
                  }

                  // 3. If unmapped to any valid backend service, BLOCK booking and show clear error
                  if (resolvedService == null || effectiveServiceId == null || effectiveServiceId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Service "$displayTitle" is not available in the catalog. Booking cannot proceed.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // 4. Vehicle category compatibility validation
                  final vehicleCategoryParam = (extraData?['vehicleCategory'] as String?)?.toLowerCase();
                  final vehicleTypeParam = (extraData?['vehicleType'] as String?)?.toLowerCase();
                  final selectedVehicle = provider.selectedVehicle;
                  final serviceCategory = resolvedService.category.toUpperCase();

                  // Luxury category does NOT have Silver
                  final isLuxury = vehicleCategoryParam == 'luxury' || selectedVehicle?.category?.toLowerCase() == 'luxury';
                  final isSilver = displayTitle.toLowerCase().contains('silver') ||
                      title.toLowerCase().contains('exterior wash') ||
                      resolvedService.name.toLowerCase().contains('basic wash') ||
                      resolvedService.id == 'a0000001-0000-4000-8000-000000000001' ||
                      resolvedService.id == '9eaa3c73-830c-402f-afae-106488ec19c6';

                  if (isLuxury && isSilver) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Silver package is not available for Luxury vehicles. Please choose Gold, Diamond, or Platinum.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final bool isBikeSelected;
                  final bool isCarSelected;
                  if (vehicleTypeParam == 'bike' || vehicleCategoryParam == 'bike') {
                    isBikeSelected = true;
                    isCarSelected = false;
                  } else if (vehicleTypeParam == 'car' || vehicleCategoryParam != null) {
                    isBikeSelected = false;
                    isCarSelected = true;
                  } else if (selectedVehicle != null) {
                    isBikeSelected = selectedVehicle.isBike;
                    isCarSelected = !selectedVehicle.isBike;
                  } else {
                    isBikeSelected = (serviceCategory == 'BIKE');
                    isCarSelected = (serviceCategory == 'CAR');
                  }

                  if (serviceCategory == 'CAR' && isBikeSelected && !isCarSelected) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Service "${resolvedService.name}" is for cars only. Please select a car.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (serviceCategory == 'BIKE' && isCarSelected && !isBikeSelected) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Service "${resolvedService.name}" is for bikes only. Please select a bike.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  provider.selectService(resolvedService);

                  final variantId = resolvedService.variants.isNotEmpty
                      ? resolvedService.variants.first.id
                      : null;

                  final String? forwardVehicleId;
                  if (extraData?['vehicleId'] != null && extraData!['vehicleId'].toString().isNotEmpty) {
                    forwardVehicleId = extraData!['vehicleId'].toString();
                  } else if (selectedVehicle != null) {
                    final vehicleMatches = (serviceCategory == 'BIKE' && selectedVehicle.isBike) ||
                        (serviceCategory == 'CAR' && !selectedVehicle.isBike);
                    forwardVehicleId = vehicleMatches ? selectedVehicle.id : null;
                  } else {
                    forwardVehicleId = null;
                  }

                  context.push(
                    '/select-date-time',
                    extra: {
                      ...?extraData,
                      'vehicleId': forwardVehicleId,
                      'serviceId': effectiveServiceId,
                      'variantId': variantId,
                      'serviceTitle': displayTitle,
                      'serviceCategory': resolvedService.category,
                      'vehicleCategory': vehicleCategoryParam,
                      'vehicleType': vehicleTypeParam ?? (serviceCategory == 'BIKE' ? 'bike' : 'car'),
                      'servicePrice': displayPrice,
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}