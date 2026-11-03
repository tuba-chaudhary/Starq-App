import 'package:flutter/foundation.dart';
import 'package:starq_app/core/errors/app_exception.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/core/config/app_constants.dart';
import 'package:starq_app/features/vehicles/data/vehicle_repository.dart';
import 'package:starq_app/features/vehicles/domain/vehicle.dart';

class GarageProvider extends ChangeNotifier {
  final VehicleRepository _repository;

  GarageProvider([VehicleRepository? repository]) : _repository = repository ?? VehicleRepository();

  List<Vehicle> vehicles = [];
  Vehicle? selected;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      vehicles = await _repository.list();
      final cachedId = LocalCacheService().getString(AppConstants.keySelectedVehicleId);
      selected = vehicles.where((v) => v.id == cachedId).firstOrNull ??
          vehicles.where((v) => v.isPrimary).firstOrNull ??
          (vehicles.isNotEmpty ? vehicles.first : null);
    } catch (e) {
      error = e is AppException ? e.message : e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> select(Vehicle vehicle) async {
    selected = vehicle;
    await LocalCacheService().setString(AppConstants.keySelectedVehicleId, vehicle.id);
    notifyListeners();
  }

  Future<bool> add(Map<String, dynamic> body) async {
    try {
      final created = await _repository.create(body);
      vehicles.insert(0, created);
      selected = created;
      await LocalCacheService().setString(AppConstants.keySelectedVehicleId, created.id);
      notifyListeners();
      return true;
    } catch (e) {
      error = e is AppException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> remove(String id) async {
    try {
      await _repository.delete(id);
      vehicles.removeWhere((v) => v.id == id);
      if (selected?.id == id) {
        selected = vehicles.isNotEmpty ? vehicles.first : null;
        if (selected != null) {
          await LocalCacheService().setString(AppConstants.keySelectedVehicleId, selected!.id);
        } else {
          await LocalCacheService().remove(AppConstants.keySelectedVehicleId);
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      error = e is AppException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }
}
