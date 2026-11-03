class Address {
  final String id;
  final String userId;
  final String label; // Home, Work, Other
  final String addressLine;
  final String? landmark;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;
  final bool isDefault;

  Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.addressLine,
    this.landmark,
    this.city = 'Noida',
    this.state = 'Uttar Pradesh',
    required this.pincode,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
  });

  String get fullAddress => landmark != null && landmark!.isNotEmpty
      ? '$addressLine, near $landmark, $city - $pincode'
      : '$addressLine, $city - $pincode';

  factory Address.fromJson(Map<String, dynamic> json) {
    final rawLabel = json['label'] as String? ?? json['line2'] as String? ?? 'Home';
    final cleanLabel = rawLabel
        .replaceFirst(RegExp(r'^\[ARCHIVED\]\s*'), '')
        .replaceFirst(RegExp(r'\[DEFAULT\]\s*'), '')
        .trim();
    final hasDefaultTag = rawLabel.contains('[DEFAULT]');
    return Address(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      label: cleanLabel.isNotEmpty ? cleanLabel : 'Home',
      addressLine: json['address_line'] as String? ?? json['addressLine'] as String? ?? json['line1'] as String? ?? json['address'] as String? ?? '',
      landmark: json['landmark'] as String?,
      city: json['city'] as String? ?? 'Noida',
      state: json['state'] as String? ?? 'Uttar Pradesh',
      pincode: json['pincode'] as String? ?? json['zipCode'] as String? ?? '',
      latitude: (json['latitude'] as num? ?? json['lat'] as num? ?? 28.5355).toDouble(),
      longitude: (json['longitude'] as num? ?? json['lng'] as num? ?? 77.3910).toDouble(),
      isDefault: hasDefaultTag || json['is_default'] == true || json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'address_line': addressLine,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
    };
  }
}
