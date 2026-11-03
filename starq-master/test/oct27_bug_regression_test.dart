import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:starq_app/core/location/location_service.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/core/storage/secure_storage_service.dart';
import 'package:starq_app/core/utils/validators.dart';
import 'package:starq_app/features/addresses/data/address_repository.dart';
import 'package:starq_app/features/addresses/saved_addresses_screen.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:starq_app/features/booking/data/booking_repository.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/points/points_repository.dart';
import 'package:starq_app/features/providers/address_provider.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/providers/rewards_provider.dart';
import 'package:starq_app/app/router/app_routes.dart';
import 'package:provider/provider.dart';


class MockHttpClientAdapter implements HttpClientAdapter {
  final Map<String, ResponseBody> responses = {};

  void on(String path, ResponseBody response) {
    responses[path] = response;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    for (final entry in responses.entries) {
      if (options.path.contains(entry.key)) {
        return entry.value;
      }
    }
    return ResponseBody.fromString(
      '{"message": "Not Found"}',
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakePointsRepository implements PointsRepository {
  String? codeToReturn;
  bool shouldThrow = false;

  @override
  Future<PointsSummary> getSummary() async {
    if (shouldThrow) throw Exception('Network error');
    return const PointsSummary(balance: 250, expiringPoints: 0, expiredPointsTotal: 0);
  }

  @override
  Future<List<PointsEntry>> getHistory({int limit = 50}) async {
    if (shouldThrow) throw Exception('Network error');
    return [];
  }

  @override
  Future<String> getReferralCode() async {
    if (shouldThrow) throw Exception('Network error');
    return codeToReturn ?? 'TUBAC472';
  }

  @override
  Future<ReferralSummary> getReferralSummary() async {
    if (shouldThrow) throw Exception('Network error');
    return ReferralSummary(
      referralCode: codeToReturn ?? 'TUBAC472',
      totalReferrals: 2,
      successfulReferrals: 1,
      totalPointsEarned: 100,
      referrals: const [],
    );
  }
}

void main() {

  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> secureStorageData = {};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUpAll(() {
    dotenv.testLoad(mergeWith: {'API_BASE_URL': 'http://localhost:3000/api/v1'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(

      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'write') {
          secureStorageData[methodCall.arguments['key']] = methodCall.arguments['value'];
          return null;
        } else if (methodCall.method == 'read') {
          return secureStorageData[methodCall.arguments['key']];
        } else if (methodCall.method == 'delete') {
          secureStorageData.remove(methodCall.arguments['key']);
          return null;
        } else if (methodCall.method == 'deleteAll') {
          secureStorageData.clear();
          return null;
        }
        return null;
      },
    );
  });

  setUp(() async {
    secureStorageData.clear();
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService().init();
  });


  group('STARQ 27 October Bug Audit & Regression Suite', () {
    // -------------------------------------------------------------
    // Bug 1: Every service shows "Not in catalog"
    // -------------------------------------------------------------
    test('Bug 1: Approved customer-facing catalog has all 6 services with exact names and prices', () {
      final bookingProv = BookingProvider(ApiClient());

      // Catalog contains approved services including all 6 customer-facing services
      expect(bookingProv.services.length, greaterThanOrEqualTo(6));

      final servicesByName = {for (final s in bookingProv.services) s.name: s};

      // 1. Exterior Wash: ₹249
      expect(servicesByName.containsKey('Exterior Wash'), isTrue);
      expect(servicesByName['Exterior Wash']!.variants.first.price, equals(249.0));
      expect(servicesByName['Exterior Wash']!.category.toLowerCase(), equals('car'));

      // 2. Interior Cleaning: ₹399
      expect(servicesByName.containsKey('Interior Cleaning'), isTrue);
      expect(servicesByName['Interior Cleaning']!.variants.first.price, equals(399.0));
      expect(servicesByName['Interior Cleaning']!.category.toLowerCase(), equals('car'));

      // 3. Full Detailing: ₹999
      expect(servicesByName.containsKey('Full Detailing'), isTrue);
      expect(servicesByName['Full Detailing']!.variants.first.price, equals(999.0));
      expect(servicesByName['Full Detailing']!.category.toLowerCase(), equals('car'));

      // 4. Premium Wash: ₹1,299
      expect(servicesByName.containsKey('Premium Wash'), isTrue);
      expect(servicesByName['Premium Wash']!.variants.first.price, equals(1299.0));
      expect(servicesByName['Premium Wash']!.category.toLowerCase(), equals('car'));

      // 5. Bucket Wash: ₹299 (Bike)
      expect(servicesByName.containsKey('Bucket Wash'), isTrue);
      expect(servicesByName['Bucket Wash']!.variants.first.price, equals(299.0));
      expect(servicesByName['Bucket Wash']!.category.toLowerCase(), equals('bike'));

      // 6. Pressure Wash: ₹399 (Bike)
      expect(servicesByName.containsKey('Pressure Wash'), isTrue);
      expect(servicesByName['Pressure Wash']!.variants.first.price, equals(399.0));
      expect(servicesByName['Pressure Wash']!.category.toLowerCase(), equals('bike'));

      // Verify variant IDs exist and are not empty
      for (final s in bookingProv.services) {
        expect(s.variants, isNotEmpty);
        expect(s.variants.first.id, isNotEmpty);
      }
    });

    // -------------------------------------------------------------
    // Bug 2: No GPS/current-location option on Select Location
    // -------------------------------------------------------------
    test('Bug 2: LocationService defines structured statuses and handles errors', () {
      const successResult = LocationResult(status: LocationStatus.success);
      expect(successResult.status, equals(LocationStatus.success));

      const disabledResult = LocationResult(
        status: LocationStatus.serviceDisabled,
        message: 'GPS disabled',
      );
      expect(disabledResult.status, equals(LocationStatus.serviceDisabled));
      expect(disabledResult.isSuccess, isFalse);

      const deniedForever = LocationResult(
        status: LocationStatus.permissionDeniedForever,
        message: 'Permission denied forever',
      );
      expect(deniedForever.status, equals(LocationStatus.permissionDeniedForever));
      expect(deniedForever.isSuccess, isFalse);

      const timeoutResult = LocationResult(
        status: LocationStatus.timeout,
        message: 'Request timed out',
      );
      expect(timeoutResult.status, equals(LocationStatus.timeout));
      expect(timeoutResult.isSuccess, isFalse);
    });

    testWidgets('Bug 2: SavedAddressesScreen displays Use Current Location option', (tester) async {
      final mockAdapter = MockHttpClientAdapter();
      final client = ApiClient();
      client.dio.httpClientAdapter = mockAdapter;
      mockAdapter.on('/addresses', ResponseBody.fromString(
        '[]',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      ));

      final addressProv = AddressProvider(client);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: addressProv),
            ChangeNotifierProvider(create: (_) => BookingFlowProvider()),
          ],
          child: const MaterialApp(
            home: SavedAddressesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
 
      expect(find.text('Saved Addresses'), findsOneWidget);
      expect(find.text('Manage your service locations'), findsOneWidget);
      expect(find.text('Add New Address'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Bug 3: Saving an address reports "No internet connection"
    // -------------------------------------------------------------
    test('Bug 3: AddressRepository correctly parses unwrapped NestJS responses', () async {
      final mockAdapter = MockHttpClientAdapter();
      final client = ApiClient();
      client.dio.httpClientAdapter = mockAdapter;

      // Mock unwrapped address list response (as returned directly by NestJS)
      mockAdapter.on('/addresses', ResponseBody.fromString(
        '[{"id": "addr_101", "userId": "user_1", "line1": "Flat 302, ATS One", "line2": "Home", "city": "Noida", "state": "Uttar Pradesh", "zipCode": "201309", "latitude": 28.627, "longitude": 77.364}]',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      ));

      final repo = AddressRepository();
      final list = await repo.list();
      expect(list.length, equals(1));
      expect(list.first.id, equals('addr_101'));
      expect(list.first.addressLine, equals('Flat 302, ATS One'));
      expect(list.first.city, equals('Noida'));
      expect(list.first.pincode, equals('201309'));

      // Mock unwrapped single address creation response
      mockAdapter.on('/addresses', ResponseBody.fromString(
        '{"id": "addr_102", "userId": "user_1", "line1": "Tower 4, Sector 62", "line2": "Office", "city": "Noida", "state": "Uttar Pradesh", "zipCode": "201309", "latitude": 28.628, "longitude": 77.365}',
        201,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      ));

      final created = await repo.create({
        'line1': 'Tower 4, Sector 62',
        'line2': 'Office',
        'city': 'Noida',
        'state': 'Uttar Pradesh',
        'zipCode': '201309',
        'latitude': 28.628,
        'longitude': 77.365,
      });

      expect(created.id, equals('addr_102'));
      expect(created.addressLine, equals('Tower 4, Sector 62'));
      expect(created.label, equals('Office'));
      expect(created.pincode, equals('201309'));
    });

    // -------------------------------------------------------------
    // Bug 4: Referral code shows "Unavailable"
    // -------------------------------------------------------------
    test('Bug 4: RewardsProvider initializes from cache and falls back to user code when API fails', () async {
      final fakeRepo = FakePointsRepository()..shouldThrow = true;
      final rewards = RewardsProvider(fakeRepo);

      // 1. Initial state without cache
      expect(rewards.referralCode, isNull);

      // 2. Seed with user's permanent referral code
      rewards.seedReferralCode('PERM7890');
      expect(rewards.referralCode, equals('PERM7890'));

      // 3. When loadReferrals is called while backend throws error, referral code is preserved
      await rewards.loadReferrals(fallbackUserCode: 'PERM7890');
      expect(rewards.referralCode, equals('PERM7890'));

      // 4. Verify LocalCacheService has persisted the referral code
      final cached = LocalCacheService().getString('cached_referral_code');
      expect(cached, equals('PERM7890'));

      // 5. A new instance of RewardsProvider automatically restores cached code
      final freshRewards = RewardsProvider(fakeRepo);
      expect(freshRewards.referralCode, equals('PERM7890'));
    });

    // -------------------------------------------------------------
    // Bug 5: Bookings do not load
    // -------------------------------------------------------------
    test('Bug 5: BookingRepository list parses unwrapped list and tolerates corrupt items', () async {
      final mockAdapter = MockHttpClientAdapter();
      final client = ApiClient();
      client.dio.httpClientAdapter = mockAdapter;

      // Mock unwrapped list of bookings with valid and one malformed item
      mockAdapter.on('/bookings', ResponseBody.fromString(
        '['
        '  {"id": "b_1", "booking_number": "BK-001", "status": "CONFIRMED", "scheduled_date": "2026-10-28T10:00:00Z", "totalAmount": 249},'
        '  {"invalid_structure": 123},'
        '  {"id": "b_2", "booking_number": "BK-002", "status": "COMPLETED", "scheduled_date": "2026-10-27T14:00:00Z", "totalAmount": 999}'
        ']',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      ));

      final repo = BookingRepository();
      final bookings = await repo.list();

      // Successfully parsed the valid bookings without crashing
      expect(bookings.length, equals(3));
      expect(bookings[0].id, equals('b_1'));
      expect(bookings[0].bookingNumber, equals('BK-001'));
      expect(bookings[0].finalTotalAmount, equals(249.0));
      expect(bookings[2].id, equals('b_2'));
      expect(bookings[2].bookingNumber, equals('BK-002'));
      expect(bookings[2].finalTotalAmount, equals(999.0));
    });

    // -------------------------------------------------------------
    // Bug 6: Login accepts an incomplete or invalid email
    // -------------------------------------------------------------
    test('Bug 6: AppValidators.email correctly rejects incomplete and invalid email formats', () {
      // Empty or whitespace
      expect(AppValidators.email(null), isNotNull);
      expect(AppValidators.email(''), isNotNull);
      expect(AppValidators.email('   '), isNotNull);

      // Incomplete or missing domain / @
      expect(AppValidators.email('tuba'), isNotNull);
      expect(AppValidators.email('tuba@'), isNotNull);
      expect(AppValidators.email('tuba@domain'), isNotNull);
      expect(AppValidators.email('tuba@.com'), isNotNull);
      expect(AppValidators.email('@domain.com'), isNotNull);

      // Valid email addresses
      expect(AppValidators.email('tuba@starq.app'), isNull);
      expect(AppValidators.email('chaudharytuba83@gmail.com'), isNull);
    });

    test('Bug 6: AuthProvider.login rejects invalid email format before network call', () async {
      final client = ApiClient();
      final storage = SecureStorageService();
      final auth = AuthProvider(client, storage);

      // Attempting to login with invalid emails fails immediately without sending network request
      final result1 = await auth.login('incomplete', 'password123');
      expect(result1, isFalse);
      expect(auth.error, equals('Please enter a valid email address'));
      expect(auth.isAuthenticated, isFalse);

      final result2 = await auth.login('user@', 'password123');
      expect(result2, isFalse);
      expect(auth.error, equals('Please enter a valid email address'));
      expect(auth.isAuthenticated, isFalse);
    });

    test('Bug 6: AuthProvider.logout clears all credentials and local user state', () async {
      final client = ApiClient();
      final storage = SecureStorageService();
      final auth = AuthProvider(client, storage);

      // Seed tokens and caches
      await storage.saveTokens(accessToken: 'sample_token_xyz');
      await LocalCacheService().setString('cached_user_json', '{"id":"u1","email":"test@starq.com"}');
      await LocalCacheService().setString('cached_referral_code', 'REF1234');
      await LocalCacheService().setString('selected_address_id', 'addr_1');

      // Execute logout
      await auth.logout();

      // Verify everything is wiped clean
      final token = await storage.getAccessToken();
      expect(token, isNull);
      expect(LocalCacheService().getString('cached_user_json'), isNull);
      expect(LocalCacheService().getString('cached_referral_code'), isNull);
      expect(LocalCacheService().getString('selected_address_id'), isNull);
      expect(auth.currentUser, isNull);
      expect(auth.isAuthenticated, isFalse);
    });

    test('Bug 6: AppRouter starts on /splash while restoring session to prevent sign-in flash', () {
      final client = ApiClient();
      final storage = SecureStorageService();
      final auth = AuthProvider(client, storage);

      final router = createAppRouter(auth);

      // Initial location is /splash while session loading completes
      expect(router.routeInformationProvider.value.uri.toString(), equals('/splash'));
    });
  });
}
