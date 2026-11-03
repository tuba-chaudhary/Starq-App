import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/features/booking/domain/booking_model.dart';
import 'package:starq_app/features/booking/booking_summary_screen.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/services/exterior_wash_screen.dart';
import 'package:starq_app/features/services/interior_wash_screen.dart';
import 'package:starq_app/core/config/app_constants.dart';
import 'package:starq_app/features/booking/domain/booking_quote.dart';
import 'package:starq_app/core/widgets/service_detail_template.dart';
import 'package:starq_app/features/services/bucket_wash_screen.dart';
import 'package:starq_app/features/home/home_dashboard_screen.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';
import 'package:starq_app/features/providers/vehicle_provider.dart';
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

class MockServiceApiClient implements ApiClient {
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
    lastPostedData = data is Map ? Map<String, dynamic>.from(data) : null;
    postedPaths.add(path);
    postedData.add(lastPostedData);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockPostResponse as T,
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Service ID & Price Propagation Bug Regression Tests', () {
    testWidgets('Unmapped service in catalog blocks booking and displays error without falling back to Basic Wash', (tester) async {
      final mockApi = MockServiceApiClient();
      // Catalog only contains "Basic Wash" (as in production backend)
      mockApi.mockGetResponse = [
        {
          'id': '9eaa3c73-830c-402f-afae-106488ec19c6',
          'name': 'Basic Wash',
          'category': 'CAR',
          'variants': [
            {
              'id': '20b7e020-adf6-404d-b566-9e27e2a03b0f',
              'name': 'Default',
              'price': 299,
              'durationMins': 30,
            }
          ]
        }
      ];

      final bookingProvider = BookingProvider(mockApi);
      await bookingProvider.fetchCatalog();
      expect(bookingProvider.services.length, 1);
      expect(bookingProvider.services.first.name, 'Basic Wash');

      Map<String, dynamic>? capturedExtra;

      final router = GoRouter(
        initialLocation: '/exterior-wash',
        routes: [
          GoRoute(
            path: '/exterior-wash',
            builder: (context, state) => const ExteriorWashScreen(),
          ),
          GoRoute(
            path: '/select-date-time',
            builder: (context, state) {
              capturedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('Select DateTime Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bookButton = find.text('Book This Service');
      expect(bookButton, findsOneWidget);
      await tester.tap(bookButton);
      await tester.pumpAndSettle();

      // Must NOT navigate to /select-date-time
      expect(capturedExtra, isNull);
      expect(find.text('Select DateTime Screen'), findsNothing);

      // Must display clear error SnackBar blocking the booking
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Service "Exterior Wash" is not available in the catalog'), findsOneWidget);
    });

    testWidgets('Verified service mapping successfully passes verified serviceId and variant to select-date-time', (tester) async {
      final mockApi = MockServiceApiClient();
      mockApi.mockGetResponse = [
        {
          'id': '9eaa3c73-830c-402f-afae-106488ec19c6',
          'name': 'Basic Wash',
          'category': 'CAR',
          'variants': [
            {
              'id': '20b7e020-adf6-404d-b566-9e27e2a03b0f',
              'name': 'Default',
              'price': 299,
              'durationMins': 30,
            }
          ]
        }
      ];

      final bookingProvider = BookingProvider(mockApi);
      await bookingProvider.fetchCatalog();

      Map<String, dynamic>? capturedExtra;

      final router = GoRouter(
        initialLocation: '/basic-wash',
        routes: [
          GoRoute(
            path: '/basic-wash',
            builder: (context, state) => const ServiceDetailTemplate(
              image: 'exterior_wash.png',
              title: 'Basic Wash',
              price: '₹299',
              duration: '30 min',
              rating: '4.8',
              serviceId: '9eaa3c73-830c-402f-afae-106488ec19c6',
              description: 'Basic Wash description',
              included: {'': ['Wash']},
            ),
          ),
          GoRoute(
            path: '/select-date-time',
            builder: (context, state) {
              capturedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('Select DateTime Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bookButton = find.text('Book This Service');
      expect(bookButton, findsOneWidget);
      await tester.tap(bookButton);
      await tester.pumpAndSettle();

      expect(capturedExtra, isNotNull);
      expect(capturedExtra!['serviceId'], '9eaa3c73-830c-402f-afae-106488ec19c6');
      expect(capturedExtra!['variantId'], '20b7e020-adf6-404d-b566-9e27e2a03b0f');
      expect(capturedExtra!['serviceTitle'], 'Basic Wash');
      expect(capturedExtra!['servicePrice'], '₹299');
    });

    testWidgets('BookingSummaryScreen stops submission and displays SnackBar when serviceId is missing', (tester) async {
      final mockApi = MockServiceApiClient();
      final bookingProvider = BookingProvider(mockApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            home: BookingSummaryScreen(
              data: {
                'addressId': 'addr_valid_123',
                // serviceId intentionally omitted/empty
                'serviceTitle': 'Unknown Wash',
                'servicePrice': '₹249',
                'vehicleId': 'veh_test_123',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final payButton = find.text('Continue to Payment');
      await tester.ensureVisible(payButton);
      await tester.tap(payButton);
      await tester.pumpAndSettle();

      // Must block booking and display error SnackBar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Please select a valid service to continue'), findsOneWidget);
      // Must NOT submit POST /bookings
      expect(mockApi.postedPaths.contains('/bookings'), isFalse);
    });

    testWidgets('BookingSummaryScreen submits with verified serviceId and addressId', (tester) async {
      final mockApi = MockServiceApiClient();
      mockApi.mockPostResponse = {
        'booking': {'id': 'b_service_test_1'},
        'orderId': 'order_service_test_1',
      };
      final bookingProvider = BookingProvider(mockApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            home: BookingSummaryScreen(
              data: {
                'addressId': 'addr_valid_123',
                'serviceId': '9eaa3c73-830c-402f-afae-106488ec19c6',
                'serviceTitle': 'Basic Wash',
                'servicePrice': '₹299',
                'vehicleId': 'veh_test_123',
                'vehicleLabel': 'Honda City',
                'vehiclePlate': 'DL 01 AB 1234',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final payButton = find.text('Continue to Payment');
      await tester.ensureVisible(payButton);
      await tester.tap(payButton);
      await tester.pumpAndSettle();

      expect(mockApi.postedPaths.contains('/bookings'), isTrue);
      final bookingIndex = mockApi.postedPaths.indexOf('/bookings');
      final bookingPayload = mockApi.postedData[bookingIndex];
      expect(bookingPayload?['serviceId'], '9eaa3c73-830c-402f-afae-106488ec19c6');
      expect(bookingPayload?['addressId'], 'addr_valid_123');
      expect(bookingPayload?['vehicleId'], 'veh_test_123');
    });

    test('BookingProvider.createBooking rejects missing or empty serviceId without transmitting empty string', () async {
      final mockApi = MockServiceApiClient();
      final provider = BookingProvider(mockApi);

      final result = await provider.createBooking(
        'addr_1',
        DateTime.now(),
        vehicleId: 'v_1',
        serviceId: '',
      );

      expect(result, isNull);
      expect(provider.error, contains('serviceId is required'));
      expect(mockApi.postedPaths.isEmpty, isTrue);
    });

    test('Booking.fromJson correctly parses service name, price, and total amount from backend Prisma structure', () {
      final backendResponse = {
        'id': 'b_100',
        'userId': 'u_100',
        'status': 'PENDING_PAYMENT',
        'totalAmount': 299,
        'scheduledAt': '2026-10-25T10:00:00.000Z',
        'items': [
          {
            'id': 'item_1',
            'bookingId': 'b_100',
            'serviceVariantId': '20b7e020-adf6-404d-b566-9e27e2a03b0f',
            'priceAtBooking': 299,
            'serviceVariant': {
              'id': '20b7e020-adf6-404d-b566-9e27e2a03b0f',
              'serviceId': '9eaa3c73-830c-402f-afae-106488ec19c6',
              'name': 'Default',
              'price': 299,
              'durationMins': 30,
              'service': {
                'id': '9eaa3c73-830c-402f-afae-106488ec19c6',
                'name': 'Basic Wash',
                'description': 'Exterior washing and cleaning',
                'category': 'CAR'
              }
            }
          }
        ]
      };

      final booking = Booking.fromJson(backendResponse);
      expect(booking.id, 'b_100');
      expect(booking.service?.id, '9eaa3c73-830c-402f-afae-106488ec19c6');
      expect(booking.service?.name, 'Basic Wash');
      expect(booking.service?.basePrice, 299.0);
      expect(booking.finalTotalAmount, 299.0);
    });

    test('AppConstants and BookingQuote missing-fee fallback are zero', () {
      expect(AppConstants.defaultConvenienceFee, 0.0);

      final quote = BookingQuote.fromJson({
        'base_service_amount': 249.0,
        'final_total_amount': 249.0,
      });
      expect(quote.convenienceFee, 0.0);
    });

    testWidgets('BookingSummaryScreen displays zero convenience fee and total equals base price', (tester) async {
      final mockApi = MockServiceApiClient();
      final bookingProvider = BookingProvider(mockApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            home: BookingSummaryScreen(
              data: {
                'addressId': 'addr_valid_123',
                'serviceId': '9eaa3c73-830c-402f-afae-106488ec19c6',
                'serviceTitle': 'Exterior Wash',
                'servicePrice': '₹249',
                'vehicleId': 'veh_test_123',
                'vehicleLabel': 'Honda City',
                'vehiclePlate': 'DL 01 AB 1234',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('convenience fee'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);
      expect(find.text('₹249'), findsNWidgets(2));
    });

    testWidgets('BookingSummaryScreen fails safely and displays error SnackBar if booking creation fails', (tester) async {
      final mockApi = MockServiceApiClient();
      mockApi.mockPostResponse = {};
      final bookingProvider = BookingProvider(mockApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            home: BookingSummaryScreen(
              data: {
                'addressId': 'addr_valid_123',
                'serviceId': '9eaa3c73-830c-402f-afae-106488ec19c6',
                'serviceTitle': 'Exterior Wash',
                'servicePrice': '₹249',
                'vehicleId': 'veh_test_123',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final payButton = find.text('Continue to Payment');
      await tester.ensureVisible(payButton);
      await tester.tap(payButton);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Failed to create booking'), findsOneWidget);
    });

    testWidgets('InteriorWashScreen aligns title to Interior Cleaning', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>(create: (_) => BookingProvider(MockServiceApiClient())),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: InteriorWashScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Interior Cleaning'), findsOneWidget);
      expect(find.text('Interior Wash'), findsNothing);
    });

    test('All six services in proposed catalog resolve strictly to their own distinct IDs, prices, and categories', () async {
      final mockApi = MockServiceApiClient();
      final mockCatalog = [
        {
          'id': 'a0000001-0000-4000-8000-000000000001',
          'name': 'Exterior Wash',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000001-0000-4000-8000-000000000001', 'name': 'Default', 'price': 249, 'durationMins': 45}
          ]
        },
        {
          'id': 'a0000002-0000-4000-8000-000000000002',
          'name': 'Interior Cleaning',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000002-0000-4000-8000-000000000002', 'name': 'Default', 'price': 399, 'durationMins': 60}
          ]
        },
        {
          'id': 'a0000003-0000-4000-8000-000000000003',
          'name': 'Full Detailing',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000003-0000-4000-8000-000000000003', 'name': 'Default', 'price': 999, 'durationMins': 120}
          ]
        },
        {
          'id': 'a0000004-0000-4000-8000-000000000004',
          'name': 'Premium Wash',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000004-0000-4000-8000-000000000004', 'name': 'Default', 'price': 1299, 'durationMins': 90}
          ]
        },
        {
          'id': 'a0000005-0000-4000-8000-000000000005',
          'name': 'Bucket Wash',
          'category': 'BIKE',
          'variants': [
            {'id': 'b0000005-0000-4000-8000-000000000005', 'name': 'Default', 'price': 299, 'durationMins': 20}
          ]
        },
        {
          'id': 'a0000006-0000-4000-8000-000000000006',
          'name': 'Pressure Wash',
          'category': 'BIKE',
          'variants': [
            {'id': 'b0000006-0000-4000-8000-000000000006', 'name': 'Default', 'price': 399, 'durationMins': 30}
          ]
        },
      ];

      mockApi.mockGetResponse = mockCatalog;
      final provider = BookingProvider(mockApi);
      await provider.fetchCatalog();

      expect(provider.services.length, 6);

      final extWash = provider.services.firstWhere((s) => s.name == 'Exterior Wash');
      expect(extWash.id, 'a0000001-0000-4000-8000-000000000001');
      expect(extWash.category, 'CAR');
      expect(extWash.variants.first.price, 249.0);

      final intClean = provider.services.firstWhere((s) => s.name == 'Interior Cleaning');
      expect(intClean.id, 'a0000002-0000-4000-8000-000000000002');
      expect(intClean.category, 'CAR');
      expect(intClean.variants.first.price, 399.0);

      final fullDet = provider.services.firstWhere((s) => s.name == 'Full Detailing');
      expect(fullDet.id, 'a0000003-0000-4000-8000-000000000003');
      expect(fullDet.category, 'CAR');
      expect(fullDet.variants.first.price, 999.0);

      final premWash = provider.services.firstWhere((s) => s.name == 'Premium Wash');
      expect(premWash.id, 'a0000004-0000-4000-8000-000000000004');
      expect(premWash.category, 'CAR');
      expect(premWash.variants.first.price, 1299.0);

      final bucketWash = provider.services.firstWhere((s) => s.name == 'Bucket Wash');
      expect(bucketWash.id, 'a0000005-0000-4000-8000-000000000005');
      expect(bucketWash.category, 'BIKE');
      expect(bucketWash.variants.first.price, 299.0);

      final pressWash = provider.services.firstWhere((s) => s.name == 'Pressure Wash');
      expect(pressWash.id, 'a0000006-0000-4000-8000-000000000006');
      expect(pressWash.category, 'BIKE');
      expect(pressWash.variants.first.price, 399.0);
    });

    testWidgets('Car service blocks booking when a bike vehicle is selected', (tester) async {
      final mockApi = MockServiceApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'a0000001-0000-4000-8000-000000000001',
          'name': 'Exterior Wash',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000001-0000-4000-8000-000000000001', 'name': 'Default', 'price': 249, 'durationMins': 45}
          ]
        }
      ];

      final provider = BookingProvider(mockApi);
      await provider.fetchCatalog();

      final router = GoRouter(
        initialLocation: '/exterior-wash',
        routes: [
          GoRoute(
            path: '/exterior-wash',
            builder: (context, state) => const ExteriorWashScreen(
              data: {'vehicleType': 'bike'},
            ),
          ),
          GoRoute(
            path: '/select-date-time',
            builder: (context, state) => const Scaffold(body: Text('DateTime')),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: provider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bookButton = find.text('Book This Service');
      await tester.tap(bookButton);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Service "Exterior Wash" is for cars only. Please select a car.'), findsOneWidget);
      expect(find.text('DateTime'), findsNothing);
    });

    testWidgets('Bike service blocks booking when a car vehicle is selected', (tester) async {
      final mockApi = MockServiceApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'a0000005-0000-4000-8000-000000000005',
          'name': 'Bucket Wash',
          'category': 'BIKE',
          'variants': [
            {'id': 'b0000005-0000-4000-8000-000000000005', 'name': 'Default', 'price': 299, 'durationMins': 20}
          ]
        }
      ];

      final provider = BookingProvider(mockApi);
      await provider.fetchCatalog();

      final router = GoRouter(
        initialLocation: '/bucket-wash',
        routes: [
          GoRoute(
            path: '/bucket-wash',
            builder: (context, state) => const BucketWashScreen(
              data: {'vehicleType': 'car'},
            ),
          ),
          GoRoute(
            path: '/select-date-time',
            builder: (context, state) => const Scaffold(body: Text('DateTime')),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: provider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bookButton = find.text('Book This Service');
      await tester.tap(bookButton);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Service "Bucket Wash" is for bikes only. Please select a bike.'), findsOneWidget);
      expect(find.text('DateTime'), findsNothing);
    });

    testWidgets('Car service passes verified ID, price, vehicleType and category to select-date-time when car is used', (tester) async {
      final mockApi = MockServiceApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'a0000001-0000-4000-8000-000000000001',
          'name': 'Exterior Wash',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000001-0000-4000-8000-000000000001', 'name': 'Default', 'price': 249, 'durationMins': 45}
          ]
        }
      ];

      final provider = BookingProvider(mockApi);
      await provider.fetchCatalog();

      Map<String, dynamic>? capturedExtra;

      final router = GoRouter(
        initialLocation: '/exterior-wash',
        routes: [
          GoRoute(
            path: '/exterior-wash',
            builder: (context, state) => const ExteriorWashScreen(
              data: {'vehicleType': 'car', 'vehicleId': 'veh_car_1'},
            ),
          ),
          GoRoute(
            path: '/select-date-time',
            builder: (context, state) {
              capturedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('DateTime'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: provider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book This Service'));
      await tester.pumpAndSettle();

      expect(capturedExtra, isNotNull);
      expect(capturedExtra!['serviceId'], 'a0000001-0000-4000-8000-000000000001');
      expect(capturedExtra!['variantId'], 'b0000001-0000-4000-8000-000000000001');
      expect(capturedExtra!['serviceTitle'], 'Exterior Wash');
      expect(capturedExtra!['servicePrice'], '₹249');
      expect(capturedExtra!['vehicleType'], 'car');
      expect(capturedExtra!['serviceCategory'], 'CAR');
    });

    testWidgets('Bike service passes verified ID, price, vehicleType and category to select-date-time when bike is used', (tester) async {
      final mockApi = MockServiceApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'a0000005-0000-4000-8000-000000000005',
          'name': 'Bucket Wash',
          'category': 'BIKE',
          'variants': [
            {'id': 'b0000005-0000-4000-8000-000000000005', 'name': 'Default', 'price': 299, 'durationMins': 20}
          ]
        }
      ];

      final provider = BookingProvider(mockApi);
      await provider.fetchCatalog();

      Map<String, dynamic>? capturedExtra;

      final router = GoRouter(
        initialLocation: '/bucket-wash',
        routes: [
          GoRoute(
            path: '/bucket-wash',
            builder: (context, state) => const BucketWashScreen(
              data: {'vehicleType': 'bike', 'vehicleId': 'veh_bike_1'},
            ),
          ),
          GoRoute(
            path: '/select-date-time',
            builder: (context, state) {
              capturedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('DateTime'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: provider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book This Service'));
      await tester.pumpAndSettle();

      expect(capturedExtra, isNotNull);
      expect(capturedExtra!['serviceId'], 'a0000005-0000-4000-8000-000000000005');
      expect(capturedExtra!['variantId'], 'b0000005-0000-4000-8000-000000000005');
      expect(capturedExtra!['serviceTitle'], 'Bucket Wash');
      expect(capturedExtra!['servicePrice'], '₹299');
      expect(capturedExtra!['vehicleType'], 'bike');
      expect(capturedExtra!['serviceCategory'], 'BIKE');
    });

    testWidgets('HomeDashboardScreen displays exactly four car services when Car is selected, hiding Basic Wash and Bike services', (tester) async {
      final mockApi = MockServiceApiClient();
      // Provide full 7-service backend catalog (6 new + 1 preserved Basic Wash)
      mockApi.mockGetResponse = [
        {
          'id': 'a0000001-0000-4000-8000-000000000001',
          'name': 'Exterior Wash',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000001-0000-4000-8000-000000000001', 'name': 'Default', 'price': 249, 'durationMins': 45}
          ]
        },
        {
          'id': 'a0000002-0000-4000-8000-000000000002',
          'name': 'Interior Cleaning',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000002-0000-4000-8000-000000000002', 'name': 'Default', 'price': 399, 'durationMins': 60}
          ]
        },
        {
          'id': 'a0000003-0000-4000-8000-000000000003',
          'name': 'Full Detailing',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000003-0000-4000-8000-000000000003', 'name': 'Default', 'price': 999, 'durationMins': 120}
          ]
        },
        {
          'id': 'a0000004-0000-4000-8000-000000000004',
          'name': 'Premium Wash',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000004-0000-4000-8000-000000000004', 'name': 'Default', 'price': 1299, 'durationMins': 90}
          ]
        },
        {
          'id': 'a0000005-0000-4000-8000-000000000005',
          'name': 'Bucket Wash',
          'category': 'BIKE',
          'variants': [
            {'id': 'b0000005-0000-4000-8000-000000000005', 'name': 'Default', 'price': 299, 'durationMins': 20}
          ]
        },
        {
          'id': 'a0000006-0000-4000-8000-000000000006',
          'name': 'Pressure Wash',
          'category': 'BIKE',
          'variants': [
            {'id': 'b0000006-0000-4000-8000-000000000006', 'name': 'Default', 'price': 399, 'durationMins': 30}
          ]
        },
        {
          'id': '9eaa3c73-830c-402f-afae-106488ec19c6',
          'name': 'Basic Wash',
          'category': 'CAR',
          'variants': [
            {'id': '20b7e020-adf6-404d-b566-9e27e2a03b0f', 'name': 'Default', 'price': 299, 'durationMins': 30}
          ]
        },
      ];

      final bookingProvider = BookingProvider(mockApi);
      final garageProvider = GarageProvider();
      final vehicleProvider = VehicleProvider(mockApi);

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeDashboardScreen(),
          ),
        ],
      );

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<GarageProvider>.value(value: garageProvider),
            ChangeNotifierProvider<VehicleProvider>.value(value: vehicleProvider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Car and Bike selectable cards are present
      expect(find.byKey(const Key('category_card_car')), findsOneWidget);
      expect(find.byKey(const Key('category_card_bike')), findsOneWidget);

      // Verify Car services header
      expect(find.text('Car Services'), findsOneWidget);

      // Verify exactly the 4 car services are displayed
      expect(find.text('Exterior Wash'), findsOneWidget);
      expect(find.text('Interior Cleaning'), findsOneWidget);
      expect(find.text('Full Detailing'), findsOneWidget);
      expect(find.text('Premium Wash'), findsOneWidget);

      // Verify backend-provided prices in service tiles
      expect(
        find.descendant(
          of: find.byKey(const Key('service_tile_exterior_wash')),
          matching: find.textContaining('₹249'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('service_tile_interior_cleaning')),
          matching: find.textContaining('₹399'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('service_tile_full_detailing')),
          matching: find.textContaining('₹999'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('service_tile_premium_wash')),
          matching: find.textContaining('₹1,299'),
        ),
        findsOneWidget,
      );

      // Verify Bike services and Basic Wash are NOT displayed
      expect(find.text('Bucket Wash'), findsNothing);
      expect(find.text('Pressure Wash'), findsNothing);
      expect(find.text('Basic Wash'), findsNothing);
      expect(find.textContaining('₹299'), findsNothing);
    });

    testWidgets('HomeDashboardScreen switches to Bike category, displaying exactly two bike services and updating header/banner', (tester) async {
      final mockApi = MockServiceApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'a0000001-0000-4000-8000-000000000001',
          'name': 'Exterior Wash',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000001-0000-4000-8000-000000000001', 'name': 'Default', 'price': 249, 'durationMins': 45}
          ]
        },
        {
          'id': 'a0000002-0000-4000-8000-000000000002',
          'name': 'Interior Cleaning',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000002-0000-4000-8000-000000000002', 'name': 'Default', 'price': 399, 'durationMins': 60}
          ]
        },
        {
          'id': 'a0000003-0000-4000-8000-000000000003',
          'name': 'Full Detailing',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000003-0000-4000-8000-000000000003', 'name': 'Default', 'price': 999, 'durationMins': 120}
          ]
        },
        {
          'id': 'a0000004-0000-4000-8000-000000000004',
          'name': 'Premium Wash',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000004-0000-4000-8000-000000000004', 'name': 'Default', 'price': 1299, 'durationMins': 90}
          ]
        },
        {
          'id': 'a0000005-0000-4000-8000-000000000005',
          'name': 'Bucket Wash',
          'category': 'BIKE',
          'variants': [
            {'id': 'b0000005-0000-4000-8000-000000000005', 'name': 'Default', 'price': 299, 'durationMins': 20}
          ]
        },
        {
          'id': 'a0000006-0000-4000-8000-000000000006',
          'name': 'Pressure Wash',
          'category': 'BIKE',
          'variants': [
            {'id': 'b0000006-0000-4000-8000-000000000006', 'name': 'Default', 'price': 399, 'durationMins': 30}
          ]
        },
        {
          'id': '9eaa3c73-830c-402f-afae-106488ec19c6',
          'name': 'Basic Wash',
          'category': 'CAR',
          'variants': [
            {'id': '20b7e020-adf6-404d-b566-9e27e2a03b0f', 'name': 'Default', 'price': 299, 'durationMins': 30}
          ]
        },
      ];

      final bookingProvider = BookingProvider(mockApi);
      final garageProvider = GarageProvider();
      final vehicleProvider = VehicleProvider(mockApi);

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeDashboardScreen(),
          ),
        ],
      );

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<GarageProvider>.value(value: garageProvider),
            ChangeNotifierProvider<VehicleProvider>.value(value: vehicleProvider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Bike card
      await tester.tap(find.byKey(const Key('category_card_bike')));
      await tester.pumpAndSettle();

      // Verify header updated to Bike Services
      expect(find.text('Bike Services'), findsOneWidget);

      // Verify banner updated to bike starting price
      expect(find.text('Starting from ₹299 · 20 min'), findsOneWidget);

      // Verify exactly the 2 bike services are displayed
      expect(find.text('Bucket Wash'), findsOneWidget);
      expect(find.text('Pressure Wash'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('service_tile_bucket_wash')),
          matching: find.textContaining('₹299'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('service_tile_pressure_wash')),
          matching: find.textContaining('₹399'),
        ),
        findsOneWidget,
      );

      // Verify car services are now hidden
      expect(find.text('Exterior Wash'), findsNothing);
      expect(find.text('Interior Cleaning'), findsNothing);
      expect(find.text('Full Detailing'), findsNothing);
      expect(find.text('Premium Wash'), findsNothing);
      expect(find.text('Basic Wash'), findsNothing);

      // Switch back to Car
      await tester.tap(find.byKey(const Key('category_card_car')));
      await tester.pumpAndSettle();

      // Verify Car services are restored
      expect(find.text('Car Services'), findsOneWidget);
      expect(find.text('Exterior Wash'), findsOneWidget);
      expect(find.text('Interior Cleaning'), findsOneWidget);
      expect(find.text('Full Detailing'), findsOneWidget);
      expect(find.text('Premium Wash'), findsOneWidget);
      expect(find.text('Bucket Wash'), findsNothing);
      expect(find.text('Pressure Wash'), findsNothing);
    });

    testWidgets('Tapping service tile preserves selected service in BookingProvider and passes backend IDs and prices to route', (tester) async {
      final mockApi = MockServiceApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'a0000001-0000-4000-8000-000000000001',
          'name': 'Exterior Wash',
          'category': 'CAR',
          'variants': [
            {'id': 'b0000001-0000-4000-8000-000000000001', 'name': 'Default', 'price': 249, 'durationMins': 45}
          ]
        },
        {
          'id': 'a0000005-0000-4000-8000-000000000005',
          'name': 'Bucket Wash',
          'category': 'BIKE',
          'variants': [
            {'id': 'b0000005-0000-4000-8000-000000000005', 'name': 'Default', 'price': 299, 'durationMins': 20}
          ]
        },
      ];

      final bookingProvider = BookingProvider(mockApi);
      final garageProvider = GarageProvider();
      final vehicleProvider = VehicleProvider(mockApi);

      Map<String, dynamic>? capturedCarExtra;
      Map<String, dynamic>? capturedBikeExtra;

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeDashboardScreen(),
          ),
          GoRoute(
            path: '/exterior-wash',
            builder: (context, state) {
              capturedCarExtra = state.extra as Map<String, dynamic>?;
              return Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back From Car'),
                ),
              );
            },
          ),
          GoRoute(
            path: '/bucket-wash',
            builder: (context, state) {
              capturedBikeExtra = state.extra as Map<String, dynamic>?;
              return Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back From Bike'),
                ),
              );
            },
          ),
        ],
      );

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<GarageProvider>.value(value: garageProvider),
            ChangeNotifierProvider<VehicleProvider>.value(value: vehicleProvider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Exterior Wash tile
      await tester.tap(find.text('Exterior Wash'));
      await tester.pumpAndSettle();

      // Verify route extra has verified serviceId, variantId, price, category
      expect(capturedCarExtra, isNotNull);
      expect(capturedCarExtra!['serviceId'], 'a0000001-0000-4000-8000-000000000001');
      expect(capturedCarExtra!['variantId'], 'b0000001-0000-4000-8000-000000000001');
      expect(capturedCarExtra!['serviceTitle'], 'Exterior Wash');
      expect(capturedCarExtra!['servicePrice'], '₹249');
      expect(capturedCarExtra!['serviceCategory'], 'CAR');
      expect(capturedCarExtra!['vehicleType'], 'car');

      // Verify BookingProvider holds selectedService
      expect(bookingProvider.selectedService, isNotNull);
      expect(bookingProvider.selectedService!.name, 'Exterior Wash');
      expect(bookingProvider.selectedService!.id, 'a0000001-0000-4000-8000-000000000001');

      // Go back to home
      await tester.tap(find.text('Back From Car'));
      await tester.pumpAndSettle();

      // Switch to Bike category
      await tester.tap(find.byKey(const Key('category_card_bike')));
      await tester.pumpAndSettle();

      // Tap Bucket Wash tile
      await tester.tap(find.text('Bucket Wash'));
      await tester.pumpAndSettle();

      // Verify Bike route extra
      expect(capturedBikeExtra, isNotNull);
      expect(capturedBikeExtra!['serviceId'], 'a0000005-0000-4000-8000-000000000005');
      expect(capturedBikeExtra!['variantId'], 'b0000005-0000-4000-8000-000000000005');
      expect(capturedBikeExtra!['serviceTitle'], 'Bucket Wash');
      expect(capturedBikeExtra!['servicePrice'], '₹299');
      expect(capturedBikeExtra!['serviceCategory'], 'BIKE');
      expect(capturedBikeExtra!['vehicleType'], 'bike');

      // Verify BookingProvider holds selectedService
      expect(bookingProvider.selectedService, isNotNull);
      expect(bookingProvider.selectedService!.name, 'Bucket Wash');
      expect(bookingProvider.selectedService!.id, 'a0000005-0000-4000-8000-000000000005');
    });
  });
}
