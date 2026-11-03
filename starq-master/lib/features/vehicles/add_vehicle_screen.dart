import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/utils/validators.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/vehicles/domain/vehicle.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/core/widgets/custom_text_field.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _variant = TextEditingController();
  final _plate = TextEditingController();
  final _color = TextEditingController();
  VehicleCategory _category = VehicleCategory.hatchback;
  bool _saving = false;

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _variant.dispose();
    _plate.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final brandText = _brand.text.trim();
    final modelText = _model.text.trim();
    final plateText = _plate.text.trim();

    if (brandText.isEmpty || modelText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter brand (e.g. Honda) and model (e.g. City).')),
      );
      return;
    }

    final plateError = AppValidators.registrationNumber(plateText);
    if (plateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(plateError)),
      );
      return;
    }

    final normalizedPlate = AppValidators.normalizeRegistrationNumber(plateText);

    setState(() => _saving = true);
    final ok = await context.read<GarageProvider>().add({
      'category': _category.name,
      'make': brandText,
      'brand': brandText,
      'model': modelText,
      'variant': _variant.text.trim(),
      'registration_number': normalizedPlate,
      'licensePlate': normalizedPlate,
      'color': _color.text.trim(),
      'is_primary': context.read<GarageProvider>().vehicles.isEmpty,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      final vehicle = context.read<GarageProvider>().selected;
      if (vehicle != null) context.read<BookingFlowProvider>().startWithVehicle(vehicle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle added successfully!')),
      );
      if (context.canPop()) {
        context.pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<GarageProvider>().error ?? 'Could not save vehicle')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Add vehicle')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Vehicle category', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: VehicleCategory.values.map((c) {
              final selected = c == _category;
              return ChoiceChip(
                label: Text(c.name.toUpperCase()),
                selected: selected,
                selectedColor: AppColors.primaryLight,
                onSelected: (_) => setState(() => _category = c),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          CustomTextField(hintText: 'Brand (e.g. Honda, Maruti, Hyundai)', controller: _brand),
          const SizedBox(height: 12),
          CustomTextField(hintText: 'Model (e.g. City, Swift, Creta)', controller: _model),
          const SizedBox(height: 12),
          CustomTextField(hintText: 'Variant (e.g. ZX, VXI - optional)', controller: _variant),
          const SizedBox(height: 12),
          CustomTextField(
            hintText: 'Registration Number (e.g. DL 01 AB 1234)',
            controller: _plate,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          CustomTextField(hintText: 'Color (e.g. White, Grey - optional)', controller: _color),
          const SizedBox(height: 24),
          AppButton(text: 'Save vehicle', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
