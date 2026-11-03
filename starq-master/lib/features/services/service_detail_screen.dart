import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/utils/formatters.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/services/data/service_repository.dart';
import 'package:starq_app/features/services/domain/add_on.dart';
import 'package:starq_app/features/services/domain/service_item.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/custom_button.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ServiceItem? service;
  const ServiceDetailScreen({super.key, this.service});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final _repo = ServiceRepository();
  List<AddOn> _addons = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAddons());
  }

  Future<void> _loadAddons() async {
    final flow = context.read<BookingFlowProvider>();
    final vehicle = flow.vehicle;
    if (vehicle == null) return;
    final items = await _repo.addOns(
      vehicleType: vehicle.isBike ? 'bike' : 'car',
      category: vehicle.category.name,
    );
    if (mounted) setState(() => _addons = items);
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<BookingFlowProvider>();
    final service = widget.service ?? flow.service;
    if (service == null) {
      return const Scaffold(body: Center(child: Text('Select a service first')));
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
                            'assets/images/${service.imageAssetPath}',
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.local_car_wash, size: 60, color: Colors.grey),
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
                              Expanded(child: Text(service.name, style: AppTextStyles.heading)),
                              Text(AppFormatters.currency(service.basePrice),
                                  style: AppTextStyles.heading.copyWith(color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('${service.durationDisplay} · ${service.rating}', style: AppTextStyles.body),
                          const SizedBox(height: 16),
                          Text(service.description, style: AppTextStyles.body),
                          const SizedBox(height: 20),
                          Text("What's Included", style: AppTextStyles.subheading),
                          const SizedBox(height: 12),
                          ...service.inclusions.entries.expand((e) => e.value.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(item, style: AppTextStyles.body)),
                                  ],
                                ),
                              ))),
                          const SizedBox(height: 16),
                          Text('Optional add-ons', style: AppTextStyles.subheading),
                          const SizedBox(height: 4),
                          Text('You can skip these.', style: AppTextStyles.body),
                          const SizedBox(height: 10),
                          ..._addons.map((addon) {
                            final selected = flow.selectedAddOns.any((a) => a.id == addon.id);
                            return CheckboxListTile(
                              value: selected,
                              activeColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                              title: Text(addon.name, style: AppTextStyles.subheading.copyWith(fontSize: 15)),
                              subtitle: Text('${addon.description} · ${AppFormatters.currency(addon.price)}'),
                              onChanged: (_) => flow.toggleAddOn(addon),
                            );
                          }),
                          TextButton(
                            onPressed: () {
                              flow.skipAddOns();
                            },
                            child: const Text('Skip add-ons'),
                          ),
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
                text: 'Continue',
                onPressed: () {
                  flow.setService(service);
                  context.push('/choose-location');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
