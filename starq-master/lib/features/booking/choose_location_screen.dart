import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/core/widgets/custom_text_field.dart';
import 'package:starq_app/core/location/location_service.dart';
import 'package:starq_app/core/location/geocoding_service.dart';
import 'package:starq_app/core/utils/validators.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/addresses/domain/address.dart' as addr_domain;
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/features/providers/address_provider.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';

class ChooseLocationScreen extends StatefulWidget {
  final Map<String, dynamic>? data;
  final ApiClient? apiClient;
  const ChooseLocationScreen({super.key, this.data, this.apiClient});

  @override
  State<ChooseLocationScreen> createState() => _ChooseLocationScreenState();
}

class _ChooseLocationScreenState extends State<ChooseLocationScreen> {
  final _searchController = TextEditingController();
  final _geocoding = GeocodingService();
  final _locationService = LocationService();
  late final ApiClient _api = widget.apiClient ?? ApiClient();

  int _selectedIndex = 0;
  bool _locating = false;
  bool _searching = false;
  Timer? _debounceTimer;

  List<Map<String, dynamic>> _searchResults = [];

  final List<Map<String, dynamic>> _savedLocations = [];

  @override
  void initState() {
    super.initState();
    _loadBackendAddresses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBackendAddresses() async {
    try {
      AddressProvider? prov;
      String? authId;
      if (mounted) {
        try {
          authId = context.read<AuthProvider>().currentUser?.id;
          prov = context.read<AddressProvider>();
        } catch (_) {}
      }
      if (prov != null && prov.addresses.isNotEmpty) {
        _syncFromAddressProvider(prov);
      }

      if (prov != null) {
        await prov.fetchAddresses(authId);
        if (mounted) {
          _syncFromAddressProvider(prov);
        }
      } else {
        final res = await _api.get('/addresses');
        final dynamic raw = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
        if (raw is List && mounted) {
          final List<Map<String, dynamic>> loaded = [];
          for (final a in raw) {
            if (a is Map) {
              final m = Map<String, dynamic>.from(a);
              final rawLabel = m['line2']?.toString() ?? 'Saved Address';
              final cleanLabel = rawLabel.replaceFirst(RegExp(r'^\[ARCHIVED\]\s*'), '');
              loaded.add({
                'id': m['id']?.toString(),
                'label': cleanLabel.isNotEmpty ? cleanLabel : 'Saved Address',
                'address': '${m['line1']}, ${m['city']}${m['zipCode'] != null ? ' - ${m['zipCode']}' : ''}',
                'city': m['city'] ?? 'Noida',
                'state': m['state'] ?? 'Uttar Pradesh',
                'pincode': m['zipCode'] ?? '',
                'latitude': (m['latitude'] as num?)?.toDouble() ?? 28.6270,
                'longitude': (m['longitude'] as num?)?.toDouble() ?? 77.3649,
              });
            }
          }
          setState(() {
            _savedLocations.clear();
            _savedLocations.addAll(loaded);
            if (_selectedIndex >= _savedLocations.length) {
              _selectedIndex = 0;
            }
          });
        }
      }
    } catch (_) {
      // Backend address load optional
    }
  }

  void _syncFromAddressProvider(AddressProvider prov) {
    if (!mounted) return;
    final List<Map<String, dynamic>> loaded = [];
    for (final a in prov.addresses) {
      loaded.add({
        'id': a.id,
        'label': a.displayTitle,
        'address': a.displaySubtitle,
        'city': a.city,
        'state': a.state ?? 'Uttar Pradesh',
        'pincode': a.zipCode ?? '',
        'latitude': a.latitude ?? 28.6270,
        'longitude': a.longitude ?? 77.3649,
      });
    }
    final selectedAddr = prov.selectedAddress;
    int targetIndex = 0;
    if (selectedAddr != null) {
      final idx = loaded.indexWhere((l) => l['id'] == selectedAddr.id);
      if (idx != -1) targetIndex = idx;
    }
    setState(() {
      _savedLocations.clear();
      _savedLocations.addAll(loaded);
      _selectedIndex = targetIndex.clamp(0, _savedLocations.isEmpty ? 0 : _savedLocations.length - 1);
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final q = query.trim();

    if (q.length < 2) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final results = await _geocoding.searchPlaces(q);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      if (!mounted) return;

      if (pos == null) {
        setState(() => _locating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied or GPS disabled. Please enable GPS.'),
          ),
        );
        return;
      }

      // Reverse geocode into detailed address
      final geocoded = await _geocoding.reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;

      setState(() {
        _locating = false;
        final gpsLoc = {
          'label': geocoded?['label']?.toString().isNotEmpty == true
              ? 'GPS: ${geocoded!['label']}'
              : 'Current GPS Location',
          'address': geocoded?['fullAddress'] ??
              'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}',
          'city': geocoded?['city'] ?? 'Noida',
          'state': geocoded?['state'] ?? 'Uttar Pradesh',
          'pincode': geocoded?['pincode'] ?? '',
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        };

        _savedLocations.insert(0, gpsLoc);
        _selectedIndex = 0;
        _searchController.clear();
        _searchResults = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Detected: ${_savedLocations[0]['label']}'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _locating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    }
  }

  void _showAddLocationDialog() {
    final labelCtrl = TextEditingController(text: 'Home');
    final lineCtrl = TextEditingController();
    final landmarkCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Noida');
    final pinCtrl = TextEditingController(text: '201309');
    String? pinError;
    String? lineError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add Service Address', style: AppTextStyles.subheading),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  hintText: 'Label (e.g. Home, Office, Villa)',
                  controller: labelCtrl,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  hintText: 'House / Flat / Street / Area',
                  controller: lineCtrl,
                  errorText: lineError,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  hintText: 'Landmark (Optional)',
                  controller: landmarkCtrl,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        hintText: 'City',
                        controller: cityCtrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        hintText: '6-digit PIN code',
                        controller: pinCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        errorText: pinError,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AppButton(
                  text: 'Save & Select Address',
                  onPressed: () async {
                    final line = lineCtrl.text.trim();
                    final pin = pinCtrl.text.trim();

                    setModalState(() {
                      lineError = line.isEmpty ? 'Address is required' : null;
                      pinError = AppValidators.pincode(pin);
                    });

                    if (lineError != null || pinError != null) return;

                    final fullAddr = '${lineCtrl.text.trim()}${landmarkCtrl.text.trim().isNotEmpty ? ', Near ${landmarkCtrl.text.trim()}' : ''}, ${cityCtrl.text.trim()} - $pin';
                    final newLoc = {
                      'label': labelCtrl.text.trim().isNotEmpty ? labelCtrl.text.trim() : 'Saved Address',
                      'address': fullAddr,
                      'city': cityCtrl.text.trim(),
                      'state': 'Uttar Pradesh',
                      'pincode': pin,
                      'latitude': 28.6270,
                      'longitude': 77.3649,
                    };

                    // Save to backend & AddressProvider
                    AddressProvider? addressProv;
                    try {
                      addressProv = context.read<AddressProvider>();
                    } catch (_) {}

                    String? savedId;
                    if (addressProv != null) {
                      final ok = await addressProv.addAddress({
                        'line1': lineCtrl.text.trim(),
                        'line2': labelCtrl.text.trim().isNotEmpty ? labelCtrl.text.trim() : 'Saved Address',
                        'city': cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : 'Noida',
                        'state': 'Uttar Pradesh',
                        'zipCode': pin,
                        'latitude': 28.6270,
                        'longitude': 77.3649,
                      });
                      if (ok && addressProv.lastAddedAddress != null) {
                        savedId = addressProv.lastAddedAddress!.id;
                      } else if (addressProv.addresses.isNotEmpty) {
                        savedId = addressProv.addresses.first.id;
                      }
                    } else {
                      try {
                        final res = await _api.post('/addresses', data: {
                          'line1': lineCtrl.text.trim(),
                          'line2': labelCtrl.text.trim().isNotEmpty ? labelCtrl.text.trim() : 'Saved Address',
                          'city': cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : 'Noida',
                          'state': 'Uttar Pradesh',
                          'zipCode': pin,
                          'latitude': 28.6270,
                          'longitude': 77.3649,
                        });
                        final dynamic raw = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
                        if (raw is Map && raw['id'] != null) {
                          savedId = raw['id'].toString();
                        }
                      } catch (_) {}
                    }

                    if (savedId != null) {
                      newLoc['id'] = savedId;
                    }

                    if (!mounted) return;
                    setState(() {
                      if (savedId != null) {
                        _savedLocations.removeWhere((l) => l['id'] == savedId);
                      }
                      _savedLocations.insert(0, newLoc);
                      _selectedIndex = 0;
                    });

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectLocationAndContinue(Map<String, dynamic> loc) async {
    String? addressId = loc['id']?.toString();
    AddressProvider? addressProv;
    try {
      addressProv = context.read<AddressProvider>();
    } catch (_) {}

    if (addressId == null || addressId.isEmpty || addressId.startsWith('loc_')) {
      // Auto-save this location to backend & AddressProvider to obtain a verified address ID
      if (addressProv != null) {
        final ok = await addressProv.addAddress({
          'line1': loc['address'] ?? 'Service Location',
          'line2': loc['label'] ?? 'Saved Address',
          'city': loc['city'] ?? 'Noida',
          'state': loc['state'] ?? 'Uttar Pradesh',
          'zipCode': loc['pincode'] ?? '201309',
          'latitude': (loc['latitude'] as num?)?.toDouble() ?? 28.6270,
          'longitude': (loc['longitude'] as num?)?.toDouble() ?? 77.3649,
        });
        if (ok && addressProv.lastAddedAddress != null) {
          addressId = addressProv.lastAddedAddress!.id;
          loc['id'] = addressId;
        } else if (addressProv.addresses.isNotEmpty) {
          addressId = addressProv.addresses.first.id;
          loc['id'] = addressId;
        }
      }

      if (addressId == null || addressId.isEmpty || addressId.startsWith('loc_')) {
        try {
          final res = await _api.post('/addresses', data: {
            'line1': loc['address'] ?? 'Service Location',
            'line2': loc['label'] ?? 'Saved Address',
            'city': loc['city'] ?? 'Noida',
            'state': loc['state'] ?? 'Uttar Pradesh',
            'zipCode': loc['pincode'] ?? '201309',
            'latitude': (loc['latitude'] as num?)?.toDouble() ?? 28.6270,
            'longitude': (loc['longitude'] as num?)?.toDouble() ?? 77.3649,
          });
          final dynamic raw = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
          if (raw is Map && raw['id'] != null) {
            addressId = raw['id'].toString();
            loc['id'] = addressId;
          }
        } catch (_) {}
      }
    } else if (addressProv != null) {
      addressProv.selectAddressById(addressId);
    }

    try {
      final matchingAddr = addressProv?.addresses.where((a) => a.id == addressId).firstOrNull;
      final addr = addr_domain.Address(
        id: addressId ?? 'loc_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'user_current',
        label: loc['label'] ?? 'Service Location',
        addressLine: loc['address'] ?? '',
        landmark: '',
        city: loc['city'] ?? 'Noida',
        state: loc['state'] ?? 'Uttar Pradesh',
        pincode: loc['pincode'] ?? '201309',
        latitude: (loc['latitude'] as num?)?.toDouble() ?? 28.6270,
        longitude: (loc['longitude'] as num?)?.toDouble() ?? 77.3649,
        isDefault: matchingAddr != null ? addressProv!.isDefaultAddress(matchingAddr) : false,
      );
      if (mounted) {
        context.read<BookingFlowProvider>().setAddress(addr);
      }
    } catch (_) {}

    final combined = {
      ...?widget.data,
      'addressId': addressId,
      'locationLabel': loc['label'],
      'locationAddress': loc['address'],
      'city': loc['city'],
      'pincode': loc['pincode'],
      'latitude': loc['latitude'],
      'longitude': loc['longitude'],
    };

    if (mounted) {
      context.push('/booking-summary', extra: combined);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final isSearching = query.isNotEmpty;

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
                    icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textDark),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choose Location', style: AppTextStyles.subheading),
                      Text('Where should our team wash your vehicle?', style: AppTextStyles.body),
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
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search area, sector, street, or city...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: isSearching
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _locating ? null : _useCurrentLocation,
                      icon: _locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.my_location, color: AppColors.primary),
                      label: Text(
                        _locating ? 'Detecting GPS & Address...' : 'Use Current GPS Location',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // LIVE SEARCH RESULTS
                    if (_searching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(strokeWidth: 2),
                              SizedBox(height: 10),
                              Text('Searching places live...'),
                            ],
                          ),
                        ),
                      )
                    else if (isSearching) ...[
                      Text(
                        'SEARCH RESULTS (${_searchResults.length})',
                        style: AppTextStyles.body.copyWith(fontSize: 11, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      if (_searchResults.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.location_off_outlined, size: 36, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text('No places found for "$query"', style: AppTextStyles.body),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final customLoc = {
                                      'label': query,
                                      'address': query,
                                      'city': 'Noida',
                                      'state': 'Uttar Pradesh',
                                      'pincode': '',
                                      'latitude': 28.6270,
                                      'longitude': 77.3649,
                                    };
                                    _selectLocationAndContinue(customLoc);
                                  },
                                  icon: const Icon(Icons.add_location_alt),
                                  label: Text('Use "$query" as Address'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(_searchResults.length, (i) {
                          final loc = _searchResults[i];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                child: Icon(Icons.place, color: AppColors.primary, size: 20),
                              ),
                              title: Text(loc['label'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                loc['fullAddress'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () => _selectLocationAndContinue(loc),
                            ),
                          );
                        }),
                    ] else ...[
                      // SAVED LOCATIONS LIST
                      Text(
                        'SAVED / RECENT LOCATIONS',
                        style: AppTextStyles.body.copyWith(fontSize: 11, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      if (_savedLocations.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.location_off_outlined, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No saved addresses yet',
                                  style: AppTextStyles.body.copyWith(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(_savedLocations.length, (i) {
                        final loc = _savedLocations[i];
                        final addressProv = context.watch<AddressProvider?>();
                        final selected = (addressProv != null && addressProv.selectedAddress != null && loc['id'] != null)
                            ? loc['id'] == addressProv.selectedAddress!.id
                            : i == _selectedIndex;
                        final isDefault = addressProv != null && loc['id'] != null && addressProv.defaultAddressId == loc['id'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedIndex = i);
                              final authId = context.read<AuthProvider?>()?.currentUser?.id;
                              if (addressProv != null && loc['id'] != null) {
                                addressProv.selectAddressById(loc['id'].toString(), authId);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFFFF9FA) : Colors.white,
                                border: Border.all(
                                  color: selected ? AppColors.primary : Colors.grey.shade300,
                                  width: selected ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                loc['label'] ?? 'Location',
                                                style: AppTextStyles.subheading.copyWith(fontSize: 15),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isDefault) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFEBEE),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Default',
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(loc['address'] ?? '', style: AppTextStyles.body),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected ? AppColors.primary : Colors.grey.shade400,
                                        width: 2.0,
                                      ),
                                      color: selected ? AppColors.primary : Colors.transparent,
                                    ),
                                    child: Center(
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        width: selected ? 8 : 0,
                                        height: selected ? 8 : 0,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _showAddLocationDialog,
                        icon: Icon(Icons.add, color: AppColors.textDark),
                        label: const Text('Add New Custom Location Manually'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppButton(
                text: 'Confirm Location',
                onPressed: () {
                  if (_savedLocations.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select or add a location')),
                    );
                    return;
                  }
                  final loc = _savedLocations[_selectedIndex.clamp(0, _savedLocations.length - 1)];
                  _selectLocationAndContinue(loc);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}