import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../booking/domain/booking_model.dart' as bm;
import '../../core/location/location_service.dart';

class PartnerProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  bm.Booking? _assignedBooking;
  bm.Booking? get assignedBooking => _assignedBooking;

  String _status = 'OFFLINE';
  String get status => _status;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  PartnerProvider(this._apiClient);

  Future<void> fetchAssignedBooking() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _apiClient.get('/partners/bookings');
      final list = (response.data as List).map((e) => bm.Booking.fromJson(e)).toList();
      _assignedBooking = list.isNotEmpty ? list.first : null;
      _manageTracking();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStatus() async {
      // In MVP we just toggle it or set it, but let's say we fetch it.
      // Wait, there's no GET /partners/status yet?
      // I will assume it's part of me or just default to OFFLINE, then user toggles.
  }

  Future<bool> setStatus(String newStatus) async {
    if (newStatus == 'AVAILABLE' && _assignedBooking != null) return false; // Prevent available if busy
    _isLoading = true;
    notifyListeners();
    try {
      await _apiClient.patch('/partners/status', data: {'status': newStatus});
      _status = newStatus;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  StreamSubscription? _locationSub;
  final LocationService _locationService = LocationService();

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  void _manageTracking() {
    if (_assignedBooking != null && 
        ['PARTNER_ASSIGNED', 'PARTNER_ON_THE_WAY', 'PARTNER_ARRIVED', 'SERVICE_STARTED', 'SERVICE_IN_PROGRESS']
        .contains(_assignedBooking!.status.name.toUpperCase())) {
      _startTracking();
    } else {
      _stopTracking();
    }
  }

  Future<void> _startTracking() async {
    if (_locationSub != null) return;
    
    final hasPermission = await _locationService.handlePermission();
    if (!hasPermission) return;

    _locationSub = _locationService.getLocationStream()?.listen((position) {
      _sendLocationToBackend(position.latitude, position.longitude, position.accuracy, position.heading, position.speed);
    });
  }

  void _stopTracking() {
    _locationSub?.cancel();
    _locationSub = null;
  }

  Future<void> _sendLocationToBackend(double lat, double lng, double acc, double heading, double speed) async {
    try {
      await _apiClient.patch('/partners/location', data: {
        'latitude': lat,
        'longitude': lng,
        'accuracy': acc,
        'heading': heading,
        'speed': speed,
      });
    } catch (e) {
      // Silently fail for background tracking
    }
  }

  Future<bool> updateBookingStatus(String bookingId, String newStatus) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiClient.patch('/partners/bookings/$bookingId/status', data: {'status': newStatus});
      await fetchAssignedBooking();
      _manageTracking();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
