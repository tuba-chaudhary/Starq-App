import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/secure_storage_service.dart';
import 'package:starq_app/features/auth/domain/user_model.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:starq_app/features/auth/role_selection_screen.dart';
import 'package:starq_app/features/partner_onboarding/screens/partner_status_screen.dart';
import 'package:starq_app/features/profile/profile_screen.dart';
import 'package:starq_app/features/providers/rewards_provider.dart';
import 'package:starq_app/features/points/points_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeApiClient implements ApiClient {
  final Map<String, dynamic> responses = {};
  final List<String> requestedPaths = [];
  dynamic lastRequestBody;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    requestedPaths.add(path);
    final data = responses[path];
    return Response<T>(
      data: data as T,
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
    requestedPaths.add(path);
    lastRequestBody = data;
    final res = responses[path] ?? {'accessToken': 'mock_token', 'user': {'id': 'u1', 'role': 'CUSTOMER'}};
    return Response<T>(
      data: res as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSecureStorage implements SecureStorageService {
  String? token;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    token = accessToken;
  }

  @override
  Future<void> clearAll() async {
    token = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPointsRepo implements PointsRepository {
  @override
  Future<PointsSummary> getSummary() async => const PointsSummary(balance: 100);

  @override
  Future<List<PointsEntry>> getHistory({int limit = 50}) async => [];

  @override
  Future<String> getReferralCode() async => 'STARQ123';

  @override
  Future<ReferralSummary> getReferralSummary() async => const ReferralSummary(
        referralCode: 'STARQ123',
        totalReferrals: 0,
        successfulReferrals: 0,
        pendingReferrals: 0,
        totalPointsEarned: 0,
        referrals: [],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('STARQ Customer & Service Partner Registration Tests', () {
    test('1. UserModel multi-role and partner status parsing', () {
      final customerUser = User.fromJson({
        'id': 'u1',
        'email': 'customer@starq.com',
        'fullName': 'Customer User',
        'role': 'CUSTOMER',
        'roles': ['CUSTOMER'],
        'phone': '9876543210',
      });

      expect(customerUser.roles, ['CUSTOMER']);
      expect(customerUser.isApprovedPartner, false);

      final partnerUser = User.fromJson({
        'id': 'u2',
        'email': 'partner@starq.com',
        'fullName': 'Partner User',
        'role': 'PARTNER',
        'roles': ['CUSTOMER', 'PARTNER'],
        'phone': '9876543210',
        'partnerApplication': {'status': 'APPROVED', 'applicationId': 'STQ-APP-12345'},
      });

      expect(partnerUser.roles, ['CUSTOMER', 'PARTNER']);
      expect(partnerUser.isApprovedPartner, true);
    });

    test('2. AuthProvider OTP send, verify and mode switching', () async {
      final fakeApi = FakeApiClient();
      final fakeStorage = FakeSecureStorage();
      final auth = AuthProvider(fakeApi, fakeStorage);

      // OTP Send
      fakeApi.responses['/auth/otp/send'] = {'success': true};
      final sendOk = await auth.sendOtp('9876543210');
      expect(sendOk, true);
      expect(fakeApi.requestedPaths, contains('/auth/otp/send'));

      // OTP Verify
      fakeApi.responses['/auth/otp/verify'] = {
        'accessToken': 'jwt_otp_token',
        'user': {
          'id': 'u1',
          'email': '9876543210@phone.starq.app',
          'fullName': 'Ramesh Kumar',
          'role': 'CUSTOMER',
          'roles': ['CUSTOMER'],
          'phone': '9876543210',
        },
      };

      final verifyOk = await auth.verifyOtp('9876543210', '123456');
      expect(verifyOk, true);
      expect(auth.currentUser?.phone, '9876543210');
      expect(auth.currentUser?.role, 'CUSTOMER');

      // Mode Switch
      fakeApi.responses['/auth/switch-mode'] = {
        'accessToken': 'jwt_partner_token',
        'user': {
          'id': 'u1',
          'email': '9876543210@phone.starq.app',
          'fullName': 'Ramesh Kumar',
          'role': 'PARTNER',
          'roles': ['CUSTOMER', 'PARTNER'],
          'phone': '9876543210',
        },
      };

      final switchOk = await auth.switchMode('PARTNER');
      expect(switchOk, true);
      expect(auth.currentUser?.role, 'PARTNER');
      expect(auth.currentUser?.roles, ['CUSTOMER', 'PARTNER']);
    });

    testWidgets('3. RoleSelectionScreen renders Customer and Service Provider options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoleSelectionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose your role to get started'), findsOneWidget);
      expect(find.text("I'm a Customer"), findsOneWidget);
      expect(find.text('Book professional car care at your doorstep'), findsOneWidget);
      expect(find.text("I'm a Service Provider"), findsOneWidget);
      expect(find.text('Provide car wash services and earn with STARQ'), findsOneWidget);
    });

    testWidgets('4. PartnerStatusScreen renders PENDING_VERIFICATION state', (tester) async {
      final fakeApi = FakeApiClient();
      final fakeStorage = FakeSecureStorage();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: fakeApi),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(fakeApi, fakeStorage)),
          ],
          child: const MaterialApp(
            home: PartnerStatusScreen(
              initialData: {
                'status': 'PENDING_VERIFICATION',
                'applicationId': 'STQ-APP-88492',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Application Under Review'), findsOneWidget);
      expect(
        find.text('Your STARQ Service Partner application is under verification. Our team will review your details.'),
        findsOneWidget,
      );
      expect(find.text('STQ-APP-88492'), findsOneWidget);
      expect(find.text('Continue in Customer Mode'), findsOneWidget);
    });

    testWidgets('5. PartnerStatusScreen renders APPROVED state with dashboard entry', (tester) async {
      final fakeApi = FakeApiClient();
      final fakeStorage = FakeSecureStorage();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: fakeApi),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(fakeApi, fakeStorage)),
          ],
          child: const MaterialApp(
            home: PartnerStatusScreen(
              initialData: {
                'status': 'APPROVED',
                'applicationId': 'STQ-APP-88492',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Congratulations!'), findsOneWidget);
      expect(find.text('Your STARQ Service Partner account has been approved.'), findsOneWidget);
      expect(find.text('Enter Partner Dashboard'), findsOneWidget);
    });

    testWidgets('6. PartnerStatusScreen renders REJECTED state with admin reason and resubmit', (tester) async {
      final fakeApi = FakeApiClient();
      final fakeStorage = FakeSecureStorage();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: fakeApi),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(fakeApi, fakeStorage)),
          ],
          child: const MaterialApp(
            home: PartnerStatusScreen(
              initialData: {
                'status': 'REJECTED',
                'applicationId': 'STQ-APP-88492',
                'rejectionReason': 'ID proof was blurry and unreadable.',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Application Needs Correction'), findsOneWidget);
      expect(find.text('ID proof was blurry and unreadable.'), findsOneWidget);
      expect(find.text('Edit & Resubmit Application'), findsOneWidget);
    });

    testWidgets('7. ProfileScreen displays Switch to Partner Mode when partner is approved', (tester) async {
      final fakeApi = FakeApiClient();
      final fakeStorage = FakeSecureStorage();
      fakeApi.responses['/auth/me'] = {
        'id': 'u1',
        'email': 'partner@starq.com',
        'fullName': 'Approved Partner',
        'role': 'CUSTOMER',
        'roles': ['CUSTOMER', 'PARTNER'],
        'partnerApplication': {'status': 'APPROVED'},
      };

      final auth = AuthProvider(fakeApi, fakeStorage);
      await auth.fetchMe();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<RewardsProvider>(create: (_) => RewardsProvider(MockPointsRepo())),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Switch to Partner Mode'), findsOneWidget);
      expect(find.text('Manage your service jobs'), findsOneWidget);
    });
  });
}
