class AddOn {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;
  final String applicableVehicleType; // 'car', 'bike', 'both'
  final bool isActive;

  AddOn({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.durationMinutes = 10,
    this.applicableVehicleType = 'both',
    this.isActive = true,
  });

  factory AddOn.fromJson(Map<String, dynamic> json) {
    return AddOn(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num? ?? 0).toDouble(),
      durationMinutes: json['duration_minutes'] as int? ?? json['durationMinutes'] as int? ?? 10,
      applicableVehicleType: json['applicable_vehicle_type'] as String? ?? 'both',
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'duration_minutes': durationMinutes,
      'applicable_vehicle_type': applicableVehicleType,
      'is_active': isActive,
    };
  }
}
