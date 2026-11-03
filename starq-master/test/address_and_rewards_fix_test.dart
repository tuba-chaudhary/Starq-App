import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/core/widgets/starq_logo.dart';
import 'package:starq_app/features/providers/address_provider.dart';
import 'package:starq_app/features/addresses/saved_addresses_screen.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/points/rewards_screen.dart';
import 'package:starq_app/features/points/points_repository.dart';
import 'package:starq_app/features/providers/rewards_provider.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/providers/vehicle_provider.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';
import 'package:starq_app/features/home/home_dashboard_screen.dart';

final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class MockTestApiClient implements ApiClient {
  dynamic mockGetResponse;
  dynamic mockPostResponse;
  dynamic mockDeleteResponse;
  bool shouldFailGet = false;
  String? getErrorMessage;

  int getCalls = 0;
  int postCalls = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    getCalls++;
    if (shouldFailGet) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        error: getErrorMessage ?? 'Network error fetching data',
        type: DioExceptionType.connectionError,
      );
    }
    return Response<T>(
      data: (mockGetResponse ?? []) as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
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
    postCalls++;
    return Response<T>(
      data: mockPostResponse as T,
      statusCode: 201,
      requestOptions: RequestOptions(path: path),
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
      data: (mockDeleteResponse ?? {'status': 'deleted'}) as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  dynamic mockPatchResponse;
  int patchCalls = 0;

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    patchCalls++;
    return Response<T>(
      data: (mockPatchResponse ?? data) as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubTestPointsRepo implements PointsRepository {
  @override
  Future<PointsSummary> getSummary() async => const PointsSummary(balance: 150);

  @override
  Future<List<PointsEntry>> getHistory({int limit = 50}) async => [];

  @override
  Future<String> getReferralCode() async => 'STARQPRO';

  @override
  Future<ReferralSummary> getReferralSummary() async => const ReferralSummary(
        referralCode: 'STARQPRO',
        totalReferrals: 0,
        successfulReferrals: 0,
        pendingReferrals: 0,
        totalPointsEarned: 0,
        referrals: [],
      );
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
          final manifestMap = <Object?, Object?>{
            'assets/images/bike image.png': <Object?>[<Object?, Object?>{}],
            'assets/images/car image.png': <Object?>[<Object?, Object?>{}],
            'assets/images/starq_logo.png': <Object?>[<Object?, Object?>{}],
          };
          return const StandardMessageCodec().encodeMessage(manifestMap);
        }
        if (key == 'AssetManifest.json') {
          return ByteData.view(Uint8List.fromList(utf8.encode(jsonEncode({
            'assets/images/bike image.png': ['assets/images/bike image.png'],
            'assets/images/car image.png': ['assets/images/car image.png'],
            'assets/images/starq_logo.png': ['assets/images/starq_logo.png'],
          }))).buffer);
        }
        return ByteData.view(kTransparentImage.buffer);
      },
    );
  });

  group('Profile -> Saved Addresses Fix Tests', () {
    testWidgets('Shows empty state when user has no saved addresses', (tester) async {
      final mockApi = MockTestApiClient();
      mockApi.mockGetResponse = [];

      final addressProvider = AddressProvider(mockApi);
      await addressProvider.fetchAddresses();

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: addressProvider),
            ChangeNotifierProvider(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: SavedAddressesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Saved Addresses Yet', skipOffstage: false), findsOneWidget);
      expect(find.byIcon(Icons.location_off_outlined, skipOffstage: false), findsOneWidget);
    });

    testWidgets('Shows error state with retry button when address fetch fails with empty list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockApi = MockTestApiClient();
      mockApi.shouldFailGet = true;
      mockApi.getErrorMessage = 'Failed to connect to address service';

      final addressProvider = AddressProvider(mockApi);
      await addressProvider.fetchAddresses();

      expect(addressProvider.error, isNotNull);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: addressProvider),
            ChangeNotifierProvider(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: SavedAddressesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Addresses', skipOffstage: false), findsOneWidget);
      expect(find.text('Try Again', skipOffstage: false), findsOneWidget);

      // Verify Try Again button is present and invokes fetchAddresses
      final retryButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Try Again'),
      );
      expect(retryButton.onPressed, isNotNull);

      // Now fix mock and invoke retry
      mockApi.shouldFailGet = false;
      mockApi.mockGetResponse = [
        {
          'id': 'addr_recovered',
          'userId': 'usr_1',
          'line1': 'Flat 101, Orchid Tower',
          'line2': 'Home',
          'city': 'Noida',
          'zipCode': '201301',
        }
      ];

      retryButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(find.text('Home', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('Flat 101, Orchid Tower', skipOffstage: false), findsOneWidget);
      expect(find.text('Failed to Load Addresses', skipOffstage: false), findsNothing);
    });

    testWidgets('Preserves existing addresses and shows non-blocking banner if refresh fails', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockApi = MockTestApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'addr_existing_1',
          'userId': 'usr_1',
          'line1': 'B-12, Sector 62',
          'line2': 'Office',
          'city': 'Noida',
          'zipCode': '201309',
        }
      ];

      final addressProvider = AddressProvider(mockApi);
      await addressProvider.fetchAddresses();

      expect(addressProvider.addresses.length, 1);

      // Subsequent refresh failure
      mockApi.shouldFailGet = true;
      mockApi.getErrorMessage = 'Temporary sync error';
      await addressProvider.fetchAddresses();

      expect(addressProvider.error, isNotNull);
      expect(addressProvider.addresses.length, 1); // Preserved!

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: addressProvider),
            ChangeNotifierProvider(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: SavedAddressesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Address card is still displayed!
      expect(find.text('Office', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('B-12, Sector 62', skipOffstage: false), findsOneWidget);
      // Non-blocking error banner is displayed
      expect(find.textContaining('Temporary sync error', skipOffstage: false), findsOneWidget);
      expect(find.text('Retry', skipOffstage: false), findsOneWidget);
    });

    testWidgets('Adding address immediately reflects in AddressProvider and marks it as active', (tester) async {
      final mockApi = MockTestApiClient();
      final newAddressData = {
        'id': 'addr_new_test',
        'userId': 'usr_1',
        'line1': 'Plot 45, Tech Zone IV',
        'line2': 'Headquarters',
        'city': 'Greater Noida',
        'state': 'Uttar Pradesh',
        'zipCode': '201306',
        'latitude': 28.5355,
        'longitude': 77.3910,
      };
      mockApi.mockPostResponse = newAddressData;
      mockApi.mockGetResponse = [newAddressData];

      final addressProvider = AddressProvider(mockApi);

      final success = await addressProvider.addAddress({
        'line1': 'Plot 45, Tech Zone IV',
        'line2': 'Headquarters',
        'city': 'Greater Noida',
        'state': 'Uttar Pradesh',
        'zipCode': '201306',
        'latitude': 28.5355,
        'longitude': 77.3910,
      });

      expect(success, isTrue);
      expect(addressProvider.addresses.length, 1);
      expect(addressProvider.selectedAddress?.id, 'addr_new_test');
      expect(addressProvider.selectedAddress?.displayTitle, 'Headquarters');

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: addressProvider),
            ChangeNotifierProvider(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: SavedAddressesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Headquarters', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('Plot 45, Tech Zone IV', skipOffstage: false), findsOneWidget);
      // Newly created address does NOT automatically become default
      expect(find.text('Default', skipOffstage: false), findsNothing);
    });

    test('selectAddressById updates selected address without mutating list', () async {
      final mockApi = MockTestApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'addr_1',
          'userId': 'u1',
          'line1': 'House 1',
          'line2': 'Home',
          'city': 'Noida',
        },
        {
          'id': 'addr_2',
          'userId': 'u1',
          'line1': 'House 2',
          'line2': 'Work',
          'city': 'Noida',
        },
      ];

      final addressProvider = AddressProvider(mockApi);
      addressProvider.setCurrentUserId('u1');
      await addressProvider.fetchAddresses('u1');

      expect(addressProvider.selectedAddress?.id, 'addr_1');

      addressProvider.selectAddressById('addr_2');
      expect(addressProvider.selectedAddress?.id, 'addr_2');
      expect(addressProvider.addresses.length, 2);
    });

    testWidgets('SavedAddressesScreen renders all reference design elements', (tester) async {
      final mockApi = MockTestApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'addr_home',
          'userId': 'u1',
          'line1': 'Flat 402, Sunshine Apartments',
          'line2': '[DEFAULT] Home',
          'city': 'Noida',
          'zipCode': '201301',
        },
        {
          'id': 'addr_work',
          'userId': 'u1',
          'line1': 'Tower B, Tech Boulevard',
          'line2': 'Work',
          'city': 'Noida',
          'zipCode': '201309',
        },
      ];

      final addressProvider = AddressProvider(mockApi);
      await addressProvider.fetchAddresses('u1');

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: addressProvider),
            ChangeNotifierProvider(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: SavedAddressesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Heading and Subtitle
      expect(find.text('Saved Addresses'), findsOneWidget);
      expect(find.text('Manage your service locations'), findsOneWidget);

      // Centered StarqLogo and Back arrow
      expect(find.byType(StarqLogo), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Both addresses displayed
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.textContaining('Flat 402, Sunshine Apartments'), findsOneWidget);
      expect(find.textContaining('Tower B, Tech Boulevard'), findsOneWidget);

      // Default badge on explicitly marked default address
      expect(find.text('Default'), findsOneWidget);

      // Red location-pin icons in pink squares
      expect(find.byIcon(Icons.location_on), findsNWidgets(2));

      // Three-dot popup menus
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));

      // Large outlined Add New Address button
      expect(find.widgetWithText(OutlinedButton, 'Add New Address'), findsOneWidget);
    });

    testWidgets('Three-dot menu displays Edit Address, Set as Default, and Delete Address', (tester) async {
      final mockApi = MockTestApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'addr_1',
          'userId': 'u1',
          'line1': 'Flat 101',
          'line2': 'Home',
          'city': 'Noida',
          'zipCode': '201301',
        },
        {
          'id': 'addr_2',
          'userId': 'u1',
          'line1': 'Flat 202',
          'line2': 'Work',
          'city': 'Noida',
          'zipCode': '201309',
        },
      ];

      final addressProvider = AddressProvider(mockApi);
      await addressProvider.fetchAddresses('u1');

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: addressProvider),
            ChangeNotifierProvider(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: SavedAddressesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap three-dot menu on the second address (Work, which is not default)
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.at(1));
      await tester.pumpAndSettle();

      expect(find.text('Edit Address'), findsOneWidget);
      expect(find.text('Set as Default'), findsOneWidget);
      expect(find.text('Delete Address'), findsOneWidget);
    });

    testWidgets('Set as Default updates default badge dynamically', (tester) async {
      final mockApi = MockTestApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'addr_1',
          'userId': 'u1',
          'line1': 'Flat 101',
          'line2': 'Home',
          'city': 'Noida',
          'zipCode': '201301',
        },
        {
          'id': 'addr_2',
          'userId': 'u1',
          'line1': 'Flat 202',
          'line2': 'Work',
          'city': 'Noida',
          'zipCode': '201309',
        },
      ];

      final addressProvider = AddressProvider(mockApi);
      await addressProvider.fetchAddresses('u1');

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: addressProvider),
            ChangeNotifierProvider(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: SavedAddressesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially neither address is default
      expect(addressProvider.defaultAddressId, isNull);
      expect(find.text('Default'), findsNothing);

      // Tap three-dot menu on addr_2 and select 'Set as Default'
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set as Default'));
      await tester.pumpAndSettle();

      // Now addr_2 is default and shows Default badge
      expect(addressProvider.defaultAddressId, 'addr_2');
      expect(find.text('Default'), findsOneWidget);

      // Now tap three-dot menu on addr_1 and select 'Set as Default'
      await tester.tap(moreButtons.at(0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set as Default'));
      await tester.pumpAndSettle();

      // Now addr_1 is default, addr_2 is no longer default, exactly 1 badge
      expect(addressProvider.defaultAddressId, 'addr_1');
      expect(find.text('Default'), findsOneWidget);
    });

    testWidgets('Radio selection indicator moves on tap without changing Default badge', (tester) async {
      final mockApi = MockTestApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'addr_1',
          'userId': 'u1',
          'line1': 'Flat 101',
          'line2': '[DEFAULT] Home',
          'city': 'Noida',
          'zipCode': '201301',
        },
        {
          'id': 'addr_2',
          'userId': 'u1',
          'line1': 'Flat 202',
          'line2': 'Work',
          'city': 'Noida',
          'zipCode': '201309',
        },
      ];

      final addressProvider = AddressProvider(mockApi);
      await addressProvider.fetchAddresses('u1');

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: addressProvider),
            ChangeNotifierProvider(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: SavedAddressesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // addr_1 is default and initially selected
      expect(addressProvider.defaultAddressId, 'addr_1');
      expect(addressProvider.selectedAddress?.id, 'addr_1');
      expect(find.text('Default'), findsOneWidget);

      // Tap on the second address card ('Work')
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      // Selection moved to addr_2
      expect(addressProvider.selectedAddress?.id, 'addr_2');

      // BUT Default badge is UNCHANGED on addr_1!
      expect(addressProvider.defaultAddressId, 'addr_1');
      expect(find.text('Default'), findsOneWidget);
    });

    test('Manual default selection and address selection persist across app cache reload', () async {
      final mockApi = MockTestApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'addr_1',
          'userId': 'u1',
          'line1': 'Flat 101',
          'line2': 'Home',
          'city': 'Noida',
        },
        {
          'id': 'addr_2',
          'userId': 'u1',
          'line1': 'Flat 202',
          'line2': 'Work',
          'city': 'Noida',
        },
      ];

      final prov1 = AddressProvider(mockApi);
      prov1.setCurrentUserId('u1');
      await prov1.fetchAddresses('u1');

      // Set addr_2 as default
      await prov1.setDefaultAddress(prov1.addresses[1], 'u1');
      // Select addr_1 for active booking
      prov1.selectAddress(prov1.addresses[0], 'u1');

      expect(prov1.defaultAddressId, 'addr_2');
      expect(prov1.selectedAddress?.id, 'addr_1');

      // Simulate app restart / cold start with fresh provider loading from cache
      final provRestart = AddressProvider(mockApi);
      provRestart.loadFromCache('u1');

      expect(provRestart.defaultAddressId, 'addr_2');
      expect(provRestart.selectedAddress?.id, 'addr_1');
    });

    testWidgets('Delete Address triggers confirmation dialog with Cancel and Delete', (tester) async {
      final mockApi = MockTestApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'addr_1',
          'userId': 'u1',
          'line1': 'Flat 101',
          'line2': 'Home',
          'city': 'Noida',
          'zipCode': '201301',
        },
      ];

      final addressProvider = AddressProvider(mockApi);
      await addressProvider.fetchAddresses('u1');

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: addressProvider),
            ChangeNotifierProvider(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: SavedAddressesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap three-dot menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Delete Address
      await tester.tap(find.text('Delete Address'));
      await tester.pumpAndSettle();

      // Confirmation dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Are you sure you want to remove "Home"?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Confirm delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Address is removed from provider and empty state is displayed
      expect(addressProvider.addresses, isEmpty);
      expect(find.text('No Saved Addresses Yet'), findsOneWidget);
    });
  });

  group('Rewards Screen Header Fix Tests', () {
    testWidgets('RewardsScreen renders header without StarqLogo or location display', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final rewardsRepo = StubTestPointsRepo();
      final rewardsProvider = RewardsProvider(rewardsRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: rewardsProvider),
          ],
          child: const MaterialApp(
            home: RewardsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirms title is present
      expect(find.text('Rewards', skipOffstage: false), findsOneWidget);
      expect(
        find.text('Earn points, get discounts and save on your next wash.', skipOffstage: false),
        findsOneWidget,
      );

      // Verifies StarqLogo is completely absent from RewardsScreen
      expect(find.byType(StarqLogo), findsNothing);

      // Verifies location text and location pin icon are completely absent from RewardsScreen
      expect(find.text('Sector 62, Noida, UP'), findsNothing);
      expect(find.byIcon(Icons.location_on), findsNothing);
    });

    testWidgets('HomeDashboardScreen preserves StarqLogo and location display', (tester) async {
      final mockApi = MockTestApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'home_addr_1',
          'userId': 'u1',
          'line1': 'Tower C, Express View',
          'city': 'Noida',
        }
      ];

      final addressProvider = AddressProvider(mockApi);
      await addressProvider.fetchAddresses();

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: addressProvider),
            ChangeNotifierProvider(create: (_) => BookingProvider(mockApi)),
            ChangeNotifierProvider(create: (_) => GarageProvider()),
            ChangeNotifierProvider(create: (_) => VehicleProvider(mockApi)),
          ],
          child: const MaterialApp(
            home: HomeDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirms HomeDashboardScreen STILL has StarqLogo and location display
      expect(find.byType(StarqLogo), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });
  });
}
