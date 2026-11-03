import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/features/addresses/domain/address.dart' as domain_addr;
import 'package:starq_app/features/models/address_model.dart' as model_addr;
import 'package:starq_app/features/booking/choose_location_screen.dart';
import 'package:starq_app/features/booking/booking_summary_screen.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/providers/address_provider.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class MockAddressApiClient implements ApiClient {
  Map<String, dynamic>? lastPostedData;
  String? lastPostedPath;
  final List<String> postedPaths = [];
  final List<Map<String, dynamic>?> postedData = [];
  dynamic mockGetResponse = [];
  Map<String, dynamic> mockPostResponse = {};

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockGetResponse as T,
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
    lastPostedPath = path;
    lastPostedData = data as Map<String, dynamic>?;
    postedPaths.add(path);
    postedData.add(lastPostedData);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockPostResponse as T,
      statusCode: 201,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    dotenv.testLoad(mergeWith: {'API_BASE_URL': 'http://localhost:3000/api/v1'});
  });

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'AssetManifest.bin') {
          final manifestMap = <Object?, Object?>{};
          return const StandardMessageCodec().encodeMessage(manifestMap);
        }
        if (key == 'AssetManifest.json') {
          return ByteData.view(Uint8List.fromList(utf8.encode(jsonEncode({}))).buffer);
        }
        return ByteData.view(kTransparentImage.buffer);
      },
    );
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService().init();
  });

  group('Phase 3 - Address Model & Domain Parsing Tests', () {
    test('domain Address.fromJson parses clean address and strips [ARCHIVED] prefix', () {
      final json = {
        'id': 'addr-123',
        'userId': 'usr-1',
        'line1': 'Flat 101, Sunshine Heights',
        'line2': '[ARCHIVED] Home',
        'city': 'Noida',
        'state': 'Uttar Pradesh',
        'zipCode': '201301',
        'latitude': 28.627,
        'longitude': 77.364,
      };

      final addr = domain_addr.Address.fromJson(json);
      expect(addr.id, 'addr-123');
      expect(addr.label, 'Home'); // Verified: [ARCHIVED] was stripped cleanly
      expect(addr.addressLine, 'Flat 101, Sunshine Heights');
      expect(addr.city, 'Noida');
      expect(addr.pincode, '201301');
      expect(addr.latitude, 28.627);
      expect(addr.longitude, 77.364);
    });

    test('model Address.fromJson maps backend Prisma fields', () {
      final json = {
        'id': 'addr-456',
        'userId': 'usr-2',
        'line1': 'Tower A, Cyber Park',
        'line2': 'Work',
        'city': 'Gurugram',
        'state': 'Haryana',
        'zipCode': '122002',
      };

      final addr = model_addr.Address.fromJson(json);
      expect(addr.id, 'addr-456');
      expect(addr.line1, 'Tower A, Cyber Park');
      expect(addr.line2, 'Work');
      expect(addr.city, 'Gurugram');
      expect(addr.zipCode, '122002');
    });
  });

  group('Phase 3 - AddressProvider Tests', () {
    late MockAddressApiClient mockApi;
    late AddressProvider provider;

    setUp(() {
      mockApi = MockAddressApiClient();
      provider = AddressProvider(mockApi);
    });

    test('fetchAddresses parses raw list from /addresses', () async {
      mockApi.mockGetResponse = [
        {
          'id': 'a1',
          'userId': 'u1',
          'line1': 'Plot 4, Sector 15',
          'line2': 'Home',
          'city': 'Noida',
          'zipCode': '201301',
        },
      ];

      await provider.fetchAddresses();
      expect(provider.addresses.length, 1);
      expect(provider.addresses.first.id, 'a1');
      expect(provider.addresses.first.line1, 'Plot 4, Sector 15');
    });

    test('fetchAddresses parses wrapped { data: [...] } envelope', () async {
      mockApi.mockGetResponse = {
        'data': [
          {
            'id': 'a2',
            'userId': 'u1',
            'line1': 'Office 202',
            'line2': 'Office',
            'city': 'Noida',
            'zipCode': '201301',
          },
        ]
      };

      await provider.fetchAddresses();
      expect(provider.addresses.length, 1);
      expect(provider.addresses.first.id, 'a2');
    });

    test('addAddress posts to /addresses and refreshes address list', () async {
      mockApi.mockPostResponse = {'id': 'a3_created'};
      mockApi.mockGetResponse = [
        {
          'id': 'a3_created',
          'userId': 'u1',
          'line1': 'Villa 9',
          'line2': 'Home',
          'city': 'Noida',
        }
      ];

      final ok = await provider.addAddress({
        'line1': 'Villa 9',
        'line2': 'Home',
        'city': 'Noida',
      });

      expect(ok, isTrue);
      expect(mockApi.lastPostedPath, '/addresses');
      expect(mockApi.lastPostedData?['line1'], 'Villa 9');
      expect(provider.addresses.length, 1);
      expect(provider.addresses.first.id, 'a3_created');
    });
  });

  group('Phase 3 - ChooseLocationScreen & Booking Payload Preservation', () {
    late MockAddressApiClient mockApi;
    late BookingFlowProvider bookingFlow;
    late BookingProvider bookingProvider;

    setUp(() {
      mockApi = MockAddressApiClient();
      bookingFlow = BookingFlowProvider();
      bookingProvider = BookingProvider(mockApi);
    });

    test('BookingProvider.createBooking transmits addressId, vehicleId, and serviceId', () async {
      mockApi.mockPostResponse = {
        'id': 'booking-99',
        'orderId': 'order_mock_99',
        'totalAmount': 499.0,
      };

      final res = await bookingProvider.createBooking(
        'real-addr-uuid-1',
        DateTime(2026, 10, 25, 10, 0),
        vehicleId: 'vehicle-uuid-1',
        serviceId: 'service-uuid-1',
      );

      expect(res, isNotNull);
      expect(res?['orderId'], 'order_mock_99');
      expect(mockApi.lastPostedPath, '/bookings');
      expect(mockApi.lastPostedData?['addressId'], 'real-addr-uuid-1');
      expect(mockApi.lastPostedData?['vehicleId'], 'vehicle-uuid-1');
      expect(mockApi.lastPostedData?['serviceId'], 'service-uuid-1');
    });

    testWidgets('ChooseLocationScreen renders empty state when no addresses exist', (tester) async {
      mockApi.mockGetResponse = [];

      final router = GoRouter(
        initialLocation: '/choose-location',
        routes: [
          GoRoute(
            path: '/choose-location',
            builder: (context, state) => ChooseLocationScreen(apiClient: mockApi),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingFlowProvider>.value(value: bookingFlow),
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verified: No dummy addresses ('B-14 Sector 62' or 'Wave Silver Tower') shown
      expect(find.text('No saved addresses yet'), findsOneWidget);
      expect(find.text('B-14, Sector 62, Noida, Uttar Pradesh 201309'), findsNothing);
      expect(find.text('Wave Silver Tower, Sector 18, Noida, Uttar Pradesh 201301'), findsNothing);
    });

    testWidgets('ChooseLocationScreen selecting address navigates to summary with verified addressId', (tester) async {
      mockApi.mockGetResponse = [
        {
          'id': 'verified-addr-42',
          'line1': 'G-12, Sector 128',
          'line2': 'Primary Home',
          'city': 'Noida',
          'state': 'Uttar Pradesh',
          'zipCode': '201304',
          'latitude': 28.520,
          'longitude': 77.380,
        }
      ];

      Map<String, dynamic>? receivedSummaryExtra;

      final router = GoRouter(
        initialLocation: '/choose-location',
        routes: [
          GoRoute(
            path: '/choose-location',
            builder: (context, state) => ChooseLocationScreen(
              apiClient: mockApi,
              data: const {
                'vehicleId': 'veh-123',
                'serviceId': 'srv-456',
                'vehicleLabel': 'Honda City',
                'vehiclePlate': 'DL 01 AB 1234',
              },
            ),
          ),
          GoRoute(
            path: '/booking-summary',
            builder: (context, state) {
              receivedSummaryExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('Summary Target Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingFlowProvider>.value(value: bookingFlow),
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );

      // Trigger address loading
      await tester.pumpAndSettle();

      expect(find.text('Primary Home'), findsOneWidget);
      expect(find.textContaining('G-12, Sector 128'), findsOneWidget);

      await tester.tap(find.text('Confirm Location'));
      await tester.pumpAndSettle();

      expect(find.text('Summary Target Screen'), findsOneWidget);
      expect(receivedSummaryExtra, isNotNull);
      expect(receivedSummaryExtra?['addressId'], 'verified-addr-42');
      expect(receivedSummaryExtra?['vehicleId'], 'veh-123');
      expect(receivedSummaryExtra?['serviceId'], 'srv-456');
    });

    testWidgets('BookingSummaryScreen stops submission and displays SnackBar when addressId is missing', (tester) async {
      final router = GoRouter(
        initialLocation: '/booking-summary',
        routes: [
          GoRoute(
            path: '/booking-summary',
            builder: (context, state) => const BookingSummaryScreen(
              data: {
                'serviceTitle': 'Exterior Wash',
                'servicePrice': '₹249',
                'vehicleLabel': 'Honda City',
                'vehiclePlate': 'DL 01 AB 1234',
                // addressId is intentionally omitted
              },
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingFlowProvider>.value(value: bookingFlow),
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Continue to Payment'
      await tester.tap(find.text('Continue to Payment'));
      await tester.pump();

      // Verified: submission was stopped and SnackBar was shown
      expect(find.text('Please select a valid service address to continue'), findsOneWidget);
      expect(mockApi.lastPostedPath, isNull); // /bookings was NOT called
    });

    testWidgets('BookingSummaryScreen submits with verified addressId when provided', (tester) async {
      mockApi.mockPostResponse = {
        'id': 'booking-verified-1',
        'orderId': 'order_mock_verified',
        'totalAmount': 279.0,
      };

      final router = GoRouter(
        initialLocation: '/booking-summary',
        routes: [
          GoRoute(
            path: '/booking-summary',
            builder: (context, state) => const BookingSummaryScreen(
              data: {
                'addressId': 'verified-addr-99',
                'serviceId': 'service-valid-1',
                'serviceTitle': 'Exterior Wash',
                'servicePrice': '₹249',
                'vehicleLabel': 'Honda City',
                'vehiclePlate': 'DL 01 AB 1234',
              },
            ),
          ),
          GoRoute(
            path: '/order-confirmed',
            builder: (context, state) => const Scaffold(body: Text('Confirmed Target Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingFlowProvider>.value(value: bookingFlow),
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Continue to Payment'
      await tester.tap(find.text('Continue to Payment'));
      await tester.pumpAndSettle();

      // Verified: /bookings was called with verified addressId
      expect(mockApi.postedPaths, contains('/bookings'));
      final bookingCallIndex = mockApi.postedPaths.indexOf('/bookings');
      expect(mockApi.postedData[bookingCallIndex]?['addressId'], 'verified-addr-99');
      expect(find.text('Confirmed Target Screen'), findsOneWidget);
    });
  });
}
