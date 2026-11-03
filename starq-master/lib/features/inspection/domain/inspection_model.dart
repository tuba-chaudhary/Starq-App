class VehicleInspection {
  final String id;
  final String bookingId;
  final String partnerId;
  final bool preExistingDamagesFound;
  final String? inspectionNotes;
  final List<String> photoUrls;
  final bool customerConsentGiven;
  final DateTime? customerConsentedAt;

  VehicleInspection({
    required this.id,
    required this.bookingId,
    required this.partnerId,
    required this.preExistingDamagesFound,
    this.inspectionNotes,
    required this.photoUrls,
    this.customerConsentGiven = false,
    this.customerConsentedAt,
  });

  factory VehicleInspection.fromJson(Map<String, dynamic> json) {
    return VehicleInspection(
      id: json['id'] as String? ?? '',
      bookingId: json['booking_id'] as String? ?? '',
      partnerId: json['partner_id'] as String? ?? '',
      preExistingDamagesFound: json['pre_existing_damages_found'] as bool? ?? false,
      inspectionNotes: json['inspection_notes'] as String?,
      photoUrls: (json['photo_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      customerConsentGiven: json['customer_consent_given'] as bool? ?? false,
      customerConsentedAt: json['customer_consented_at'] != null
          ? DateTime.tryParse(json['customer_consented_at'] as String)
          : null,
    );
  }
}
