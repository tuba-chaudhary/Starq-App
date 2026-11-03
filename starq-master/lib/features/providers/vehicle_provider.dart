import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../models/vehicle_model.dart';

class VehicleProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _error;

  VehicleProvider(this._apiClient);

  List<Vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchVehicles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _apiClient.get('/vehicles');
      _vehicles = (response.data as List).map((v) => Vehicle.fromJson(v)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addVehicle(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _apiClient.post('/vehicles', data: data);
      await fetchVehicles();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteVehicle(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _apiClient.delete('/vehicles/$id');
      await fetchVehicles();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
