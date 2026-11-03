import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/vehicles/domain/vehicle.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';

class MyGarageScreen extends StatefulWidget {
  const MyGarageScreen({super.key});

  @override
  State<MyGarageScreen> createState() => _MyGarageScreenState();
}

class _MyGarageScreenState extends State<MyGarageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GarageProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<GarageProvider>(
          builder: (context, garage, _) {
            final vehicles = garage.vehicles;

            return Column(
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
                          Text('My Garage', style: AppTextStyles.subheading),
                          Text('${vehicles.length} Vehicle${vehicles.length == 1 ? '' : 's'}',
                              style: AppTextStyles.body),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => context.push('/add-vehicle'),
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                        tooltip: 'Add Vehicle',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (garage.loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (vehicles.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No Vehicles in Garage',
                                style: AppTextStyles.subheading),
                            const SizedBox(height: 8),
                            Text(
                              'Add your car or bike to easily book doorstep washes and detailing.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body.copyWith(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => context.push('/add-vehicle'),
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text('Add Vehicle Now',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ...vehicles.map((Vehicle v) {
                          final isBike = v.isBike;
                          final imageAsset = isBike
                              ? 'assets/images/bike image.png'
                              : 'assets/images/car image.png';
                          final isSelected = garage.selected?.id == v.id;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: GestureDetector(
                              onTap: () {
                                garage.select(v);
                                context.read<BookingFlowProvider>().startWithVehicle(v);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.asset(
                                            imageAsset,
                                            width: 64,
                                            height: 64,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => Container(
                                              width: 64,
                                              height: 64,
                                              color: Colors.grey.shade200,
                                              child: Icon(
                                                isBike ? Icons.two_wheeler : Icons.directions_car,
                                                color: Colors.grey,
                                              ),
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
                                                      '${v.brand} ${v.model}',
                                                      style: AppTextStyles.subheading
                                                          .copyWith(fontSize: 15),
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.shade50,
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: Colors.green.shade200),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.check, size: 10, color: Colors.green.shade700),
                                                          const SizedBox(width: 2),
                                                          Text(
                                                            'ACTIVE',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.green.shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  else if (v.isPrimary)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        'PRIMARY',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${v.registrationNumber} · ${v.category.name.toUpperCase()}',
                                                style: AppTextStyles.body,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.grey, size: 20),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Delete Vehicle'),
                                                content: Text(
                                                    'Remove ${v.brand} ${v.model} from your garage?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => ctx.pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => ctx.pop(true),
                                                    child: const Text('Delete',
                                                        style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await garage.remove(v.id);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton.icon(
                                            onPressed: () {
                                              garage.select(v);
                                              context.read<BookingFlowProvider>().startWithVehicle(v);
                                            },
                                            icon: Icon(
                                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                              size: 16,
                                              color: isSelected ? AppColors.primary : Colors.grey,
                                            ),
                                            label: Text(
                                              isSelected ? 'Active for Wash' : 'Set as Active',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isSelected ? AppColors.primary : Colors.grey.shade700,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            garage.select(v);
                                            context.read<BookingFlowProvider>().startWithVehicle(v);
                                            context.push('/service-selection', extra: {
                                              'vehicleId': v.id,
                                              'vehicleType': isBike ? 'bike' : 'car',
                                              'vehicleCategory': isBike ? 'bike' : v.category.name.toLowerCase(),
                                              'vehicleLabel': '${v.brand} ${v.model}',
                                              'vehiclePlate': v.registrationNumber,
                                            });
                                          },
                                          icon: const Icon(Icons.local_car_wash, size: 14, color: Colors.white),
                                          label: const Text('Book Wash', style: TextStyle(color: Colors.white, fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            minimumSize: const Size(0, 32),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/add-vehicle'),
                          icon: Icon(Icons.add, color: AppColors.textDark),
                          label: const Text('Add New Vehicle'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}