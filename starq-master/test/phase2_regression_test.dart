import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/core/utils/validators.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/vehicles/add_vehicle_screen.dart';
import 'package:starq_app/features/vehicles/data/vehicle_repository.dart';
import 'package:starq_app/features/vehicles/domain/vehicle.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';
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

class MockVehicleApiClient implements ApiClient {
  Map<String, dynamic>? lastPostedData;
  String? lastPostedPath;
  Map<String, dynamic> mockCreateResponse = {};
  List<dynamic> mockListResponse = [];

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
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockCreateResponse as T,
      statusCode: 201,
    );
  }

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
      data: mockListResponse as T,
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
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
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

  group('Phase 2 - Registration Number Validator Tests', () {
    test('rejects empty or whitespace-only registration number', () {
      expect(AppValidators.registrationNumber(null), 'Registration number is required');
      expect(AppValidators.registrationNumber(''), 'Registration number is required');
      expect(AppValidators.registrationNumber('   '), 'Registration number is required');
    });

    test('rejects plates with invalid length', () {
      expect(AppValidators.registrationNumber('KA1'), 'Please enter a valid vehicle plate (e.g. DL 01 AB 1234)');
      expect(AppValidators.registrationNumber('DL01AB1234567890'), 'Please enter a valid vehicle plate (e.g. DL 01 AB 1234)');
    });

    test('rejects plates with non-alphanumeric characters', () {
      expect(AppValidators.registrationNumber('DL@01#1234'), 'Registration number should only contain letters and numbers');
    });

    test('accepts valid plate formats with or without spaces/dashes', () {
      expect(AppValidators.registrationNumber('DL 01 AB 1234'), isNull);
      expect(AppValidators.registrationNumber('KA05M1234'), isNull);
      expect(AppValidators.registrationNumber('UP-16-XX-1234'), isNull);
      expect(AppValidators.registrationNumber('22BH1234AA'), isNull);
    });
  });

  group('Phase 2 - GarageProvider State & Persistence Tests', () {
    late MockVehicleApiClient mockApi;
    late VehicleRepository repository;
    late GarageProvider garage;

    setUp(() {
      mockApi = MockVehicleApiClient();
      repository = VehicleRepository(mockApi);
      garage = GarageProvider(repository);
    });

    test('add vehicle saves to state, updates selected, and does not inject UP 16 XX 0000', () async {
      mockApi.mockCreateResponse = {
        'id': 'v-new-1',
        'userId': 'usr-1',
        'make': 'Hyundai',
        'model': 'Creta',
        'category': 'SUV',
        'licensePlate': 'DL 03 XY 9999',
      };

      final success = await garage.add({
        'category': 'suv',
        'make': 'Hyundai',
        'brand': 'Hyundai',
        'model': 'Creta',
        'registration_number': 'DL 03 XY 9999',
        'licensePlate': 'DL 03 XY 9999',
      });

      expect(success, isTrue);
      expect(garage.vehicles.length, 1);
      expect(garage.selected, isNotNull);
      expect(garage.selected!.registrationNumber, 'DL 03 XY 9999');
      expect(garage.selected!.registrationNumber, isNot('UP 16 XX 0000'));
      expect(mockApi.lastPostedData?['licensePlate'], 'DL 03 XY 9999');
    });

    test('select vehicle updates selected state and persists', () async {
      final v1 = Vehicle(
        id: 'v1',
        userId: 'u1',
        category: VehicleCategory.sedan,
        brand: 'Honda',
        model: 'City',
        registrationNumber: 'KA 01 AB 1111',
      );
      final v2 = Vehicle(
        id: 'v2',
        userId: 'u1',
        category: VehicleCategory.suv,
        brand: 'Tata',
        model: 'Nexon',
        registrationNumber: 'MH 12 CD 2222',
      );

      garage.vehicles = [v1, v2];
      await garage.select(v2);

      expect(garage.selected?.id, 'v2');
      expect(garage.selected?.brand, 'Tata');
      expect(garage.selected?.registrationNumber, 'MH 12 CD 2222');
    });

    test('remove active vehicle falls back to remaining vehicle', () async {
      final v1 = Vehicle(
        id: 'v1',
        userId: 'u1',
        category: VehicleCategory.sedan,
        brand: 'Honda',
        model: 'City',
        registrationNumber: 'KA 01 AB 1111',
      );
      final v2 = Vehicle(
        id: 'v2',
        userId: 'u1',
        category: VehicleCategory.bike,
        brand: 'Royal Enfield',
        model: 'Classic',
        registrationNumber: 'DL 02 EF 3333',
      );

      garage.vehicles = [v1, v2];
      garage.selected = v1;

      final success = await garage.remove('v1');
      expect(success, isTrue);
      expect(garage.vehicles.length, 1);
      expect(garage.selected?.id, 'v2');
      expect(garage.selected?.registrationNumber, 'DL 02 EF 3333');
    });
  });

  group('Phase 2 - AddVehicleScreen Validation UI Tests', () {
    late MockVehicleApiClient mockApi;
    late GarageProvider garage;
    late BookingFlowProvider bookingFlow;

    setUp(() {
      mockApi = MockVehicleApiClient();
      garage = GarageProvider(VehicleRepository(mockApi));
      bookingFlow = BookingFlowProvider();
    });

    testWidgets('submitting empty registration plate shows validation error and does not save', (tester) async {
      final router = GoRouter(
        initialLocation: '/add-vehicle',
        routes: [
          GoRoute(path: '/add-vehicle', builder: (context, state) => const AddVehicleScreen()),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GarageProvider>.value(value: garage),
            ChangeNotifierProvider<BookingFlowProvider>.value(value: bookingFlow),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Honda');
      await tester.enterText(textFields.at(1), 'City');
      // Leave plate (textFields.at(3)) empty

      await tester.tap(find.text('Save vehicle'));
      await tester.pumpAndSettle();

      // Error snackbar shown
      expect(find.text('Registration number is required'), findsOneWidget);
      // API was NOT called with default placeholder
      expect(mockApi.lastPostedData, isNull);
    });

    testWidgets('submitting valid registration number sends clean uppercase plate without UP 16 XX 0000', (tester) async {
      mockApi.mockCreateResponse = {
        'id': 'v-honda-1',
        'userId': 'usr-1',
        'make': 'Honda',
        'model': 'City',
        'category': 'SEDAN',
        'licensePlate': 'DL 01 AB 1234',
      };

      final router = GoRouter(
        initialLocation: '/garage',
        routes: [
          GoRoute(
            path: '/garage',
            builder: (context, state) => const Scaffold(body: Text('Garage Root Screen')),
          ),
          GoRoute(
            path: '/add-vehicle',
            builder: (context, state) => const AddVehicleScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GarageProvider>.value(value: garage),
            ChangeNotifierProvider<BookingFlowProvider>.value(value: bookingFlow),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );

      router.push('/add-vehicle');
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Honda');
      await tester.enterText(textFields.at(1), 'City');
      await tester.enterText(textFields.at(3), 'dl 01 ab 1234'); // plate field

      await tester.tap(find.text('Save vehicle'));
      await tester.pumpAndSettle();

      expect(mockApi.lastPostedData, isNotNull);
      expect(mockApi.lastPostedData?['licensePlate'], 'DL 01 AB 1234');
      expect(mockApi.lastPostedData?['registration_number'], 'DL 01 AB 1234');
      expect(mockApi.lastPostedData?['licensePlate'], isNot('UP 16 XX 0000'));
      expect(find.text('Garage Root Screen'), findsOneWidget);
    });
  });
}
