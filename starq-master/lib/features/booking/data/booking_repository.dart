import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/network/api_endpoints.dart';
import 'package:starq_app/core/utils/json_helpers.dart';
import 'package:starq_app/features/payment/domain/payment_models.dart';
import 'package:starq_app/features/booking/domain/booking_model.dart';
import 'package:starq_app/features/booking/domain/booking_quote.dart';

class TimeSlot {
  final String slot;
  final bool available;
  TimeSlot({required this.slot, required this.available});
}

class BookingRepository {
  final ApiClient _api;

  BookingRepository([ApiClient? api]) : _api = api ?? ApiClient();

  Future<List<TimeSlot>> slots({required String date, String? pincode}) async {
    final res = await _api.get(ApiEndpoints.availableSlots, queryParameters: {
      'date': date,
      if (pincode != null) 'pincode': pincode,
    });
    return asJsonList(asJsonMap(res.data)['data'])
        .map((e) => TimeSlot(slot: e['slot']?.toString() ?? '', available: e['available'] == true))
        .toList();
  }

  Future<Map<String, dynamic>> currentConsent() async {
    final res = await _api.get(ApiEndpoints.currentConsent);
    return asJsonMap(asJsonMap(res.data)['data']);
  }

  Future<String> submitConsent({
    required String vehicleId,
    required String notes,
    required String consentVersionId,
  }) async {
    final res = await _api.post(ApiEndpoints.consents, data: {
      'vehicle_id': vehicleId,
      'existing_damage_notes': notes,
      'consent_version_id': consentVersionId,
      'acknowledged': true,
    });
    return asJsonMap(asJsonMap(res.data)['data'])['id']?.toString() ?? '';
  }

  Future<BookingQuote> quote(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.quote, data: body);
    return BookingQuote.fromJson(asJsonMap(asJsonMap(res.data)['data']));
  }

  Future<RazorpayOrder> createOrder(String quoteToken) async {
    final res = await _api.post(ApiEndpoints.createPaymentOrder, data: {'quote_token': quoteToken});
    return RazorpayOrder.fromJson(asJsonMap(asJsonMap(res.data)['data']));
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) return data['data'] as Map<String, dynamic>;
      if (data['booking'] is Map<String, dynamic>) return data['booking'] as Map<String, dynamic>;
      return data;
    }
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      if (m['data'] is Map) return Map<String, dynamic>.from(m['data'] as Map);
      if (m['booking'] is Map) return Map<String, dynamic>.from(m['booking'] as Map);
      return m;
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data.map(asJsonMap).toList();
    }
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final raw = m['data'] ?? m['bookings'] ?? m['items'];
      if (raw is List) {
        return raw.map(asJsonMap).toList();
      }
    }
    return const [];
  }

  Future<Booking> verifyPayment(PaymentVerificationPayload payload) async {
    final res = await _api.post(ApiEndpoints.verifyPayment, data: payload.toJson());
    return Booking.fromJson(_extractMap(res.data));
  }

  Future<Booking> paymentStatus(String bookingId) async {
    final res = await _api.get(ApiEndpoints.paymentStatus(bookingId));
    final data = _extractMap(res.data);
    final bookingData = data['booking'] is Map ? data['booking'] : data;
    return Booking.fromJson(asJsonMap(bookingData));
  }

  Future<List<Booking>> list() async {
    final res = await _api.get(ApiEndpoints.bookings);
    final rawList = _extractList(res.data);
    final List<Booking> bookings = [];
    for (final item in rawList) {
      try {
        bookings.add(Booking.fromJson(item));
      } catch (_) {
        // Skip any corrupted record instead of failing the entire bookings view
      }
    }
    return bookings;
  }


  Future<Booking> getById(String id) async {
    final res = await _api.get(ApiEndpoints.booking(id));
    return Booking.fromJson(_extractMap(res.data));
  }

  Future<Booking> cancel(String id, String reason) async {
    final res = await _api.post(ApiEndpoints.cancelBooking(id), data: {'reason': reason});
    return Booking.fromJson(_extractMap(res.data));
  }

  Future<Map<String, dynamic>> rebook(String id) async {
    final res = await _api.post(ApiEndpoints.rebook(id));
    return asJsonMap(asJsonMap(res.data)['data']);
  }

  Future<void> submitReview({
    required String bookingId,
    required int rating,
    String? comment,
    List<String>? tags,
  }) async {
    await _api.post(ApiEndpoints.reviews, data: {
      'booking_id': bookingId,
      'rating': rating,
      'comment': comment,
      'tags': tags ?? [],
    });
  }

  Future<Map<String, dynamic>> tracking(String bookingId) async {
    final res = await _api.get(ApiEndpoints.bookingTracking(bookingId));
    return asJsonMap(asJsonMap(res.data)['data']);
  }

  Future<Map<String, dynamic>> inspection(String bookingId) async {
    final res = await _api.get(ApiEndpoints.bookingInspection(bookingId));
    return asJsonMap(asJsonMap(res.data)['data']);
  }

  Future<void> acknowledgeInspection(String bookingId) async {
    await _api.post(ApiEndpoints.consentInspection(bookingId), data: {'acknowledged': true});
  }
}
