enum VehicleCategory { hatchback, sedan, suv, muv, luxury, bike }

extension VehicleCategoryX on VehicleCategory {
  String get displayName {
    switch (this) {
      case VehicleCategory.hatchback:
        return 'Hatchback';
      case VehicleCategory.sedan:
        return 'Sedan';
      case VehicleCategory.muv:
        return 'MUV';
      case VehicleCategory.suv:
        return 'SUV';
      case VehicleCategory.luxury:
        return 'Luxury';
      case VehicleCategory.bike:
        return 'Bike';
    }
  }

  bool get isCar => this != VehicleCategory.bike;
}

class Vehicle {
  final String id;
  final String userId;
  final VehicleCategory category;
  final String brand;
  final String model;
  final String? variant;
  final String registrationNumber;
  final String? color;
  final String? fuelType;
  final bool isPrimary;
  final String? imageUrl;
  final DateTime? createdAt;

  Vehicle({
    required this.id,
    required this.userId,
    required this.category,
    required this.brand,
    required this.model,
    this.variant,
    required this.registrationNumber,
    this.color,
    this.fuelType,
    this.isPrimary = false,
    this.imageUrl,
    this.createdAt,
  });

  bool get isBike => category == VehicleCategory.bike;

  String get displayName => variant != null && variant!.isNotEmpty
      ? '$brand $model ($variant)'
      : '$brand $model';

  String get subtitle => '${registrationNumber.toUpperCase()} · ${category.name.toUpperCase()}${color != null ? ' · $color' : ''}';

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      category: _parseCategory(json['category'] as String? ?? json['vehicle_type'] as String?),
      brand: json['brand'] as String? ?? json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      variant: json['variant'] as String?,
      registrationNumber: json['registration_number'] as String? ??
          json['registrationNumber'] as String? ??
          json['licensePlate'] as String? ??
          '',
      color: json['color'] as String?,
      fuelType: json['fuel_type'] as String? ?? json['fuelType'] as String?,
      isPrimary: json['is_primary'] as bool? ?? json['isPrimary'] as bool? ?? false,
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  static VehicleCategory _parseCategory(String? value) {
    switch (value?.toLowerCase()) {
      case 'bike':
        return VehicleCategory.bike;
      case 'sedan':
        return VehicleCategory.sedan;
      case 'suv':
        return VehicleCategory.suv;
      case 'muv':
        return VehicleCategory.muv;
      case 'luxury':
        return VehicleCategory.luxury;
      case 'hatchback':
      default:
        return VehicleCategory.hatchback;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category': category.name,
      'brand': brand,
      'model': model,
      'variant': variant,
      'registration_number': registrationNumber,
      'color': color,
      'fuel_type': fuelType,
      'is_primary': isPrimary,
      'image_url': imageUrl,
    };
  }
}
