class BookingQuote {
  final double baseServiceAmount;
  final double addOnsAmount;
  final double convenienceFee;
  final double taxAmount;
  final double discountAmount;
  final double finalTotalAmount;
  final int pointsAwarded;
  final String quoteToken;

  BookingQuote({
    required this.baseServiceAmount,
    required this.addOnsAmount,
    required this.convenienceFee,
    required this.taxAmount,
    required this.discountAmount,
    required this.finalTotalAmount,
    required this.pointsAwarded,
    required this.quoteToken,
  });

  factory BookingQuote.fromJson(Map<String, dynamic> json) {
    return BookingQuote(
      baseServiceAmount: (json['base_service_amount'] as num? ?? json['baseAmount'] as num? ?? 0).toDouble(),
      addOnsAmount: (json['add_ons_amount'] as num? ?? json['addOnsAmount'] as num? ?? 0).toDouble(),
      convenienceFee: (json['convenience_fee'] as num? ?? json['convenienceFee'] as num? ?? 0).toDouble(),
      taxAmount: (json['tax_amount'] as num? ?? json['taxAmount'] as num? ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] as num? ?? json['discountAmount'] as num? ?? 0).toDouble(),
      finalTotalAmount: (json['final_total_amount'] as num? ?? json['totalAmount'] as num? ?? 0).toDouble(),
      pointsAwarded: json['points_awarded'] as int? ?? json['pointsAwarded'] as int? ?? 0,
      quoteToken: json['quote_token'] as String? ?? json['quoteToken'] as String? ?? '',
    );
  }
}
