class PartnerLocation {
  final String bookingId;
  final String partnerId;
  final double latitude;
  final double longitude;
  final double? heading;
  final int? etaMinutes;
  final DateTime updatedAt;

  PartnerLocation({
    required this.bookingId,
    required this.partnerId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.etaMinutes,
    required this.updatedAt,
  });

  factory PartnerLocation.fromJson(Map<String, dynamic> json) {
    return PartnerLocation(
      bookingId: json['booking_id'] as String? ?? '',
      partnerId: json['partner_id'] as String? ?? '',
      latitude: (json['latitude'] as num? ?? json['lat'] as num? ?? 0).toDouble(),
      longitude: (json['longitude'] as num? ?? json['lng'] as num? ?? 0).toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      etaMinutes: json['eta_minutes'] as int? ?? json['eta'] as int?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
