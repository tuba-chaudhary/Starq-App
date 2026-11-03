import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';
import 'package:starq_app/features/vehicles/data/vehicle_repository.dart';
import 'package:starq_app/features/vehicles/domain/vehicle.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/services/service_selection_screen.dart';
import 'package:starq_app/features/services/domain/service_package.dart';
import 'package:starq_app/features/services/interior_wash_screen.dart';

class MockFlowApiClient implements ApiClient {
  dynamic mockGetResponse = [];
  Map<String, dynamic> mockPostResponse = {};
  String? lastGetPath;
  Map<String, dynamic>? lastGetParams;

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
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockPostResponse as T,
      statusCode: 200,
    );
  }
}

final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  });

  group('STARQ — Authoritative Catalog & Choose a Service Tests', () {
    late MockFlowApiClient mockApi;
    late BookingProvider bookingProvider;
    late GarageProvider garageProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService().init();

      mockApi = MockFlowApiClient();
      bookingProvider = BookingProvider(mockApi);
      garageProvider = GarageProvider(VehicleRepository(mockApi));
    });

    test('1. Exact Authoritative Catalog Prices & Packages across all categories', () {
      // Hatchback: 399, 699, 1099, 2699
      final hbPkgs = getPackagesForCategory(VehicleCategory.hatchback);
      expect(hbPkgs.length, 4);
      expect(hbPkgs.firstWhere((p) => p.tier == PackageTier.silver).getPrice(VehicleCategory.hatchback), 399);
      expect(hbPkgs.firstWhere((p) => p.tier == PackageTier.gold).getPrice(VehicleCategory.hatchback), 699);
      expect(hbPkgs.firstWhere((p) => p.tier == PackageTier.diamond).getPrice(VehicleCategory.hatchback), 1099);
      expect(hbPkgs.firstWhere((p) => p.tier == PackageTier.platinum).getPrice(VehicleCategory.hatchback), 2699);

      // Sedan: 599, 799, 1199, 3099
      final sedanPkgs = getPackagesForCategory(VehicleCategory.sedan);
      expect(sedanPkgs.firstWhere((p) => p.tier == PackageTier.silver).getPrice(VehicleCategory.sedan), 599);
      expect(sedanPkgs.firstWhere((p) => p.tier == PackageTier.gold).getPrice(VehicleCategory.sedan), 799);
      expect(sedanPkgs.firstWhere((p) => p.tier == PackageTier.diamond).getPrice(VehicleCategory.sedan), 1199);
      expect(sedanPkgs.firstWhere((p) => p.tier == PackageTier.platinum).getPrice(VehicleCategory.sedan), 3099);

      // MUV: 699, 899, 1399, 3399
      final muvPkgs = getPackagesForCategory(VehicleCategory.muv);
      expect(muvPkgs.firstWhere((p) => p.tier == PackageTier.silver).getPrice(VehicleCategory.muv), 699);
      expect(muvPkgs.firstWhere((p) => p.tier == PackageTier.gold).getPrice(VehicleCategory.muv), 899);
      expect(muvPkgs.firstWhere((p) => p.tier == PackageTier.diamond).getPrice(VehicleCategory.muv), 1399);
      expect(muvPkgs.firstWhere((p) => p.tier == PackageTier.platinum).getPrice(VehicleCategory.muv), 3399);

      // SUV: 799, 999, 1499, 3599
      final suvPkgs = getPackagesForCategory(VehicleCategory.suv);
      expect(suvPkgs.firstWhere((p) => p.tier == PackageTier.silver).getPrice(VehicleCategory.suv), 799);
      expect(suvPkgs.firstWhere((p) => p.tier == PackageTier.gold).getPrice(VehicleCategory.suv), 999);
      expect(suvPkgs.firstWhere((p) => p.tier == PackageTier.diamond).getPrice(VehicleCategory.suv), 1499);
      expect(suvPkgs.firstWhere((p) => p.tier == PackageTier.platinum).getPrice(VehicleCategory.suv), 3599);

      // Luxury: Gold 1899, Diamond 2599, Platinum 5099, NO Silver
      final luxPkgs = getPackagesForCategory(VehicleCategory.luxury);
      expect(luxPkgs.length, 3);
      expect(luxPkgs.where((p) => p.tier == PackageTier.silver), isEmpty);
      expect(luxPkgs.firstWhere((p) => p.tier == PackageTier.gold).getPrice(VehicleCategory.luxury), 1899);
      expect(luxPkgs.firstWhere((p) => p.tier == PackageTier.diamond).getPrice(VehicleCategory.luxury), 2599);
      expect(luxPkgs.firstWhere((p) => p.tier == PackageTier.platinum).getPrice(VehicleCategory.luxury), 5099);

      // Bike: Bucket Wash 299, Pressure Wash 399
      expect(kBikeServicePackages.length, 2);
      expect(kBikeServicePackages[0].title, 'Bucket Wash');
      expect(kBikeServicePackages[0].price, 299);
      expect(kBikeServicePackages[0].duration, '20 min');
      expect(kBikeServicePackages[1].title, 'Pressure Wash');
      expect(kBikeServicePackages[1].price, 399);
      expect(kBikeServicePackages[1].duration, '30 min');
    });

    test('2. Inclusions inheritance: Gold inherits Silver, Diamond inherits Gold', () {
      final silver = kAllServicePackages.firstWhere((p) => p.tier == PackageTier.silver);
      final gold = kAllServicePackages.firstWhere((p) => p.tier == PackageTier.gold);
      final diamond = kAllServicePackages.firstWhere((p) => p.tier == PackageTier.diamond);
      final platinum = kAllServicePackages.firstWhere((p) => p.tier == PackageTier.platinum);

      final silverItems = silver.getAllInclusions(VehicleCategory.hatchback);
      expect(silverItems, contains('Exterior foam wash'));
      expect(silverItems, contains('Mirror & glass cleaning (exterior only)'));

      final goldItems = gold.getAllInclusions(VehicleCategory.hatchback);
      for (final sItem in silverItems) {
        expect(goldItems, contains(sItem), reason: 'Gold must inherit Silver item: $sItem');
      }
      expect(goldItems, contains('Interior vacuum (seats, mats & boot)'));
      expect(goldItems, contains('Scented air freshener spray'));

      final diamondItems = diamond.getAllInclusions(VehicleCategory.hatchback);
      for (final gItem in goldItems) {
        expect(diamondItems, contains(gItem), reason: 'Diamond must inherit Gold item: $gItem');
      }
      expect(diamondItems, contains('Underbody wash'));
      expect(diamondItems, contains('Tyre polish & shine'));
      expect(diamondItems, contains('Special care for every corner and final detail'));

      final platItems = platinum.getAllInclusions(VehicleCategory.hatchback);
      expect(platItems.length, 14);
      expect(platItems, contains('Seats Shampooing & Vacuuming'));
      expect(platItems, contains('Final Dry & Shine Finish'));
    });

    testWidgets('3. ServiceSelectionScreen displays saved Bike without defaulting to Car', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // User has a saved Royal Enfield Bike
      mockApi.mockGetResponse = [
        {
          'id': 'bike-v-1',
          'userId': 'u1',
          'category': 'bike',
          'brand': 'Royal Enfield',
          'model': 'Classic 350',
          'registrationNumber': 'KA 05 MN 9999',
          'isPrimary': true,
        }
      ];
      await garageProvider.load();

      final router = GoRouter(
        initialLocation: '/service-selection',
        routes: [
          GoRoute(
            path: '/service-selection',
            builder: (context, state) => ServiceSelectionScreen(
              data: state.extra as Map<String, dynamic>?,
            ),
          ),
          GoRoute(path: '/bucket-wash', builder: (context, state) => const Scaffold(body: Text('Bucket Wash Screen'))),
          GoRoute(path: '/pressure-wash', builder: (context, state) => const Scaffold(body: Text('Pressure Wash Screen'))),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<GarageProvider>.value(value: garageProvider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header shows real vehicle, not fake plate
      expect(find.textContaining('KA 05 MN 9999'), findsOneWidget);
      expect(find.textContaining('Royal Enfield Classic 350'), findsOneWidget);
      expect(find.textContaining('KA 01 AB 1234'), findsNothing);
      expect(find.textContaining('Honda City'), findsNothing);

      // Shows Bike Services, not Car packages
      expect(find.text('Bucket Wash'), findsOneWidget);
      expect(find.text('Pressure Wash'), findsOneWidget);
      expect(find.text('₹299'), findsOneWidget);
      expect(find.text('₹399'), findsOneWidget);
      expect(find.text('Silver — Basic Wash'), findsNothing);
    });

    testWidgets('4. ServiceSelectionScreen displays saved SUV with SUV pricing, not Hatchback', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // User has a saved Mahindra XUV700 (SUV)
      mockApi.mockGetResponse = [
        {
          'id': 'suv-v-1',
          'userId': 'u1',
          'category': 'suv',
          'brand': 'Mahindra',
          'model': 'XUV700',
          'registrationNumber': 'MH 12 XY 4321',
          'isPrimary': true,
        }
      ];
      await garageProvider.load();

      final router = GoRouter(
        initialLocation: '/service-selection',
        routes: [
          GoRoute(
            path: '/service-selection',
            builder: (context, state) => ServiceSelectionScreen(
              data: state.extra as Map<String, dynamic>?,
            ),
          ),
          GoRoute(path: '/exterior-wash', builder: (context, state) => const Scaffold(body: Text('Exterior Wash Screen'))),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<GarageProvider>.value(value: garageProvider),
            ChangeNotifierProvider<BookingFlowProvider>(create: (_) => BookingFlowProvider()),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header shows Mahindra XUV700
      expect(find.textContaining('MH 12 XY 4321'), findsOneWidget);
      expect(find.textContaining('Mahindra XUV700'), findsOneWidget);

      // SUV Prices: Silver ₹799, Gold ₹999, Diamond ₹1,499, Platinum ₹3,599
      expect(find.text('Silver — Basic Wash'), findsOneWidget);
      expect(find.text('₹799'), findsOneWidget);
      expect(find.text('Gold — Deluxe Wash'), findsOneWidget);
      expect(find.text('₹999'), findsOneWidget);
      expect(find.text('Diamond — Premium Wash'), findsOneWidget);
      expect(find.text('₹1,499'), findsOneWidget);
      expect(find.text('Platinum — Deep Cleaning (Interior + Exterior)'), findsOneWidget);
      expect(find.text('₹3,599'), findsOneWidget);

      // Must NOT display Hatchback prices
      expect(find.text('₹399'), findsNothing);
      expect(find.text('₹699'), findsNothing);
      expect(find.text('₹1,099'), findsNothing);
      expect(find.text('₹2,699'), findsNothing);
    });

    testWidgets('5. ServiceSelectionScreen displays honest loading and error states without flashing fake data', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      garageProvider.loading = true;
      garageProvider.vehicles = [];

      final router = GoRouter(
        initialLocation: '/service-selection',
        routes: [
          GoRoute(
            path: '/service-selection',
            builder: (context, state) => ServiceSelectionScreen(
              data: state.extra as Map<String, dynamic>?,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<GarageProvider>.value(value: garageProvider),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      // Honest loader shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Fetching your saved vehicles & catalog...'), findsOneWidget);
      expect(find.text('Honda City'), findsNothing);
      expect(find.text('KA 01 AB 1234'), findsNothing);

      // Now simulate network failure
      garageProvider.loading = false;
      garageProvider.error = 'Network connection failed';
      garageProvider.notifyListeners();
      await tester.pump();

      // Displays error and Retry button
      expect(find.text('Network connection failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('6. ServiceSelectionScreen with no saved vehicle displays category selector without fake license plate', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      mockApi.mockGetResponse = [];
      await garageProvider.load();

      final router = GoRouter(
        initialLocation: '/service-selection',
        routes: [
          GoRoute(
            path: '/service-selection',
            builder: (context, state) => ServiceSelectionScreen(
              data: state.extra as Map<String, dynamic>?,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<GarageProvider>.value(value: garageProvider),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shows no vehicle selected rather than fake plates
      expect(find.textContaining('No vehicle selected · Details required at checkout'), findsOneWidget);
      expect(find.textContaining('KA 01 AB 1234'), findsNothing);
      expect(find.textContaining('Honda City'), findsNothing);

      // Category chips exist
      expect(find.byKey(const Key('category_chip_hatchback')), findsOneWidget);
      expect(find.byKey(const Key('category_chip_sedan')), findsOneWidget);
      expect(find.byKey(const Key('category_chip_luxury')), findsOneWidget);

      // Tap Luxury category: Gold ₹1,899, Diamond ₹2,599, Platinum ₹5,099
      await tester.tap(find.byKey(const Key('category_chip_luxury')));
      await tester.pumpAndSettle();

      expect(find.text('Gold — Deluxe Wash'), findsOneWidget);
      expect(find.text('₹1,899'), findsOneWidget);
      expect(find.text('Diamond — Premium Wash'), findsOneWidget);
      expect(find.text('₹2,599'), findsOneWidget);
      expect(find.text('Platinum — Deep Cleaning (Interior + Exterior)'), findsOneWidget);
      expect(find.text('₹5,099'), findsOneWidget);

      // Silver must NOT be displayed under Luxury
      expect(find.text('Silver — Basic Wash'), findsNothing);
    });

    testWidgets('7. Navigation from ServiceSelectionScreen preserves full package data and inherited inclusions', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      mockApi.mockGetResponse = [
        {
          'id': 'v-sedan-1',
          'userId': 'u1',
          'category': 'sedan',
          'brand': 'Honda',
          'model': 'Amaze',
          'registrationNumber': 'DL 04 CD 5678',
          'isPrimary': true,
        }
      ];
      await garageProvider.load();

      Map<String, dynamic>? capturedExtra;

      final router = GoRouter(
        initialLocation: '/service-selection',
        routes: [
          GoRoute(
            path: '/service-selection',
            builder: (context, state) => ServiceSelectionScreen(
              data: state.extra as Map<String, dynamic>?,
            ),
          ),
          GoRoute(
            path: '/interior-wash',
            builder: (context, state) {
              capturedExtra = state.extra as Map<String, dynamic>?;
              return InteriorWashScreen(data: capturedExtra);
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
            ChangeNotifierProvider<GarageProvider>.value(value: garageProvider),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false, splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Gold — Deluxe Wash (Sedan price ₹799)
      await tester.tap(find.text('Gold — Deluxe Wash'));
      await tester.pumpAndSettle();

      // Verify captured data in detail screen
      expect(capturedExtra, isNotNull);
      expect(capturedExtra!['vehicleId'], 'v-sedan-1');
      expect(capturedExtra!['vehiclePlate'], 'DL 04 CD 5678');
      expect(capturedExtra!['vehicleCategory'], 'sedan');
      expect(capturedExtra!['servicePrice'], '₹799');
      expect(capturedExtra!['packageTier'], 'GOLD');

      // Verify detail screen displays package title, price, and both Silver + Gold inclusions
      expect(find.text('Gold — Deluxe Wash'), findsOneWidget);
      expect(find.text('₹799'), findsOneWidget);
      expect(find.text('Base Package (Silver Basic Wash)'), findsOneWidget);
      expect(find.text('Deluxe Wash Additions'), findsOneWidget);
      expect(find.text('Exterior foam wash'), findsOneWidget);
      expect(find.text('Interior vacuum (seats, mats & boot)'), findsOneWidget);
    });
  });
}
