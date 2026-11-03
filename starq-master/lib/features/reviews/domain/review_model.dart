class Review {
  final String id;
  final String bookingId;
  final String customerId;
  final String partnerId;
  final int rating;
  final List<String> tags;
  final String? comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.partnerId,
    required this.rating,
    this.tags = const [],
    this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String? ?? '',
      bookingId: json['booking_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      partnerId: json['partner_id'] as String? ?? '',
      rating: json['rating'] as int? ?? 5,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'rating': rating,
      'tags': tags,
      'comment': comment,
    };
  }
}
