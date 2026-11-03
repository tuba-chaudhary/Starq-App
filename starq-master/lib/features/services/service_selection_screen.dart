import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/vehicles/domain/vehicle.dart';
import 'package:starq_app/features/services/domain/service_package.dart';

class ServiceSelectionScreen extends StatefulWidget {
  final Map<String, dynamic>? data;
  const ServiceSelectionScreen({super.key, this.data});

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  VehicleCategory? _selectedCategory;
  String? _selectedVehicleId;
  bool _userSwitchedCategory = false;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.data?['vehicleId'] as String?;
    final rawCat = widget.data?['vehicleCategory'] as String?;
    final rawType = widget.data?['vehicleType'] as String?;
    if (rawCat != null && rawCat.isNotEmpty) {
      _selectedCategory = _parseCategory(rawCat);
    } else if (rawType == 'bike') {
      _selectedCategory = VehicleCategory.bike;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final garage = context.read<GarageProvider>();
      if (garage.vehicles.isEmpty && !garage.loading) {
        garage.load();
      }
    });
  }

  static VehicleCategory _parseCategory(String value) {
    switch (value.toLowerCase()) {
      case 'bike':
        return VehicleCategory.bike;
      case 'sedan':
        return VehicleCategory.sedan;
      case 'muv':
        return VehicleCategory.muv;
      case 'suv':
        return VehicleCategory.suv;
      case 'luxury':
        return VehicleCategory.luxury;
      case 'hatchback':
      default:
        return VehicleCategory.hatchback;
    }
  }

  Vehicle? _resolveVehicle(GarageProvider garage) {
    if (garage.vehicles.isEmpty) return null;

    // 1. If explicit vehicleId was selected or passed, find matching
    if (_selectedVehicleId != null && _selectedVehicleId!.isNotEmpty) {
      final match = garage.vehicles.where((v) => v.id == _selectedVehicleId).firstOrNull;
      if (match != null) return match;
    }

    // 2. Check garage.selected
    if (garage.selected != null) {
      final match = garage.vehicles.where((v) => v.id == garage.selected!.id).firstOrNull;
      if (match != null) return match;
    }

    // 3. Check isPrimary vehicle
    final primary = garage.vehicles.where((v) => v.isPrimary).firstOrNull;
    if (primary != null) return primary;

    // 4. Default to first vehicle
    return garage.vehicles.first;
  }

  VehicleCategory _resolveCategory(Vehicle? vehicle) {
    if (_userSwitchedCategory && _selectedCategory != null) {
      return _selectedCategory!;
    }
    if (vehicle != null) {
      return vehicle.category;
    }
    if (_selectedCategory != null) {
      return _selectedCategory!;
    }
    return VehicleCategory.hatchback;
  }

  @override
  Widget build(BuildContext context) {
    final garage = context.watch<GarageProvider>();
    final bookingProvider = context.watch<BookingProvider>();

    // Honest loading state when fetching saved vehicles for the first time
    if (garage.loading && garage.vehicles.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, vehicleText: 'Loading vehicle details...'),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Fetching your saved vehicles & catalog...',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error state if loading failed and no vehicles exist
    if (garage.error != null && garage.vehicles.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, vehicleText: 'Error loading vehicles'),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(garage.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => garage.load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final vehicle = _resolveVehicle(garage);
    final category = _resolveCategory(vehicle);

    final String vehicleSubtitle;
    if (vehicle != null) {
      vehicleSubtitle = '${vehicle.registrationNumber.toUpperCase()} · ${vehicle.displayName}';
    } else {
      vehicleSubtitle = 'No vehicle selected · Details required at checkout';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              context,
              vehicleText: vehicleSubtitle,
              vehicle: vehicle,
              garage: garage,
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Saved Vehicle Switcher (if user has multiple vehicles)
                    if (garage.vehicles.length > 1) ...[
                      Text('Saved Vehicles',
                          style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: garage.vehicles.map((v) {
                            final isSelected = vehicle?.id == v.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  '${v.registrationNumber.toUpperCase()} (${v.category.displayName})',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textDark,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                backgroundColor: Colors.grey.shade100,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _selectedVehicleId = v.id;
                                      _selectedCategory = v.category;
                                      _userSwitchedCategory = false;
                                    });
                                    garage.select(v);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Category Selector (when user has no saved vehicle or wants to explore other categories)
                    if (vehicle == null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Select Vehicle Category',
                              style: AppTextStyles.subheading.copyWith(fontSize: 14)),
                          TextButton.icon(
                            onPressed: () => context.push('/add-vehicle'),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Vehicle', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            VehicleCategory.bike,
                            VehicleCategory.hatchback,
                            VehicleCategory.sedan,
                            VehicleCategory.muv,
                            VehicleCategory.suv,
                            VehicleCategory.luxury,
                          ].map((cat) {
                            final isSelected = category == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                key: Key('category_chip_${cat.name}'),
                                label: Text(cat.displayName),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textDark,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                backgroundColor: Colors.grey.shade100,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _selectedCategory = cat;
                                      _userSwitchedCategory = true;
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Current Category Header & Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category == VehicleCategory.bike ? 'Bike Services' : 'Car Wash Packages',
                          style: AppTextStyles.subheading,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category.displayName.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Service List
                    if (category == VehicleCategory.bike)
                      ..._buildBikeServices(context, vehicle, bookingProvider)
                    else
                      ..._buildCarPackages(context, vehicle, category, bookingProvider),

                    const SizedBox(height: 24),

                    // Why Choose STARQ
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Why choose STARQ?', style: AppTextStyles.subheading),
                          const SizedBox(height: 8),
                          Text(
                            'We use premium eco-friendly products and professional '
                            'tools to ensure your vehicle gets the care it deserves. '
                            'Every service includes a quality check by our certified '
                            'experts.',
                            style: AppTextStyles.body,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: const [
                              _Badge('ECO-FRIENDLY'),
                              SizedBox(width: 16),
                              _Badge('VERIFIED EXPERTS'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 16, color: AppColors.textLight),
                        const SizedBox(width: 6),
                        Text('STARQ SECURE CHECKOUT',
                            style: AppTextStyles.body.copyWith(
                                fontSize: 11, letterSpacing: 0.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String vehicleText,
    Vehicle? vehicle,
    GarageProvider? garage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: () => context.pop(),
              icon: Icon(Icons.arrow_back_ios_new,
                  size: 16, color: AppColors.textDark),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose a Service', style: AppTextStyles.subheading),
                const SizedBox(height: 2),
                Text(
                  vehicleText,
                  style: AppTextStyles.body.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBikeServices(
    BuildContext context,
    Vehicle? vehicle,
    BookingProvider bookingProvider,
  ) {
    return kBikeServicePackages.map((bikePkg) {
      final matchingService = bookingProvider.services.where((s) {
        return s.id == bikePkg.id || s.name.trim().toLowerCase() == bikePkg.title.trim().toLowerCase();
      }).firstOrNull;

      final variantId = matchingService?.variants.isNotEmpty == true
          ? matchingService!.variants.first.id
          : bikePkg.variantId;

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _ServiceCard(
          image: bikePkg.image,
          title: bikePkg.title,
          subtitle: bikePkg.description,
          duration: bikePkg.duration,
          price: bikePkg.displayPrice,
          inclusionsSummary: bikePkg.inclusions.take(3).join(' • '),
          onTap: () {
            if (matchingService != null) {
              bookingProvider.selectService(matchingService);
            }
            context.push(bikePkg.route, extra: {
              ...?widget.data,
              'vehicleId': vehicle?.id,
              'vehicleType': 'bike',
              'vehicleCategory': 'bike',
              'vehicleLabel': vehicle != null ? '${vehicle.brand} ${vehicle.model}' : null,
              'vehiclePlate': vehicle?.registrationNumber,
              'serviceId': bikePkg.id,
              'variantId': variantId,
              'serviceTitle': bikePkg.title,
              'packageTitle': bikePkg.title,
              'servicePrice': bikePkg.displayPrice,
              'duration': bikePkg.duration,
              'description': bikePkg.description,
              'inclusions': {
                'Included Services': bikePkg.inclusions,
              },
            });
          },
        ),
      );
    }).toList();
  }

  List<Widget> _buildCarPackages(
    BuildContext context,
    Vehicle? vehicle,
    VehicleCategory category,
    BookingProvider bookingProvider,
  ) {
    // Strictly excludes Luxury Silver
    final packages = getPackagesForCategory(category);

    return packages.map((pkg) {
      final price = pkg.getPrice(category);
      if (price == null) return const SizedBox.shrink();

      final displayPrice = price >= 1000
          ? '₹${price ~/ 1000},${(price % 1000).toString().padLeft(3, '0')}'
          : '₹$price';

      final matchingService = bookingProvider.services.where((s) {
        return s.id == pkg.backendServiceId;
      }).firstOrNull;

      final variantId = matchingService?.variants.isNotEmpty == true
          ? matchingService!.variants.first.id
          : null;

      final allInclusions = pkg.getAllInclusions(category);
      final inclusionsSummary = allInclusions.take(3).join(' • ');

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _ServiceCard(
          image: pkg.image,
          title: pkg.fullCustomerTitle,
          subtitle: pkg.getDescription(category),
          duration: pkg.duration,
          price: displayPrice,
          inclusionsSummary: inclusionsSummary,
          tierBadge: pkg.customerName,
          onTap: () {
            if (matchingService != null) {
              bookingProvider.selectService(matchingService);
            }
            context.push(pkg.route, extra: {
              ...?widget.data,
              'vehicleId': vehicle?.id,
              'vehicleType': 'car',
              'vehicleCategory': category.name.toLowerCase(),
              'vehicleLabel': vehicle != null ? '${vehicle.brand} ${vehicle.model}' : null,
              'vehiclePlate': vehicle?.registrationNumber,
              'packageTier': pkg.tier.name.toUpperCase(),
              'serviceId': pkg.backendServiceId,
              'variantId': variantId,
              'serviceTitle': pkg.fullCustomerTitle,
              'packageTitle': pkg.fullCustomerTitle,
              'servicePrice': displayPrice,
              'duration': pkg.duration,
              'description': pkg.getDescription(category),
              'inclusions': pkg.getInclusions(category),
            });
          },
        ),
      );
    }).toList();
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 6, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(text,
            style: AppTextStyles.body
                .copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  final String duration;
  final String price;
  final String inclusionsSummary;
  final String? tierBadge;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.price,
    required this.inclusionsSummary,
    this.tierBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/$image',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.local_car_wash, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTextStyles.subheading.copyWith(fontSize: 16),
                            ),
                          ),
                          if (tierBadge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tierBadge!,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 13, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(duration, style: AppTextStyles.body.copyWith(fontSize: 12)),
                          const SizedBox(width: 12),
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text('4.8', style: AppTextStyles.body.copyWith(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        price,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: AppTextStyles.body.copyWith(fontSize: 12, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (inclusionsSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      inclusionsSummary,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}