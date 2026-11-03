import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../booking/domain/booking_model.dart' as bm;

class AdminProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  List<bm.Booking> _bookings = [];
  List<bm.Booking> get bookings => _bookings;

  List<dynamic> _partners = [];
  List<dynamic> get partners => _partners;

  AdminProvider(this._apiClient);

  Future<void> fetchBookings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _apiClient.get('/admin/bookings');
      _bookings = (response.data as List).map((e) => bm.Booking.fromJson(e)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPartners() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _apiClient.get('/admin/partners');
      _partners = response.data;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> assignPartner(String bookingId, String partnerId) async {
    try {
      await _apiClient.patch('/admin/bookings/$bookingId/assign-partner', data: {'partnerId': partnerId});
      await fetchBookings();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelBooking(String bookingId) async {
    try {
      await _apiClient.patch('/admin/bookings/$bookingId/cancel');
      await fetchBookings();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
