import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/network/api_endpoints.dart';
import 'package:starq_app/features/vehicles/domain/vehicle.dart';

class VehicleRepository {
  final ApiClient _api;

  VehicleRepository([ApiClient? api]) : _api = api ?? ApiClient();

  Future<List<Vehicle>> list() async {
    final res = await _api.get(ApiEndpoints.vehicles);
    final raw = res.data;
    if (raw is List) {
      return raw.map((e) => Vehicle.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
    if (raw is Map) {
      final list = raw['data'] ?? raw['vehicles'];
      if (list is List) {
        return list.map((e) => Vehicle.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    }
    return [];
  }

  Future<Vehicle> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.vehicles, data: body);
    final raw = res.data;
    if (raw is Map) {
      if (raw['data'] != null && raw['data'] is Map) {
        return Vehicle.fromJson(Map<String, dynamic>.from(raw['data'] as Map));
      }
      return Vehicle.fromJson(Map<String, dynamic>.from(raw));
    }
    throw Exception('Invalid vehicle response format');
  }

  Future<Vehicle> update(String id, Map<String, dynamic> body) async {
    final res = await _api.put(ApiEndpoints.vehicle(id), data: body);
    final raw = res.data;
    if (raw is Map && raw['data'] is Map) {
      return Vehicle.fromJson(Map<String, dynamic>.from(raw['data'] as Map));
    }
    return Vehicle.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> delete(String id) async {
    await _api.delete(ApiEndpoints.vehicle(id));
  }

  Future<Vehicle> setPrimary(String id) async {
    final res = await _api.post(ApiEndpoints.setPrimaryVehicle(id));
    final raw = res.data;
    if (raw is Map && raw['data'] is Map) {
      return Vehicle.fromJson(Map<String, dynamic>.from(raw['data'] as Map));
    }
    return Vehicle.fromJson(Map<String, dynamic>.from(raw as Map));
  }
}
