import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/features/addresses/domain/address.dart' as addr_domain;
import 'package:starq_app/features/addresses/data/address_repository.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/providers/address_provider.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:starq_app/core/location/location_service.dart';
import 'package:starq_app/core/location/geocoding_service.dart';
import 'package:starq_app/core/errors/app_exception.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/core/widgets/custom_text_field.dart';
import 'package:starq_app/core/utils/validators.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _repo = AddressRepository();
  final _locationService = LocationService();
  final _geocodingService = GeocodingService();

  final _label = TextEditingController(text: 'Home');
  final _line = TextEditingController();
  final _landmark = TextEditingController();
  final _city = TextEditingController(text: 'Noida');
  final _pincode = TextEditingController(text: '201309');
  bool _saving = false;
  bool _detectingLocation = false;
  double _latitude = 28.6270;
  double _longitude = 77.3649;

  static const _coords = {
    '201309': [28.6270, 77.3649],
    '201301': [28.5703, 77.3219],
    '201307': [28.5708, 77.3624],
    '201304': [28.5074, 77.4096],
  };

  @override
  void dispose() {
    _label.dispose();
    _line.dispose();
    _landmark.dispose();
    _city.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _detectingLocation = true);
    try {
      final result = await _locationService.getDetailedCurrentPosition();
      if (!mounted) return;

      if (!result.isSuccess) {
        setState(() => _detectingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Could not detect location')),
        );
        return;
      }

      final pos = result.position!;
      _latitude = pos.latitude;
      _longitude = pos.longitude;

      final geocoded = await _geocodingService.reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;

      setState(() {
        _detectingLocation = false;
        if (geocoded != null) {
          final street = geocoded['street']?.toString() ?? '';
          final area = geocoded['area']?.toString() ?? '';
          final fullLine = [street, area].where((s) => s.isNotEmpty).join(', ');
          if (fullLine.isNotEmpty) _line.text = fullLine;

          final city = geocoded['city']?.toString() ?? '';
          if (city.isNotEmpty) _city.text = city;

          final pin = geocoded['pincode']?.toString() ?? '';
          if (pin.isNotEmpty) _pincode.text = pin;

          final label = geocoded['label']?.toString() ?? '';
          if (label.isNotEmpty && _label.text.isEmpty) _label.text = label;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Address detected! Please review and save.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _detectingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    }
  }

  Future<void> _save() async {
    final pin = _pincode.text.trim();
    final line = _line.text.trim();
    final pinErr = AppValidators.pincode(pin);

    if (line.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter house / street address')),
      );
      return;
    }
    if (pinErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pinErr)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final latlng = _coords[pin] ?? [_latitude, _longitude];
      final landmarkText = _landmark.text.trim();
      final line1Val = landmarkText.isNotEmpty ? '$line, Near $landmarkText' : line;
      final labelVal = _label.text.trim().isNotEmpty ? _label.text.trim() : 'Home';

      final addressData = {
        'line1': line1Val,
        'line2': labelVal,
        'city': _city.text.trim().isNotEmpty ? _city.text.trim() : 'Noida',
        'state': 'Uttar Pradesh',
        'zipCode': pin,
        'latitude': latlng[0],
        'longitude': latlng[1],
      };

      String? authUserId;
      try {
        authUserId = context.read<AuthProvider>().currentUser?.id;
      } catch (_) {}

      AddressProvider? addressProv;
      try {
        addressProv = context.read<AddressProvider>();
      } catch (_) {}

      addr_domain.Address? bookingAddr;
      if (addressProv != null) {
        final success = await addressProv.addAddress(addressData, authUserId);
        if (!success) {
          throw AppException(addressProv.error ?? 'Failed to save address. Please try again.');
        }
        final created = addressProv.lastAddedAddress;
        if (created != null) {
          bookingAddr = addr_domain.Address(
            id: created.id,
            userId: created.userId,
            label: created.displayTitle,
            addressLine: created.line1,
            city: created.city,
            state: created.state ?? 'Uttar Pradesh',
            pincode: created.zipCode ?? pin,
            latitude: created.latitude ?? latlng[0],
            longitude: created.longitude ?? latlng[1],
            isDefault: addressProv.isDefaultAddress(created),
          );
        }
      } else {
        bookingAddr = await _repo.create(addressData);
      }

      if (!mounted) return;

      if (bookingAddr != null) {
        try {
          context.read<BookingFlowProvider>().setAddress(bookingAddr);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Address saved successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Address'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          OutlinedButton.icon(
            onPressed: _detectingLocation ? null : _useCurrentLocation,
            icon: _detectingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, color: AppColors.primary),
            label: Text(
              _detectingLocation ? 'Detecting location...' : 'Use Current Location (GPS)',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Serviceable Noida pincodes: 201309, 201301, 201307, 201304', style: AppTextStyles.body),
          const SizedBox(height: 16),
          CustomTextField(hintText: 'Label (Home / Work)', controller: _label),
          const SizedBox(height: 12),
          CustomTextField(hintText: 'House / street', controller: _line),
          const SizedBox(height: 12),
          CustomTextField(hintText: 'Landmark', controller: _landmark),
          const SizedBox(height: 12),
          CustomTextField(hintText: 'City', controller: _city),
          const SizedBox(height: 12),
          CustomTextField(hintText: 'Pincode', controller: _pincode, keyboardType: TextInputType.number, maxLength: 6),
          const SizedBox(height: 24),
          AppButton(text: 'Save address', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
