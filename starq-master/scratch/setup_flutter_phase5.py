import os

base_dir = r"c:\Users\SIDDDIQUI TABISH\Downloads\STARQ\starq_app-\lib\features"

models_dir = os.path.join(base_dir, "models")
address_model = """class Address {
  final String id;
  final String userId;
  final String line1;
  final String? line2;
  final String city;
  final String? state;
  final String? zipCode;

  Address({
    required this.id,
    required this.userId,
    required this.line1,
    this.line2,
    required this.city,
    this.state,
    this.zipCode,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'],
      userId: json['userId'],
      line1: json['line1'],
      line2: json['line2'],
      city: json['city'],
      state: json['state'],
      zipCode: json['zipCode'],
    );
  }
}
"""
with open(os.path.join(models_dir, "address_model.dart"), "w") as f:
    f.write(address_model)

providers_dir = os.path.join(base_dir, "providers")
address_provider = """import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../models/address_model.dart';

class AddressProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  List<Address> _addresses = [];
  bool _isLoading = false;
  String? _error;

  AddressProvider(this._apiClient);

  List<Address> get addresses => _addresses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAddresses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _apiClient.get('/addresses');
      _addresses = (response.data as List).map((a) => Address.fromJson(a)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addAddress(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiClient.post('/addresses', data: data);
      await fetchAddresses();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
"""
with open(os.path.join(providers_dir, "address_provider.dart"), "w") as f:
    f.write(address_provider)

payment_service = """import 'package:flutter/foundation.dart';
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
  }) {
    var options = {
      'key': keyId,
      'amount': (amount * 100).toInt(), // Razorpay expects amount in paise
      'name': name,
      'order_id': orderId,
      'description': description,
      'timeout': 120, // in seconds
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
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
"""
with open(os.path.join(base_dir, "booking", "payment_service.dart"), "w") as f:
    f.write(payment_service)

print("Flutter address models and payment service created.")
