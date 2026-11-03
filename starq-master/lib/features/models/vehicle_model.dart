class Vehicle {
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
