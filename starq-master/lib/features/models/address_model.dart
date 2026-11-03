class Address {
  final String id;
  final String userId;
  final String line1;
  final String? line2;
  final String? landmark;
  final String city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  Address({
    required this.id,
    required this.userId,
    required this.line1,
    this.line2,
    this.landmark,
    required this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  String get displayTitle {
    if (line2 != null && line2!.trim().isNotEmpty) {
      final clean = line2!
          .replaceFirst(RegExp(r'^\[ARCHIVED\]\s*'), '')
          .replaceFirst(RegExp(r'\[DEFAULT\]\s*'), '')
          .trim();
      if (clean.isNotEmpty) return clean;
    }
    return 'Home';
  }

  String get label => displayTitle;
  String get addressLine => line1;
  String get pincode => zipCode ?? '';

  String get fullAddress {
    final parts = <String>[];
    if (line1.trim().isNotEmpty) parts.add(line1.trim());
    if (landmark != null && landmark!.trim().isNotEmpty) parts.add('Near ${landmark!.trim()}');
    if (city.trim().isNotEmpty) parts.add(city.trim());
    final main = parts.join(', ');
    final pin = (zipCode != null && zipCode!.trim().isNotEmpty) ? zipCode!.trim() : null;
    if (pin != null) {
      return main.isNotEmpty ? '$main - $pin' : pin;
    }
    return main;
  }

  String get displaySubtitle => fullAddress.isNotEmpty ? fullAddress : '$line1, $city';

  Address copyWith({
    String? id,
    String? userId,
    String? line1,
    String? line2,
    String? landmark,
    String? city,
    String? state,
    String? zipCode,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  factory Address.fromJson(Map<String, dynamic> json) {
    final rawLine2 = json['line2']?.toString() ?? json['label']?.toString();
    final hasDefaultTag = rawLine2 != null && rawLine2.contains('[DEFAULT]');
    return Address(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      line1: json['line1']?.toString() ?? json['address_line']?.toString() ?? json['addressLine']?.toString() ?? json['address']?.toString() ?? '',
      line2: rawLine2,
      landmark: json['landmark']?.toString(),
      city: json['city']?.toString() ?? 'Noida',
      state: json['state']?.toString() ?? 'Uttar Pradesh',
      zipCode: json['zipCode']?.toString() ?? json['pincode']?.toString(),
      latitude: _parseCoord(json['latitude'] ?? json['lat']),
      longitude: _parseCoord(json['longitude'] ?? json['lng']),
      isDefault: hasDefaultTag || json['is_default'] == true || json['isDefault'] == true,
    );
  }

  static double? _parseCoord(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'line1': line1,
      'line2': line2,
      'landmark': landmark,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
    };
  }
}
