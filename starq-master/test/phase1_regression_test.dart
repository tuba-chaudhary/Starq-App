import 'package:flutter_test/flutter_test.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/features/booking/data/booking_repository.dart';
import 'package:starq_app/features/booking/domain/booking_model.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:dio/dio.dart';

class MockApiClient implements ApiClient {
  dynamic mockGetData;
  dynamic mockPostData;
  String? lastGetPath;
  String? lastPostPath;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastGetPath = path;
    dynamic resultData = mockGetData;
    if (path.startsWith('/bookings/') && path != '/bookings') {
      if (mockGetData is List && (mockGetData as List).isNotEmpty) {
        resultData = (mockGetData as List).first;
      } else if (mockGetData is Map) {
        final m = mockGetData as Map;
        if (m['data'] is List && (m['data'] as List).isNotEmpty) {
          resultData = (m['data'] as List).first;
        } else if (m['bookings'] is List && (m['bookings'] as List).isNotEmpty) {
          resultData = (m['bookings'] as List).first;
        }
      }
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: resultData as T,
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastPostPath = path;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockPostData as T,
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase 1 - Booking.fromJson Backend Mappings', () {
    final Map<String, dynamic> prismaBookingJson = {
      'id': 'cm2b7x9ab0001xyz123456789',
      'userId': 'usr_customer_456',
      'status': 'CONFIRMED',
      'scheduledAt': '2026-10-25T14:30:00.000Z',
      'totalAmount': 599.0,
      'pointsAwarded': 25,
      'items': [
        {
          'priceAtBooking': 599.0,
          'serviceVariant': {
            'id': 'var_foam_01',
            'name': 'Foam Wash Variant',
            'price': 599.0,
            'durationMins': 45,
            'service': {
              'id': 'svc_foam_01',
              'name': 'Exterior Foam Wash',
              'description': 'Pressure foam wash for car exterior',
              'targetVehicleType': 'car',
              'slug': 'exterior-foam-wash',
            },
          },
        },
      ],
      'partner': {
        'id': 'partner_001',
        'rating': 4.9,
        'user': {
          'fullName': 'Vikram Singh',
          'phone': '9876543210',
        },
      },
      'createdAt': '2026-10-24T10:00:00.000Z',
    };

    test('correctly maps Prisma backend response to Booking model', () {
      final booking = Booking.fromJson(prismaBookingJson);

      expect(booking.id, 'cm2b7x9ab0001xyz123456789');
      // bookingNumber derived from id
      expect(booking.bookingNumber, '#CM2B7X9A');
      // customerId mapped from userId
      expect(booking.customerId, 'usr_customer_456');
      // status parsed from string
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.isActive, isTrue);
      expect(booking.isCompleted, isFalse);
      // totalAmount mapped to finalTotalAmount
      expect(booking.finalTotalAmount, 599.0);
      expect(booking.pointsAwarded, 25);

      // Service extracted from nested items -> serviceVariant -> service
      expect(booking.service, isNotNull);
      expect(booking.service!.id, 'svc_foam_01');
      expect(booking.service!.name, 'Exterior Foam Wash');
      expect(booking.service!.description, 'Pressure foam wash for car exterior');
      expect(booking.service!.targetVehicleType, 'car');
      expect(booking.service!.basePrice, 599.0);
      expect(booking.service!.durationMinutes, 45);

      // Partner user details extracted from nested user object
      expect(booking.partner, isNotNull);
      expect(booking.partner!.id, 'partner_001');
      expect(booking.partner!.name, 'Vikram Singh');
      expect(booking.partner!.phone, '9876543210');
      expect(booking.partner!.rating, 4.9);

      // scheduledTimeSlot formatted from scheduledAt
      expect(booking.scheduledTimeSlot, isNotEmpty);
    });

    test('preserves explicit bookingNumber if present in payload', () {
      final json = Map<String, dynamic>.from(prismaBookingJson);
      json['bookingNumber'] = 'STRQ-2026-001';

      final booking = Booking.fromJson(json);
      expect(booking.bookingNumber, 'STRQ-2026-001');
    });

    test('falls back correctly for short id or missing id', () {
      final shortJson = {'id': 'abc', 'userId': 'u1', 'status': 'COMPLETED'};
      expect(Booking.fromJson(shortJson).bookingNumber, '#ABC');

      final emptyJson = {'id': '', 'userId': 'u1', 'status': 'COMPLETED'};
      expect(Booking.fromJson(emptyJson).bookingNumber, 'Booking');
    });

    test('supports legacy flat service and partner formats', () {
      final legacyJson = {
        'id': 'booking_legacy_1',
        'customer_id': 'cust_1',
        'booking_number': 'LEGACY-001',
        'status': 'SERVICE_COMPLETED',
        'final_total_amount': 399.0,
        'scheduled_date': '2026-10-24T15:00:00.000Z',
        'scheduled_time_slot': '03:00 PM',
        'service': {
          'id': 'svc_legacy',
          'slug': 'basic-wash',
          'name': 'Basic Wash',
          'target_vehicle_type': 'bike',
          'description': 'Standard wash',
          'base_price': 399.0,
          'duration_minutes': 30,
          'image_asset_path': 'bike.png',
          'inclusions': <String, dynamic>{},
        },
        'partner': {
          'id': 'p_1',
          'name': 'Rahul Verma',
          'phone': '9123456789',
          'rating': 4.7,
        },
      };

      final booking = Booking.fromJson(legacyJson);
      expect(booking.bookingNumber, 'LEGACY-001');
      expect(booking.customerId, 'cust_1');
      expect(booking.status, BookingStatus.serviceCompleted);
      expect(booking.isCompleted, isTrue);
      expect(booking.finalTotalAmount, 399.0);
      expect(booking.scheduledTimeSlot, '03:00 PM');
      expect(booking.service?.name, 'Basic Wash');
      expect(booking.partner?.name, 'Rahul Verma');
    });
  });

  group('Phase 1 - BookingRepository List & Envelopes Parsing', () {
    late MockApiClient mockApi;
    late BookingRepository repository;

    final mockItem = {
      'id': 'cm2b7x9ab0001xyz123456789',
      'userId': 'usr_1',
      'status': 'CONFIRMED',
      'totalAmount': 299.0,
      'createdAt': '2026-10-24T10:00:00.000Z',
    };

    setUp(() {
      mockApi = MockApiClient();
      repository = BookingRepository(mockApi);
    });

    test('parses raw JSON list from backend GET /bookings', () async {
      mockApi.mockGetData = [mockItem, Map<String, dynamic>.from(mockItem)..['id'] = 'cm2b7x9ab0002xyz123456789'];

      final bookings = await repository.list();
      expect(bookings.length, 2);
      expect(bookings[0].id, 'cm2b7x9ab0001xyz123456789');
      expect(bookings[1].id, 'cm2b7x9ab0002xyz123456789');
    });

    test('parses wrapped {"data": [...]} response envelope', () async {
      mockApi.mockGetData = {
        'data': [mockItem],
      };

      final bookings = await repository.list();
      expect(bookings.length, 1);
      expect(bookings.first.id, 'cm2b7x9ab0001xyz123456789');
    });

    test('parses wrapped {"bookings": [...]} response envelope', () async {
      mockApi.mockGetData = {
        'bookings': [mockItem],
      };

      final bookings = await repository.list();
      expect(bookings.length, 1);
      expect(bookings.first.id, 'cm2b7x9ab0001xyz123456789');
    });

    test('parses wrapped {"items": [...]} response envelope', () async {
      mockApi.mockGetData = {
        'items': [mockItem],
      };

      final bookings = await repository.list();
      expect(bookings.length, 1);
      expect(bookings.first.id, 'cm2b7x9ab0001xyz123456789');
    });

    test('handles empty or malformed list response gracefully', () async {
      mockApi.mockGetData = <dynamic>[];
      expect(await repository.list(), isEmpty);

      mockApi.mockGetData = {'data': null};
      expect(await repository.list(), isEmpty);

      mockApi.mockGetData = 'not a valid payload';
      expect(await repository.list(), isEmpty);
    });

    test('getById handles both raw map and wrapped {"data": {...}}', () async {
      mockApi.mockGetData = mockItem;
      final b1 = await repository.getById('cm2b7x9ab0001xyz123456789');
      expect(b1.id, 'cm2b7x9ab0001xyz123456789');

      mockApi.mockGetData = {'data': mockItem};
      final b2 = await repository.getById('cm2b7x9ab0001xyz123456789');
      expect(b2.id, 'cm2b7x9ab0001xyz123456789');
    });
  });

  group('Phase 1 - BookingProvider fetchActiveBooking Envelopes', () {
    late MockApiClient mockApi;
    late BookingProvider provider;

    final activeBookingJson = {
      'id': 'booking_active_123',
      'userId': 'usr_1',
      'status': 'CONFIRMED',
      'totalAmount': 499.0,
      'createdAt': '2026-10-24T10:00:00.000Z',
    };

    setUp(() {
      mockApi = MockApiClient();
      provider = BookingProvider(mockApi);
    });

    test('fetchActiveBooking parses raw List backend response', () async {
      mockApi.mockGetData = [activeBookingJson];

      await provider.fetchActiveBooking();

      expect(provider.activeBooking, isNotNull);
      expect(provider.activeBooking!.id, 'booking_active_123');
      expect(provider.activeBooking!.isActive, isTrue);
    });

    test('fetchActiveBooking parses wrapped {"data": [...]} backend response', () async {
      mockApi.mockGetData = {
        'data': [activeBookingJson],
      };

      await provider.fetchActiveBooking();

      expect(provider.activeBooking, isNotNull);
      expect(provider.activeBooking!.id, 'booking_active_123');
      expect(provider.activeBooking!.isActive, isTrue);
    });
  });
}
