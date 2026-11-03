import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {
  late Razorpay _razorpay;

  PaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Function(PaymentSuccessResponse)? onSuccess;
  Function(PaymentFailureResponse)? onFailure;

  void openCheckout({
    required String orderId,
    required double amount,
    required String keyId,
    String name = 'STARQ',
    String description = 'Service Booking',
    String? prefillEmail,
    String? prefillContact,
  }) {
    var options = {
      'key': keyId,
      'amount': (amount * 100).toInt(), // Razorpay expects amount in paise
      'name': name,
      'order_id': orderId,
      'description': description,
      'timeout': 180, // in seconds
      'prefill': {
        if (prefillContact != null && prefillContact.isNotEmpty) 'contact': prefillContact,
        if (prefillEmail != null && prefillEmail.isNotEmpty) 'email': prefillEmail,
      },
      'theme': {
        'color': '#E2000C',
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // optional handling
  }

  void dispose() {
    _razorpay.clear();
  }
}
