class ServiceFeature {
  final String sectionName;
  final String featureText;

  ServiceFeature({required this.sectionName, required this.featureText});

  factory ServiceFeature.fromJson(Map<String, dynamic> json) {
    return ServiceFeature(
      sectionName: json['section_name'] as String? ?? json['sectionName'] as String? ?? '',
      featureText: json['feature_text'] as String? ?? json['featureText'] as String? ?? '',
    );
  }
}

class ServiceItem {
  final String id;
  final String slug;
  final String name;
  final String targetVehicleType; // 'car' or 'bike'
  final String description;
  final double basePrice;
  final int durationMinutes;
  final String imageAssetPath;
  final double rating;
  final bool isActive;
  final Map<String, List<String>> inclusions; // Section -> Items

  ServiceItem({
    required this.id,
    required this.slug,
    required this.name,
    required this.targetVehicleType,
    required this.description,
    required this.basePrice,
    required this.durationMinutes,
    required this.imageAssetPath,
    this.rating = 4.8,
    this.isActive = true,
    required this.inclusions,
  });

  String get durationDisplay => durationMinutes >= 60
      ? '${durationMinutes ~/ 60}h ${durationMinutes % 60 > 0 ? "${durationMinutes % 60}m" : ""}'
      : '$durationMinutes min';

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final rawInclusions = json['inclusions'];
    Map<String, List<String>> incMap = {};

    if (rawInclusions is Map) {
      rawInclusions.forEach((key, val) {
        if (val is List) {
          incMap[key.toString()] = val.map((e) => e.toString()).toList();
        }
      });
    }

    return ServiceItem(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      targetVehicleType: json['target_vehicle_type'] as String? ?? json['vehicleType'] as String? ?? 'car',
      description: json['description'] as String? ?? '',
      basePrice: (json['base_price'] as num? ?? json['basePrice'] as num? ?? 0).toDouble(),
      durationMinutes: json['duration_minutes'] is num
          ? (json['duration_minutes'] as num).toInt()
          : json['durationMinutes'] is num
              ? (json['durationMinutes'] as num).toInt()
              : 45,
      imageAssetPath: json['image_asset_path'] as String? ?? json['image'] as String? ?? 'exterior_wash.png',
      rating: (json['rating'] as num? ?? 4.8).toDouble(),
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
      inclusions: incMap,
    );
  }
}
