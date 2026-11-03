import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/features/vehicles/data/vehicle_repository.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/features/booking/booking_summary_screen.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/services/exterior_wash_screen.dart';
import 'package:starq_app/features/services/interior_wash_screen.dart';
import 'package:starq_app/features/home/home_dashboard_screen.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';
import 'package:starq_app/features/providers/vehicle_provider.dart';
import 'package:starq_app/features/vehicles/domain/vehicle.dart';
import 'package:starq_app/features/services/domain/service_package.dart';
import 'package:starq_app/core/widgets/service_detail_template.dart';
import 'package:dio/dio.dart';

final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class MockDynamicCatalogApiClient implements ApiClient {
  Map<String, dynamic>? lastPostedData;
  String? lastPostedPath;
  String? lastGetPath;
  Map<String, dynamic>? lastGetParams;
  dynamic mockGetResponse = [];
  Map<String, dynamic> mockPostResponse = {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastGetPath = path;
    lastGetParams = queryParameters;
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
    if (data is Map<String, dynamic>) {
      lastPostedData = data;
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockPostResponse as T,
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> put<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) async => throw UnimplementedError();
  @override
  Future<Response<T>> patch<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) async => throw UnimplementedError();
  @override
  Future<Response<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) async => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(mergeWith: {'API_BASE_URL': 'http://localhost:3000/api/v1'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'AssetManifest.bin') {
          final ByteData data = const StandardMessageCodec().encodeMessage(<String, dynamic>{})!;
          return data.buffer.asByteData();
        }
        if (key == 'AssetManifest.json') {
          final encoded = utf8.encode('{}');
          return ByteData.view(Uint8List.fromList(encoded).buffer);
        }
        return ByteData.view(kTransparentImage.buffer);
      },
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  group('STARQ Dynamic Vehicle-Based Service Catalog Domain Tests', () {
    test('1. All 5 vehicle categories have exact package price specifications', () {
      final hatchbackPackages = getPackagesForCategory(VehicleCategory.hatchback);
      expect(hatchbackPackages.length, equals(4));
      expect(hatchbackPackages.firstWhere((p) => p.tier == PackageTier.silver).getPrice(VehicleCategory.hatchback), equals(399));
      expect(hatchbackPackages.firstWhere((p) => p.tier == PackageTier.gold).getPrice(VehicleCategory.hatchback), equals(699));
      expect(hatchbackPackages.firstWhere((p) => p.tier == PackageTier.diamond).getPrice(VehicleCategory.hatchback), equals(1099));
      expect(hatchbackPackages.firstWhere((p) => p.tier == PackageTier.platinum).getPrice(VehicleCategory.hatchback), equals(2699));

      final sedanPackages = getPackagesForCategory(VehicleCategory.sedan);
      expect(sedanPackages.length, equals(4));
      expect(sedanPackages.firstWhere((p) => p.tier == PackageTier.silver).getPrice(VehicleCategory.sedan), equals(599));
      expect(sedanPackages.firstWhere((p) => p.tier == PackageTier.gold).getPrice(VehicleCategory.sedan), equals(799));
      expect(sedanPackages.firstWhere((p) => p.tier == PackageTier.diamond).getPrice(VehicleCategory.sedan), equals(1199));
      expect(sedanPackages.firstWhere((p) => p.tier == PackageTier.platinum).getPrice(VehicleCategory.sedan), equals(3099));

      final muvPackages = getPackagesForCategory(VehicleCategory.muv);
      expect(muvPackages.length, equals(4));
      expect(muvPackages.firstWhere((p) => p.tier == PackageTier.silver).getPrice(VehicleCategory.muv), equals(699));
      expect(muvPackages.firstWhere((p) => p.tier == PackageTier.gold).getPrice(VehicleCategory.muv), equals(899));
      expect(muvPackages.firstWhere((p) => p.tier == PackageTier.diamond).getPrice(VehicleCategory.muv), equals(1399));
      expect(muvPackages.firstWhere((p) => p.tier == PackageTier.platinum).getPrice(VehicleCategory.muv), equals(3399));

      final suvPackages = getPackagesForCategory(VehicleCategory.suv);
      expect(suvPackages.length, equals(4));
      expect(suvPackages.firstWhere((p) => p.tier == PackageTier.silver).getPrice(VehicleCategory.suv), equals(799));
      expect(suvPackages.firstWhere((p) => p.tier == PackageTier.gold).getPrice(VehicleCategory.suv), equals(999));
      expect(suvPackages.firstWhere((p) => p.tier == PackageTier.diamond).getPrice(VehicleCategory.suv), equals(1499));
      expect(suvPackages.firstWhere((p) => p.tier == PackageTier.platinum).getPrice(VehicleCategory.suv), equals(3599));

      final luxuryPackages = getPackagesForCategory(VehicleCategory.luxury);
      expect(luxuryPackages.length, equals(3), reason: 'Luxury category must strictly have 3 packages (Silver omitted)');
      expect(luxuryPackages.any((p) => p.tier == PackageTier.silver), isFalse, reason: 'Silver package must not exist for Luxury');
      expect(luxuryPackages.firstWhere((p) => p.tier == PackageTier.gold).getPrice(VehicleCategory.luxury), equals(1899));
      expect(luxuryPackages.firstWhere((p) => p.tier == PackageTier.diamond).getPrice(VehicleCategory.luxury), equals(2599));
      expect(luxuryPackages.firstWhere((p) => p.tier == PackageTier.platinum).getPrice(VehicleCategory.luxury), equals(5099));
    });

    test('2. Included services preserve inheritance and display complete inclusions', () {
      final silver = kAllServicePackages.firstWhere((p) => p.tier == PackageTier.silver);
      final gold = kAllServicePackages.firstWhere((p) => p.tier == PackageTier.gold);
      final diamond = kAllServicePackages.firstWhere((p) => p.tier == PackageTier.diamond);
      final platinum = kAllServicePackages.firstWhere((p) => p.tier == PackageTier.platinum);

      final silverInclusions = silver.getInclusions(VehicleCategory.hatchback);
      expect(silverInclusions.containsKey('Silver — Basic Wash Inclusions'), isTrue);
      expect(silverInclusions['Silver — Basic Wash Inclusions']!.contains('Exterior foam wash'), isTrue);
      expect(silverInclusions['Silver — Basic Wash Inclusions']!.contains('Pressure rinse'), isTrue);

      final goldInclusions = gold.getInclusions(VehicleCategory.hatchback);
      expect(goldInclusions.containsKey('Base Package (Silver Basic Wash)'), isTrue);
      expect(goldInclusions.containsKey('Deluxe Wash Additions'), isTrue);
      expect(goldInclusions['Base Package (Silver Basic Wash)']!.contains('Exterior foam wash'), isTrue);
      expect(goldInclusions['Deluxe Wash Additions']!.contains('Interior vacuum (seats, mats & boot)'), isTrue);

      final diamondInclusions = diamond.getInclusions(VehicleCategory.hatchback);
      expect(diamondInclusions.containsKey('Base Package (Gold Deluxe Wash)'), isTrue);
      expect(diamondInclusions.containsKey('Premium Wash Additions'), isTrue);
      expect(diamondInclusions['Premium Wash Additions']!.contains('Underbody wash'), isTrue);

      final platinumInclusions = platinum.getInclusions(VehicleCategory.hatchback);
      expect(platinumInclusions.containsKey('Platinum Deep Cleaning (Interior + Exterior)'), isTrue);
      expect(platinumInclusions['Platinum Deep Cleaning (Interior + Exterior)']!.contains('Seats Shampooing & Vacuuming'), isTrue);
      expect(platinumInclusions['Platinum Deep Cleaning (Interior + Exterior)']!.contains('Silver Trims & Engine Grille Polished'), isTrue);
    });

    test('3. Luxury category displays dedicated luxury paint-safe inclusions', () {
      final luxuryGold = kAllServicePackages.firstWhere((p) => p.tier == PackageTier.gold);
      final luxuryDiamond = kAllServicePackages.firstWhere((p) => p.tier == PackageTier.diamond);

      final goldInclusions = luxuryGold.getInclusions(VehicleCategory.luxury);
      expect(goldInclusions.values.expand((x) => x).contains('Safe care for ceramic, PPF and matte finishes'), isTrue);
      expect(goldInclusions.values.expand((x) => x).contains('Soft-touch foam wash with luxury paint-safe shampoo'), isTrue);

      final diamondInclusions = luxuryDiamond.getInclusions(VehicleCategory.luxury);
      expect(diamondInclusions.values.expand((x) => x).contains('Light scratch reduction and exterior gloss restoration'), isTrue);
    });
  });

  group('STARQ Dynamic Vehicle-Based UI Regression Tests', () {
    late MockDynamicCatalogApiClient mockApi;
    late BookingProvider bookingProvider;
    late GarageProvider garageProvider;
    late VehicleProvider vehicleProvider;

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

      mockApi = MockDynamicCatalogApiClient();
      bookingProvider = BookingProvider(mockApi);
      garageProvider = GarageProvider(VehicleRepository(mockApi));
      vehicleProvider = VehicleProvider(mockApi);
    });

    testWidgets('4. User with no saved vehicle shows vehicle category selector and switches categories', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeDashboardScreen()),
          GoRoute(path: '/exterior-wash', builder: (context, state) => const ExteriorWashScreen()),
          GoRoute(path: '/interior-wash', builder: (context, state) => const InteriorWashScreen()),
          GoRoute(path: '/service-selection', builder: (context, state) => const Scaffold(body: Text('Service Selection'))),
          GoRoute(path: '/booking-details', builder: (context, state) => const Scaffold(body: Text('Booking Details'))),
          GoRoute(path: '/my-garage', builder: (context, state) => const Scaffold(body: Text('My Garage'))),
          GoRoute(path: '/add-vehicle', builder: (context, state) => const Scaffold(body: Text('Add Vehicle'))),
          GoRoute(path: '/saved-addresses', builder: (context, state) => const Scaffold(body: Text('Saved Addresses'))),
          GoRoute(path: '/profile', builder: (context, state) => const Scaffold(body: Text('Profile'))),
        ],
      );

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

      // Verify all 5 category cards exist on Home Dashboard
      expect(find.byKey(const Key('category_card_hatchback')), findsOneWidget);
      expect(find.byKey(const Key('category_card_sedan')), findsOneWidget);
      expect(find.byKey(const Key('category_card_muv')), findsOneWidget);
      expect(find.byKey(const Key('category_card_suv')), findsOneWidget);
      expect(find.byKey(const Key('category_card_luxury')), findsOneWidget);

      // Default is Hatchback: Silver ₹399
      expect(find.textContaining('₹399'), findsWidgets);

      // Tap Sedan category
      await tester.tap(find.byKey(const Key('category_card_sedan')));
      await tester.pumpAndSettle();

      // Sedan prices: Silver ₹599, Gold ₹799, Diamond ₹1,199, Platinum ₹3,099
      expect(find.textContaining('₹599'), findsWidgets);
      expect(find.textContaining('₹799'), findsWidgets);
      expect(find.textContaining('₹1,199'), findsWidgets);
      expect(find.textContaining('₹3,099'), findsWidgets);

      // Tap Luxury category
      await tester.tap(find.byKey(const Key('category_card_luxury')));
      await tester.pumpAndSettle();

      // Luxury prices: Gold ₹1,899, Diamond ₹2,599, Platinum ₹5,099
      expect(find.textContaining('₹1,899'), findsWidgets);
      expect(find.textContaining('₹2,599'), findsWidgets);
      expect(find.textContaining('₹5,099'), findsWidgets);

      // Verify Silver is NOT present under Luxury
      expect(find.byKey(const Key('service_tile_silver')), findsNothing);
      expect(find.byKey(const Key('service_tile_exterior_wash')), findsNothing);
    });

    testWidgets('5. User with saved vehicle auto-selects vehicle category', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Configure mock API to return saved SUV vehicle
      mockApi.mockGetResponse = [
        {
          'id': 'v-suv-1',
          'userId': 'u1',
          'category': 'suv',
          'brand': 'Hyundai',
          'model': 'Creta',
          'registrationNumber': 'DL 01 AB 1234',
          'isPrimary': true,
        }
      ];

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeDashboardScreen()),
          GoRoute(path: '/my-garage', builder: (context, state) => const Scaffold(body: Text('My Garage'))),
          GoRoute(path: '/profile', builder: (context, state) => const Scaffold(body: Text('Profile'))),
          GoRoute(path: '/saved-addresses', builder: (context, state) => const Scaffold(body: Text('Saved Addresses'))),
        ],
      );

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

      // SUV vehicle is displayed
      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.textContaining('SUV'), findsWidgets);

      // SUV prices: Silver ₹799, Gold ₹999, Diamond ₹1,499, Platinum ₹3,599
      expect(find.textContaining('₹799'), findsWidgets);
      expect(find.textContaining('₹999'), findsWidgets);
      expect(find.textContaining('₹1,499'), findsWidgets);
      expect(find.textContaining('₹3,599'), findsWidgets);
    });

    testWidgets('6. ServiceDetailTemplate rejects Silver package for Luxury category', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/exterior-wash',
        routes: [
          GoRoute(
            path: '/exterior-wash',
            builder: (context, state) => const ServiceDetailTemplate(
              title: 'Silver — Basic Wash',
              price: '₹399',
              image: 'exterior_wash.png',
              duration: '45 mins',
              rating: '4.8',
              description: 'Exterior wash',
              included: {'Included Services': ['Foam wash']},
              extraData: {
                'vehicleCategory': 'luxury',
                'serviceCategory': 'CAR',
                'serviceTitle': 'Silver — Basic Wash',
                'serviceId': 'a0000001-0000-4000-8000-000000000001',
              },
            ),
          ),
          GoRoute(path: '/select-date-time', builder: (context, state) => const Scaffold(body: Text('Select Date Time'))),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<GarageProvider>.value(value: garageProvider),
            ChangeNotifierProvider<VehicleProvider>.value(value: vehicleProvider),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Book This Service
      await tester.tap(find.text('Book This Service'));
      await tester.pumpAndSettle();

      // Verify rejected and error SnackBar displayed
      expect(find.textContaining('Silver package is not available for Luxury vehicles'), findsOneWidget);
      expect(find.text('Select Date Time'), findsNothing);
    });

    testWidgets('7. BookingSummaryScreen requires vehicle details when vId is null without creating fake vehicles', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/booking-summary',
        routes: [
          GoRoute(
            path: '/booking-summary',
            builder: (context, state) => const BookingSummaryScreen(
              data: {
                'vehicleId': null,
                'vehicleCategory': 'sedan',
                'serviceId': 'a0000001-0000-4000-8000-000000000001',
                'serviceTitle': 'Silver — Basic Wash',
                'servicePrice': '₹599',
                'addressId': 'addr-1',
              },
            ),
          ),
          GoRoute(path: '/add-vehicle', builder: (context, state) => const Scaffold(body: Text('Add Vehicle Screen'))),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<GarageProvider>.value(value: garageProvider),
            ChangeNotifierProvider<VehicleProvider>.value(value: vehicleProvider),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Vehicle row shows Details required rather than a fake license plate
      expect(find.text('SEDAN · Details required'), findsOneWidget);

      // Tap Continue to Payment
      await tester.tap(find.text('Continue to Payment'));
      await tester.pumpAndSettle();

      // Prompts user to add vehicle details and navigates to /add-vehicle
      expect(find.text('Add Vehicle Screen'), findsOneWidget);
    });
  });
}
