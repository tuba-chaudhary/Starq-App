import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/core/utils/validators.dart';
import 'package:starq_app/features/providers/address_provider.dart';
import 'package:starq_app/features/addresses/saved_addresses_screen.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:dio/dio.dart';

class MockAddressApiClient implements ApiClient {
  dynamic mockGetResponse;
  dynamic mockPostResponse;
  dynamic mockDeleteResponse;

  String? lastPath;
  Map<String, dynamic>? lastPostData;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastPath = path;
    return Response<T>(
      data: mockGetResponse as T,
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
    lastPath = path;
    lastPostData = data is Map<String, dynamic> ? data : null;
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
    lastPath = path;
    return Response<T>(
      data: (mockDeleteResponse ?? {'status': 'deleted'}) as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService().init();
  });

  // =========================================================================
  // BUG 8 REGRESSION TESTS: Vehicle Registration Validation & Normalization
  // =========================================================================
  group('Bug 8: Vehicle Registration Validation & Normalization', () {
    test('accepts standard valid Indian private vehicle registration patterns', () {
      final validPlates = [
        'MH 01 AB 1234',
        'DL 3C AB 1234',
        'KA 05 M 1234',
        'UP 16 XX 1234',
        'HR 26 DQ 5555',
        'GJ 01 CW 9999',
        'TN 09 BK 0001',
      ];
      for (final plate in validPlates) {
        final err = AppValidators.registrationNumber(plate);
        expect(err, isNull, reason: 'Expected "$plate" to be valid, got "$err"');
      }
    });

    test('accepts Bharat Series registrations', () {
      final bhPlates = [
        '22 BH 1234 AA',
        '21 BH 9999 Z',
        '23BH0001AB',
      ];
      for (final plate in bhPlates) {
        final err = AppValidators.registrationNumber(plate);
        expect(err, isNull, reason: 'Expected Bharat series "$plate" to be valid');
      }
    });

    test('accepts lowercase input and handles spacing variations', () {
      expect(AppValidators.registrationNumber('mh 01 ab 1234'), isNull);
      expect(AppValidators.registrationNumber('mh01ab1234'), isNull);
      expect(AppValidators.registrationNumber('dl3cab1234'), isNull);
      expect(AppValidators.registrationNumber('ka 05 m 1234'), isNull);
      expect(AppValidators.registrationNumber('  up 16 xx 1234  '), isNull);
      expect(AppValidators.registrationNumber('22bh1234aa'), isNull);
    });

    test('rejects arbitrary numbers, invalid state codes, and wrong character positions', () {
      final invalidPlates = [
        '12345678',          // all numbers
        'XX 01 AB 1234',     // invalid state code
        '01 AB 1234',        // missing state code
        'MH AB AB 1234',     // letters where RTO numbers expected
        '12 01 AB 1234',     // digits where state expected
        'MH 01 ABCD 123456', // excessive characters
        'KA1',               // too short
        'DL@01#1234',        // special characters
        '   ',               // whitespace only
      ];
      for (final plate in invalidPlates) {
        final err = AppValidators.registrationNumber(plate);
        expect(err, isNotNull, reason: 'Expected "$plate" to be rejected');
        expect(err!.isNotEmpty, isTrue);
      }
    });

    test('normalizes registration numbers cleanly with standard spacing', () {
      expect(AppValidators.normalizeRegistrationNumber('mh 01 ab 1234'), 'MH 01 AB 1234');
      expect(AppValidators.normalizeRegistrationNumber('mh01ab1234'), 'MH 01 AB 1234');
      expect(AppValidators.normalizeRegistrationNumber('dl3cab1234'), 'DL 3C AB 1234');
      expect(AppValidators.normalizeRegistrationNumber('ka05m1234'), 'KA 05 M 1234');
      expect(AppValidators.normalizeRegistrationNumber('22bh1234aa'), '22 BH 1234 AA');
      expect(AppValidators.normalizeRegistrationNumber('  up-16-xx-1234  '), 'UP 16 XX 1234');
    });
  });

  // =========================================================================
  // BUG 7 REGRESSION TESTS: Address Persistence & Saved Addresses Reload
  // =========================================================================
  group('Bug 7: Saved Address Persistence & Synchronization', () {
    test('AddressProvider persists saved addresses across cold restarts via LocalCacheService', () async {
      final mockApi = MockAddressApiClient();
      mockApi.mockPostResponse = {
        'id': 'addr_persisted_1',
        'userId': 'usr_test_1',
        'line1': 'Tower A, Floor 12, Flat 1204',
        'line2': 'Home',
        'city': 'Noida',
        'state': 'Uttar Pradesh',
        'zipCode': '201309',
        'latitude': 28.6270,
        'longitude': 77.3649,
      };
      mockApi.mockGetResponse = [
        {
          'id': 'addr_persisted_1',
          'userId': 'usr_test_1',
          'line1': 'Tower A, Floor 12, Flat 1204',
          'line2': 'Home',
          'city': 'Noida',
          'state': 'Uttar Pradesh',
          'zipCode': '201309',
          'latitude': 28.6270,
          'longitude': 77.3649,
        }
      ];

      final provider1 = AddressProvider(mockApi);
      provider1.setCurrentUserId('usr_test_1');

      final success = await provider1.addAddress({
        'line1': 'Tower A, Floor 12, Flat 1204',
        'line2': 'Home',
        'city': 'Noida',
        'state': 'Uttar Pradesh',
        'zipCode': '201309',
      }, 'usr_test_1');

      expect(success, isTrue);
      expect(provider1.addresses.length, 1);
      expect(provider1.addresses.first.id, 'addr_persisted_1');
      expect(provider1.selectedAddress?.id, 'addr_persisted_1');

      // Verify written to disk cache
      final rawCache = LocalCacheService().getString('cached_addresses_usr_test_1');
      expect(rawCache, isNotNull);
      expect(rawCache, contains('addr_persisted_1'));

      // Simulate cold app restart: create new AddressProvider with no network call
      final offlineApi = MockAddressApiClient();
      offlineApi.mockGetResponse = <Map<String, dynamic>>[];
      final provider2 = AddressProvider(offlineApi);
      provider2.setCurrentUserId('usr_test_1');

      // Must be restored immediately from cache!
      expect(provider2.addresses.length, 1);
      expect(provider2.addresses.first.id, 'addr_persisted_1');
      expect(provider2.addresses.first.displayTitle, 'Home');
      expect(provider2.addresses.first.line1, 'Tower A, Floor 12, Flat 1204');
      expect(provider2.selectedAddress?.id, 'addr_persisted_1');
    });

    test('AddressProvider maintains strict user isolation between different accounts', () async {
      final mockApi = MockAddressApiClient();
      final provider = AddressProvider(mockApi);

      // User A saves an address
      mockApi.mockPostResponse = {
        'id': 'addr_user_a',
        'userId': 'user_a',
        'line1': 'User A Address',
        'line2': 'Home A',
        'city': 'Noida',
        'zipCode': '201301',
      };
      mockApi.mockGetResponse = [mockApi.mockPostResponse];

      await provider.addAddress({
        'line1': 'User A Address',
        'line2': 'Home A',
        'city': 'Noida',
        'zipCode': '201301',
      }, 'user_a');

      expect(provider.addresses.any((a) => a.id == 'addr_user_a'), isTrue);

      // User A logs out and clears their address cache
      await provider.clear('user_a');
      expect(provider.addresses.isEmpty, isTrue);
      expect(provider.selectedAddress, isNull);

      // User B logs in with their own empty address state
      provider.setCurrentUserId('user_b');
      expect(provider.addresses.isEmpty, isTrue);
      expect(provider.selectedAddress, isNull);
    });

    test('AddressProvider deleteAddress updates memory, selection, and persistent cache', () async {
      final mockApi = MockAddressApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'addr_del_1',
          'userId': 'u1',
          'line1': 'Address To Delete',
          'line2': 'Office',
          'city': 'Noida',
          'zipCode': '201309',
        },
        {
          'id': 'addr_keep_2',
          'userId': 'u1',
          'line1': 'Address To Keep',
          'line2': 'Home',
          'city': 'Noida',
          'zipCode': '201301',
        },
      ];

      final provider = AddressProvider(mockApi);
      provider.setCurrentUserId('u1');
      await provider.fetchAddresses('u1');

      expect(provider.addresses.length, 2);
      expect(provider.selectedAddress?.id, 'addr_del_1');

      // Delete the first address
      final deleted = await provider.deleteAddress('addr_del_1', 'u1');
      expect(deleted, isTrue);
      expect(provider.addresses.length, 1);
      expect(provider.addresses.first.id, 'addr_keep_2');
      expect(provider.selectedAddress?.id, 'addr_keep_2');

      // Verify persistent cache updated
      final cacheAfter = LocalCacheService().getString('cached_addresses_u1');
      expect(cacheAfter, isNotNull);
      expect(cacheAfter, isNot(contains('addr_del_1')));
      expect(cacheAfter, contains('addr_keep_2'));
    });

    testWidgets('SavedAddressesScreen displays user saved addresses and reloads on refresh', (tester) async {
      final mockApi = MockAddressApiClient();
      mockApi.mockGetResponse = [
        {
          'id': 'saved_addr_99',
          'userId': 'u1',
          'line1': '104, Blossom County',
          'line2': 'Primary Home',
          'city': 'Noida',
          'zipCode': '201309',
        }
      ];

      final provider = AddressProvider(mockApi);
      await provider.fetchAddresses();

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: SavedAddressesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SAVED ADDRESSES (1)', skipOffstage: false), findsOneWidget);
      expect(find.text('Primary Home', skipOffstage: false), findsOneWidget);
      expect(find.text('104, Blossom County, Noida - 201309', skipOffstage: false), findsOneWidget);

      // Test refresh
      mockApi.mockGetResponse = [
        {
          'id': 'saved_addr_99',
          'userId': 'u1',
          'line1': '104, Blossom County',
          'line2': 'Primary Home',
          'city': 'Noida',
          'zipCode': '201309',
        },
        {
          'id': 'saved_addr_100',
          'userId': 'u1',
          'line1': 'Sector 62 Work Hub',
          'line2': 'Office',
          'city': 'Noida',
          'zipCode': '201301',
        }
      ];

      await provider.fetchAddresses();
      await tester.pumpAndSettle();

      expect(find.text('SAVED ADDRESSES (2)', skipOffstage: false), findsOneWidget);
      expect(find.text('Office', skipOffstage: false), findsOneWidget);
    });
  });
}
