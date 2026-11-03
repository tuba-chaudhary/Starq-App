import os

base_dir = r"c:\Users\SIDDDIQUI TABISH\Downloads\STARQ\starq_app-\lib\features"

# Models
models_dir = os.path.join(base_dir, "models")
os.makedirs(models_dir, exist_ok=True)

vehicle_model = """class Vehicle {
  final String id;
  final String userId;
  final String vehicleTypeId;
  final String make;
  final String model;
  final String? category;
  final String? licensePlate;
  final Map<String, dynamic>? vehicleType;

  Vehicle({
    required this.id,
    required this.userId,
    required this.vehicleTypeId,
    required this.make,
    required this.model,
    this.category,
    this.licensePlate,
    this.vehicleType,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      userId: json['userId'],
      vehicleTypeId: json['vehicleTypeId'],
      make: json['make'],
      model: json['model'],
      category: json['category'],
      licensePlate: json['licensePlate'],
      vehicleType: json['vehicleType'],
    );
  }

  bool get isBike => vehicleType != null && vehicleType!['name'] == 'BIKE';
}
"""
with open(os.path.join(models_dir, "vehicle_model.dart"), "w") as f:
    f.write(vehicle_model)

service_model = """class ServiceVariant {
  final String id;
  final String name;
  final double price;

  ServiceVariant({required this.id, required this.name, required this.price});

  factory ServiceVariant.fromJson(Map<String, dynamic> json) {
    return ServiceVariant(
      id: json['id'],
      name: json['name'] ?? 'Default',
      price: (json['price'] as num).toDouble(),
    );
  }
}

class Service {
  final String id;
  final String name;
  final String? description;
  final String category; // CAR or BIKE
  final List<ServiceVariant> variants;

  Service({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.variants,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      variants: (json['variants'] as List?)
              ?.map((v) => ServiceVariant.fromJson(v))
              .toList() ??
          [],
    );
  }
}
"""
with open(os.path.join(models_dir, "service_model.dart"), "w") as f:
    f.write(service_model)

addon_model = """class Addon {
  final String id;
  final String name;
  final String? description;
  final double price;

  Addon({
    required this.id,
    required this.name,
    this.description,
    required this.price,
  });

  factory Addon.fromJson(Map<String, dynamic> json) {
    return Addon(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
    );
  }
}
"""
with open(os.path.join(models_dir, "addon_model.dart"), "w") as f:
    f.write(addon_model)

quote_model = """class Quote {
  final String serviceName;
  final double basePrice;
  final double addonsTotal;
  final double subtotal;
  final double taxes;
  final double total;
  final List<dynamic> addons;

  Quote({
    required this.serviceName,
    required this.basePrice,
    required this.addonsTotal,
    required this.subtotal,
    required this.taxes,
    required this.total,
    required this.addons,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      serviceName: json['serviceName'] ?? '',
      basePrice: (json['basePrice'] as num).toDouble(),
      addonsTotal: (json['addonsTotal'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      taxes: (json['taxes'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      addons: json['addons'] ?? [],
    );
  }
}
"""
with open(os.path.join(models_dir, "quote_model.dart"), "w") as f:
    f.write(quote_model)


# Providers
providers_dir = os.path.join(base_dir, "providers")
os.makedirs(providers_dir, exist_ok=True)

vehicle_provider = """import 'package:flutter/foundation.dart';
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
"""
with open(os.path.join(providers_dir, "vehicle_provider.dart"), "w") as f:
    f.write(vehicle_provider)

booking_provider = """import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../models/service_model.dart';
import '../models/addon_model.dart';
import '../models/quote_model.dart';
import '../models/vehicle_model.dart';

class BookingProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  List<Service> _services = [];
  List<Addon> _addons = [];
  
  Vehicle? _selectedVehicle;
  Service? _selectedService;
  List<Addon> _selectedAddons = [];
  Quote? _currentQuote;

  bool _isLoading = false;
  String? _error;

  BookingProvider(this._apiClient);

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

  Future<void> fetchCatalog() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final sRes = await _apiClient.get('/services');
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

  Future<bool> getQuote() async {
    if (_selectedVehicle == null || _selectedService == null) return false;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _apiClient.post('/pricing/quote', data: {
        'vehicleId': _selectedVehicle!.id,
        'serviceId': _selectedService!.id,
        'addonIds': _selectedAddons.map((a) => a.id).toList(),
      });
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
}
"""
with open(os.path.join(providers_dir, "booking_provider.dart"), "w") as f:
    f.write(booking_provider)

print("Flutter models and providers created.")
