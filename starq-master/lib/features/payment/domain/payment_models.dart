class RazorpayOrder {
  final String bookingId;
  final String bookingNumber;
  final String razorpayOrderId;
  final double amount;
  final String currency;
  final String keyId;
  final String checkoutUrl;

  RazorpayOrder({
    required this.bookingId,
    required this.bookingNumber,
    required this.razorpayOrderId,
    required this.amount,
    this.currency = 'INR',
    required this.keyId,
    required this.checkoutUrl,
  });

  factory RazorpayOrder.fromJson(Map<String, dynamic> json) {
    return RazorpayOrder(
      bookingId: json['booking_id'] as String? ?? json['bookingId'] as String? ?? '',
      bookingNumber: json['booking_number'] as String? ?? '',
      razorpayOrderId: json['razorpay_order_id'] as String? ?? json['orderId'] as String? ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      keyId: json['key_id'] as String? ?? json['keyId'] as String? ?? '',
      checkoutUrl: json['checkout_url'] as String? ?? '',
    );
  }
}

class PaymentVerificationPayload {
  final String bookingId;
  final String razorpayOrderId;
  final String razorpayPaymentId;
  final String razorpaySignature;

  PaymentVerificationPayload({
    required this.bookingId,
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
    required this.razorpaySignature,
  });

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    };
  }
}
