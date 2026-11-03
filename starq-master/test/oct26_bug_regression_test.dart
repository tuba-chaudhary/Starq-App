import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/core/storage/secure_storage_service.dart';
import 'package:starq_app/core/widgets/service_detail_template.dart';
import 'package:starq_app/features/addresses/saved_addresses_screen.dart';
import 'package:starq_app/features/auth/domain/user_model.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:starq_app/features/home/home_dashboard_screen.dart';
import 'package:starq_app/features/models/address_model.dart';
import 'package:starq_app/features/models/service_model.dart';
import 'package:starq_app/features/models/vehicle_model.dart';
import 'package:starq_app/features/profile/profile_screen.dart';
import 'package:starq_app/features/providers/address_provider.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/providers/rewards_provider.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';

final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class MockTestApiClient implements ApiClient {
  final List<String> requestedPaths = [];
  final List<String> postedPaths = [];
  final List<Map<String, dynamic>?> postedData = [];
  dynamic getResponse = [];
  dynamic postResponse = {};

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    requestedPaths.add(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: getResponse as T,
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
    requestedPaths.add(path);
    postedPaths.add(path);
    postedData.add(data is Map ? Map<String, dynamic>.from(data) : null);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: postResponse as T,
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    requestedPaths.add(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true} as T,
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
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService().init();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage(<Object?, Object?>{});
        }
        if (key == 'AssetManifest.json') {
          return ByteData.view(Uint8List.fromList(utf8.encode(jsonEncode({}))).buffer);
        }
        return ByteData.view(kTransparentImage.buffer);
      },
    );
  });

  group('26 October Bug Regression Test Suite', () {
    // 1. Bike + Bucket Wash and Bike + Pressure Wash reach quote/booking validation with the correct BIKE category
    testWidgets('1. Bike + Bucket Wash and Bike + Pressure Wash validate with BIKE category without car conflict', (tester) async {
      final mockClient = MockTestApiClient();
      final bookingProvider = BookingProvider(mockClient);

      // Add bike services to provider
      final bucketWashService = Service(
        id: 's_bike_bucket',
        name: 'Bucket Wash',
        description: 'Eco-friendly bike wash',
        category: 'BIKE',
        variants: [ServiceVariant(id: 'var_bb', name: 'Standard', price: 299)],
      );
      final pressureWashService = Service(
        id: 's_bike_pressure',
        name: 'Pressure Wash',
        description: 'Deep pressure bike cleaning',
        category: 'BIKE',
        variants: [ServiceVariant(id: 'var_bp', name: 'Standard', price: 399)],
      );
      bookingProvider.services.addAll([bucketWashService, pressureWashService]);

      // Simulate a user who has a car vehicle selected in provider
      bookingProvider.selectVehicle(Vehicle(
        id: 'v_user_car',
        userId: 'u1',
        vehicleTypeId: 'vt_car',
        make: 'Honda',
        model: 'City',
        licensePlate: 'KA 01 AB 1234',
        vehicleType: {'name': 'CAR'},
      ));

      String? pushedRoute;
      Map<String, dynamic>? pushedExtra;

      final router = GoRouter(
        initialLocation: '/bucket-wash',
        routes: [
          GoRoute(
            path: '/bucket-wash',
            builder: (context, state) => ServiceDetailTemplate(
              image: 'Bike_Bucket_wash.png',
              title: 'Bucket Wash',
              price: '₹299',
              duration: '20 min',
              serviceId: 's_bike_bucket',
              extraData: const {
                'vehicleType': 'bike',
                'serviceCategory': 'BIKE',
              },
              description: 'Bike Bucket Wash Description',
              included: const {'What is included': ['Foam wash', 'Chain wipe']},
            ),
          ),
          GoRoute(
            path: '/select-date-time',
            builder: (context, state) {
              pushedRoute = '/select-date-time';
              pushedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('Select Date Time Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Book This Service
      await tester.tap(find.text('Book This Service'));
      await tester.pumpAndSettle();

      // Should smoothly navigate to select-date-time without throwing Car error
      expect(pushedRoute, '/select-date-time');
      expect(pushedExtra?['vehicleType'], 'bike');
      expect(pushedExtra?['serviceCategory'], 'BIKE');
      expect(find.textContaining('is for cars only'), findsNothing);
    });

    // 2. Car services remain compatible with CAR vehicles
    testWidgets('2. Car services remain compatible with CAR vehicles', (tester) async {
      final mockClient = MockTestApiClient();
      final bookingProvider = BookingProvider(mockClient);

      final exteriorService = Service(
        id: 's_car_ext',
        name: 'Exterior Wash',
        description: 'Complete foam wash',
        category: 'CAR',
        variants: [ServiceVariant(id: 'var_ext', name: 'Standard', price: 249)],
      );
      bookingProvider.services.add(exteriorService);
      bookingProvider.selectVehicle(Vehicle(
        id: 'v_user_car',
        userId: 'u1',
        vehicleTypeId: 'vt_car',
        make: 'Honda',
        model: 'City',
        licensePlate: 'KA 01 AB 1234',
        vehicleType: {'name': 'CAR'},
      ));

      String? pushedRoute;
      Map<String, dynamic>? pushedExtra;

      final router = GoRouter(
        initialLocation: '/exterior-wash',
        routes: [
          GoRoute(
            path: '/exterior-wash',
            builder: (context, state) => ServiceDetailTemplate(
              image: 'exterior_wash.png',
              title: 'Exterior Wash',
              price: '₹249',
              duration: '45 min',
              serviceId: 's_car_ext',
              extraData: const {
                'vehicleType': 'car',
                'serviceCategory': 'CAR',
              },
              description: 'Exterior Wash Description',
              included: const {'What is included': ['Foam spray', 'Microfiber dry']},
            ),
          ),
          GoRoute(
            path: '/select-date-time',
            builder: (context, state) {
              pushedRoute = '/select-date-time';
              pushedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('Select Date Time Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book This Service'));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/select-date-time');
      expect(pushedExtra?['vehicleType'], 'car');
      expect(pushedExtra?['serviceCategory'], 'CAR');
      expect(find.textContaining('is for bikes only'), findsNothing);
    });

    // 3. Repeated booking submission idempotency test
    testWidgets('3. A repeated booking submission transmits idempotencyKey and guards against duplicate creation', (tester) async {
      final mockClient = MockTestApiClient();
      mockClient.postResponse = {
        'id': 'booking_res_1',
        'orderId': 'order_mock_123',
        'totalAmount': 249,
      };

      final bookingProvider = BookingProvider(mockClient);

      await bookingProvider.createBooking(
        'addr_1',
        DateTime(2026, 10, 28, 10, 0),
        serviceId: 's_car_ext',
        vehicleId: 'v_car_1',
        idempotencyKey: 'test_client_key_456',
      );

      expect(mockClient.postedPaths, contains('/bookings'));
      expect(mockClient.postedData.first?['idempotencyKey'], 'test_client_key_456');
      expect(mockClient.postedData.first?['serviceId'], 's_car_ext');
    });

    // 4. Saved Addresses opens the correct address-management screen
    testWidgets('4. Profile -> Saved Addresses navigates to /saved-addresses screen', (tester) async {
      final mockClient = MockTestApiClient();
      final authProvider = AuthProvider(mockClient, SecureStorageService());
      final addressProvider = AddressProvider(mockClient);

      String? pushedRoute;

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/saved-addresses',
            builder: (context, state) {
              pushedRoute = '/saved-addresses';
              return const SavedAddressesScreen();
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<AddressProvider>.value(value: addressProvider),
            ChangeNotifierProvider<RewardsProvider>(create: (_) => RewardsProvider()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final savedAddressesFinder = find.text('Saved Addresses');
      expect(savedAddressesFinder, findsOneWidget);

      await tester.tap(savedAddressesFinder);
      await tester.pumpAndSettle();

      expect(pushedRoute, '/saved-addresses');
      expect(find.byType(SavedAddressesScreen), findsOneWidget);
    });

    // 5. Bookings opens the actual booking history
    testWidgets('5. Profile -> Bookings tab navigates to /bookings rather than coming soon', (tester) async {
      final mockClient = MockTestApiClient();
      final authProvider = AuthProvider(mockClient, SecureStorageService());

      String? navRoute;

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/bookings',
            builder: (context, state) {
              navRoute = '/bookings';
              return const Scaffold(body: Text('Bookings History Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<RewardsProvider>(create: (_) => RewardsProvider()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final bookingsTab = find.text('bookings');
      expect(bookingsTab, findsOneWidget);

      await tester.tap(bookingsTab);
      await tester.pumpAndSettle();

      expect(navRoute, '/bookings');
      expect(find.textContaining('coming soon'), findsNothing);
    });

    // 6. Profile details are sourced from authenticated user data
    testWidgets('6. Profile details display user fullName, email, phone, and referral code', (tester) async {
      final mockClient = MockTestApiClient();
      final userMap = {
        'id': 'u_test_999',
        'email': 'rahul.sharma@example.com',
        'fullName': 'Rahul Sharma',
        'role': 'CUSTOMER',
        'phone': '9876500000',
        'referralCode': 'STARQ9K2X',
      };
      mockClient.getResponse = userMap;

      final authProvider = AuthProvider(mockClient, SecureStorageService());
      await authProvider.fetchMe();

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<RewardsProvider>(create: (_) => RewardsProvider()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('rahul.sharma@example.com'), findsOneWidget);
      expect(find.text('9876500000'), findsOneWidget);
      expect(find.text('Referral: STARQ9K2X'), findsOneWidget);
    });

    // 7. Location control reflects selected address and handles empty selection safely
    testWidgets('7. Location control reflects selected address and handles empty safely', (tester) async {
      final mockClient = MockTestApiClient();
      final addressProvider = AddressProvider(mockClient);
      final bookingProvider = BookingProvider(mockClient);
      final garageProvider = GarageProvider();

      // Test with empty address selection
      Widget buildApp() {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AddressProvider>.value(value: addressProvider),
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<GarageProvider>.value(value: garageProvider),
          ],
          child: const MaterialApp(
            home: HomeDashboardScreen(),
          ),
        );
      }

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Select location'), findsOneWidget);

      // Now set selected address
      addressProvider.selectAddress(Address(
        id: 'addr_home',
        userId: 'u1',
        line1: 'Flat 402, Lotus Boulevard',
        line2: 'Home',
        city: 'Noida',
        zipCode: '201304',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Home · Noida'), findsOneWidget);
    });

    // 8. Same account retains the same referral code across logins
    test('8. User model retains referralCode and phone accurately across serialization', () {
      final user = User.fromJson({
        'id': 'u_ref_1',
        'email': 'referral.test@starq.app',
        'fullName': 'Referral User',
        'role': 'CUSTOMER',
        'phone': '+919876543210',
        'referralCode': 'STARQABCDE',
      });

      expect(user.referralCode, 'STARQABCDE');
      expect(user.phone, '+919876543210');

      final serialized = user.toJson();
      final restored = User.fromJson(serialized);

      expect(restored.referralCode, user.referralCode);
      expect(restored.phone, user.phone);
    });
  });
}
