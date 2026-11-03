import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/local_cache_service.dart';
import '../models/service_model.dart';
import '../models/addon_model.dart';
import '../models/quote_model.dart';
import '../models/vehicle_model.dart';

import '../booking/domain/booking_model.dart' as bm;

final List<Service> kApprovedDefaultCatalog = [
  Service(
    id: 'a0000001-0000-4000-8000-000000000001',
    name: 'Exterior Wash',
    description: 'Full exterior rinse, foam wash, and hand dry. Removes dust, dirt, and surface grime.',
    category: 'CAR',
    variants: [ServiceVariant(id: 'b0000001-0000-4000-8000-000000000001', name: 'Default', price: 249, durationMins: 45)],
  ),
  Service(
    id: 'a0000002-0000-4000-8000-000000000002',
    name: 'Interior Cleaning',
    description: 'Deep interior cleaning with vacuuming and surface care. Removes dust, stains, dirt, and unpleasant odours.',
    category: 'CAR',
    variants: [ServiceVariant(id: 'b0000002-0000-4000-8000-000000000002', name: 'Default', price: 399, durationMins: 60)],
  ),
  Service(
    id: 'a0000003-0000-4000-8000-000000000003',
    name: 'Full Detailing',
    description: "Complete interior and exterior detailing with deep cleaning, polishing, and protective treatment. Restores the vehicle's shine while refreshing and protecting the cabin.",
    category: 'CAR',
    variants: [ServiceVariant(id: 'b0000003-0000-4000-8000-000000000003', name: 'Default', price: 999, durationMins: 120)],
  ),
  Service(
    id: 'a0000004-0000-4000-8000-000000000004',
    name: 'Premium Wash',
    description: "Complete exterior and interior cleaning with polishing and a protective finish. Removes tough dirt, dust, stains, and restores the vehicle's shine.",
    category: 'CAR',
    variants: [ServiceVariant(id: 'b0000004-0000-4000-8000-000000000004', name: 'Default', price: 1299, durationMins: 90)],
  ),
  Service(
    id: 'a0000005-0000-4000-8000-000000000005',
    name: 'Bucket Wash',
    description: 'A quick and thorough manual wash using bucket and soap. Perfect for regular upkeep and everyday grime.',
    category: 'BIKE',
    variants: [ServiceVariant(id: 'b0000005-0000-4000-8000-000000000005', name: 'Default', price: 299, durationMins: 20)],
  ),
  Service(
    id: 'a0000006-0000-4000-8000-000000000006',
    name: 'Pressure Wash',
    description: 'High-pressure water jet wash that removes tough dirt and grime from every corner of the bike.',
    category: 'BIKE',
    variants: [ServiceVariant(id: 'b0000006-0000-4000-8000-000000000006', name: 'Default', price: 399, durationMins: 30)],
  ),
  Service(
    id: '9eaa3c73-830c-402f-afae-106488ec19c6',
    name: 'Basic Wash',
    description: 'Exterior washing and cleaning',
    category: 'CAR',
    variants: [ServiceVariant(id: '20b7e020-adf6-404d-b566-9e27e2a03b0f', name: 'Default', price: 299, durationMins: 30)],
  ),
];

class BookingProvider extends ChangeNotifier {
  bm.Booking? _activeBooking;
  bm.Booking? get activeBooking => _activeBooking;
  final ApiClient _apiClient;

  List<Service> _services = [];
  List<Addon> _addons = [];
  
  Vehicle? _selectedVehicle;
  Service? _selectedService;
  List<Addon> _selectedAddons = [];
  Quote? _currentQuote;

  bool _isLoading = false;
  String? _error;

  BookingProvider(this._apiClient) {
    _initCatalog();
  }

  void _initCatalog() {
    final cached = LocalCacheService().getString('cached_services_catalog_json');
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is List && decoded.isNotEmpty) {
          _services = decoded
              .map((s) => Service.fromJson(s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s as Map)))
              .toList();
          return;
        }
      } catch (_) {}
    }
    _services = List<Service>.from(kApprovedDefaultCatalog);
  }

  List<Service> get services => _services;
  List<Addon> get addons => _addons;
  Vehicle? get selectedVehicle => _selectedVehicle;
  Service? get selectedService => _selectedService;
  List<Addon> get selectedAddons => _selectedAddons;
  Quote? get currentQuote => _currentQuote;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void selectVehicle(Vehicle vehicle) {
    _selectedVehicle = vehicle;
    _selectedService = null;
    _selectedAddons = [];
    _currentQuote = null;
    notifyListeners();
  }

  void selectService(Service service) {
    _selectedService = service;
    _currentQuote = null;
    notifyListeners();
  }

  void toggleAddon(Addon addon) {
    if (_selectedAddons.contains(addon)) {
      _selectedAddons.remove(addon);
    } else {
      _selectedAddons.add(addon);
    }
    _currentQuote = null;
    notifyListeners();
  }


  Future<void> fetchActiveBooking() async {
    try {
      final response = await _apiClient.get('/bookings');
      final dynamic raw = response.data is List
          ? response.data
          : (response.data is Map ? (response.data['data'] ?? response.data['bookings'] ?? []) : []);
      final list = (raw as List)
          .map((e) => bm.Booking.fromJson(e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .toList();
      _activeBooking = list.firstWhere(
        (b) => b.isActive,
        orElse: () => list.isNotEmpty ? list.first : null as dynamic,
      );
      if (_activeBooking != null) {
        try {
          final detailResponse = await _apiClient.get('/bookings/${_activeBooking!.id}');
          final dynamic rawDetail = detailResponse.data;
          if (rawDetail is Map) {
            final detailMap = rawDetail['data'] is Map
                ? rawDetail['data'] as Map
                : (rawDetail['booking'] is Map ? rawDetail['booking'] as Map : rawDetail);
            if (detailMap['id'] != null) {
              _activeBooking = bm.Booking.fromJson(
                Map<String, dynamic>.from(detailMap),
              );
            }
          }
        } catch (_) {
          // If detailed fetch fails, keep the active booking from the list
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> fetchCatalog({String? vehicleCategory}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final queryParams = <String, dynamic>{};
      if (vehicleCategory != null && vehicleCategory.isNotEmpty) {
        queryParams['vehicleCategory'] = vehicleCategory;
      }
      final sRes = await _apiClient.get(
        '/services',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      _services = (sRes.data as List).map((s) => Service.fromJson(s)).toList();

      final aRes = await _apiClient.get('/addons');
      _addons = (aRes.data as List).map((a) => Addon.fromJson(a)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> getQuote({
    String? vehicleId,
    String? serviceId,
    String? vehicleCategory,
  }) async {
    final effectiveServiceId = serviceId ?? _selectedService?.id;
    if (effectiveServiceId == null) return false;

    String? effectiveVehicleId = vehicleId;
    if (effectiveVehicleId == null || effectiveVehicleId.isEmpty) {
      if (_selectedVehicle != null) {
        Service? targetService;
        for (final s in _services) {
          if (s.id == effectiveServiceId) {
            targetService = s;
            break;
          }
        }
        targetService ??= _selectedService;

        if (targetService != null && targetService.category.isNotEmpty) {
          final serviceIsBike = targetService.category.toUpperCase() == 'BIKE';
          if (serviceIsBike == _selectedVehicle!.isBike) {
            effectiveVehicleId = _selectedVehicle!.id;
          }
        }
      }
    }

    if ((effectiveVehicleId == null || effectiveVehicleId.isEmpty) &&
        (vehicleCategory == null || vehicleCategory.isEmpty)) {
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final payload = <String, dynamic>{
        'serviceId': effectiveServiceId,
        'addonIds': _selectedAddons.map((a) => a.id).toList(),
      };
      if (effectiveVehicleId != null && effectiveVehicleId.isNotEmpty) {
        payload['vehicleId'] = effectiveVehicleId;
      }
      if (vehicleCategory != null && vehicleCategory.isNotEmpty) {
        payload['vehicleCategory'] = vehicleCategory;
      }

      final response = await _apiClient.post('/pricing/quote', data: payload);
      _currentQuote = Quote.fromJson(response.data);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> createBooking(
    String addressId,
    DateTime scheduledAt, {
    String? vehicleId,
    String? serviceId,
    String? vehicleCategory,
    String? idempotencyKey,
  }) async {
    final effectiveServiceId = (serviceId != null && serviceId.trim().isNotEmpty)
        ? serviceId.trim()
        : (_selectedService?.id ?? '');

    if (effectiveServiceId.isEmpty) {
      _error = 'A valid serviceId is required';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      String? resolvedVehicleId = (vehicleId != null && vehicleId.trim().isNotEmpty) ? vehicleId.trim() : null;
      if (resolvedVehicleId == null && _selectedVehicle != null) {
        Service? targetService;
        for (final s in _services) {
          if (s.id == effectiveServiceId) {
            targetService = s;
            break;
          }
        }
        targetService ??= _selectedService;
        if (targetService != null && targetService.category.isNotEmpty) {
          final serviceIsBike = targetService.category.toUpperCase() == 'BIKE';
          if (serviceIsBike == _selectedVehicle!.isBike) {
            resolvedVehicleId = _selectedVehicle!.id;
          }
        }
      }

      final payload = <String, dynamic>{
        'serviceId': effectiveServiceId,
        'addonIds': _selectedAddons.map((a) => a.id).toList(),
        'addressId': addressId,
        'scheduledAt': scheduledAt.toIso8601String(),
      };
      if (resolvedVehicleId != null && resolvedVehicleId.isNotEmpty) {
        payload['vehicleId'] = resolvedVehicleId;
      }
      if (vehicleCategory != null && vehicleCategory.isNotEmpty) {
        payload['vehicleCategory'] = vehicleCategory;
      }
      if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
        payload['idempotencyKey'] = idempotencyKey.trim();
      }

      final response = await _apiClient.post('/bookings', data: payload);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyPayment(String orderId, String paymentId, String signature) async {
    try {
      final response = await _apiClient.post('/payments/verify', data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
