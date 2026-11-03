import 'package:flutter_test/flutter_test.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/secure_storage_service.dart';
import 'package:starq_app/features/points/points_repository.dart';
import 'package:starq_app/features/providers/rewards_provider.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:dio/dio.dart';

class FakeRewardsApiClient implements ApiClient {
  String lastPath = '';
  Map<String, dynamic>? lastQueryParams;
  dynamic lastData;
  Map<String, dynamic> mockResponseData = {};
  bool throwError = false;
  String errorMessage = 'API Error';

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPath = path;
    lastQueryParams = queryParameters;
    if (throwError) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 500,
          data: {'message': errorMessage},
        ),
      );
    }
    return Response(
      requestOptions: RequestOptions(path: path),
      data: mockResponseData,
      statusCode: 200,
    ) as Response<T>;
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPath = path;
    lastData = data;
    if (throwError) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 400,
          data: {'message': errorMessage},
        ),
      );
    }
    return Response(
      requestOptions: RequestOptions(path: path),
      data: mockResponseData,
      statusCode: 201,
    ) as Response<T>;
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

void main() {
  group('Points Policy & Calculation Tests', () {
    test('pointsForAmount: 5 points for every Rs 100 spent (rounded down)', () {
      expect(pointsForAmount(0), 0);
      expect(pointsForAmount(99), 0);
      expect(pointsForAmount(100), 5);
      expect(pointsForAmount(199), 5);
      expect(pointsForAmount(249), 10);
      expect(pointsForAmount(299), 10);
      expect(pointsForAmount(499), 20);
      expect(pointsForAmount(1000), 50);
      expect(pointsForAmount(-100), 0);
    });

    test('maxRedeemablePoints: cap at smaller of balance and 30% of total', () {
      // 30% of 200 is 60. Balance is 40 -> max is 40
      expect(maxRedeemablePoints(balance: 40, bookingTotal: 200), 40);

      // 30% of 200 is 60. Balance is 100 -> max is 60
      expect(maxRedeemablePoints(balance: 100, bookingTotal: 200), 60);

      // Zero balance
      expect(maxRedeemablePoints(balance: 0, bookingTotal: 200), 0);

      // Zero total
      expect(maxRedeemablePoints(balance: 100, bookingTotal: 0), 0);
    });
  });

  group('Points & Referral Model Parsing Tests', () {
    test('PointsSummary fromJson and toJson', () {
      final json = {
        'balance': 200,
        'expiringPoints': 50,
        'expiringOn': '2026-12-31T23:59:59.000Z',
        'expiredPointsTotal': 10,
      };

      final summary = PointsSummary.fromJson(json);

      expect(summary.balance, 200);
      expect(summary.expiringPoints, 50);
      expect(summary.expiringOn, isNotNull);
      expect(summary.expiringOn!.year, 2026);
      expect(summary.expiredPointsTotal, 10);

      final exported = summary.toJson();
      expect(exported['balance'], 200);
      expect(exported['expiringPoints'], 50);
    });

    test('PointsEntry fromJson parses credit and debit entries', () {
      final creditJson = {
        'id': 'p-1',
        'type': 'earned_referral',
        'points': 100,
        'description': 'Referral reward: friend completed first booking',
        'bookingId': 'b-100',
        'createdAt': '2026-10-23T10:00:00.000Z',
        'expiresAt': '2027-01-21T10:00:00.000Z',
      };

      final entry = PointsEntry.fromJson(creditJson);
      expect(entry.id, 'p-1');
      expect(entry.points, 100);
      expect(entry.type, 'earned_referral');
      expect(entry.note, contains('friend completed first booking'));
      expect(entry.bookingId, 'b-100');
      expect(entry.expiresAt, isNotNull);

      final debitJson = {
        'id': 'p-2',
        'type': 'redeemed',
        'points': -50,
        'description': 'Redeemed on booking',
        'createdAt': '2026-10-23T12:00:00.000Z',
      };
      final debitEntry = PointsEntry.fromJson(debitJson);
      expect(debitEntry.points, -50);
      expect(debitEntry.type, 'redeemed');
      expect(debitEntry.expiresAt, isNull);
    });

    test('ReferralSummary fromJson parses summary metrics and referee list', () {
      final json = {
        'referralCode': 'STARQ9ABC',
        'totalReferrals': 3,
        'successfulReferrals': 1,
        'pendingReferrals': 2,
        'pointsPerSuccessfulReferral': 100,
        'totalPointsEarned': 100,
        'referrals': [
          {
            'id': 'ref-1',
            'refereeId': 'u-2',
            'refereeName': 'John Doe',
            'refereePhoneMasked': '98****1234',
            'status': 'REWARDED',
            'rewardedAt': '2026-10-23T11:00:00.000Z',
            'createdAt': '2026-10-22T09:00:00.000Z',
          },
          {
            'id': 'ref-2',
            'refereeId': 'u-3',
            'refereeName': 'Jane Smith',
            'refereePhoneMasked': '99****5678',
            'status': 'PENDING',
            'createdAt': '2026-10-23T08:00:00.000Z',
          }
        ]
      };

      final summary = ReferralSummary.fromJson(json);

      expect(summary.referralCode, 'STARQ9ABC');
      expect(summary.totalReferrals, 3);
      expect(summary.successfulReferrals, 1);
      expect(summary.pendingReferrals, 2);
      expect(summary.totalPointsEarned, 100);
      expect(summary.referrals.length, 2);

      final first = summary.referrals[0];
      expect(first.refereeName, 'John Doe');
      expect(first.refereePhoneMasked, '98****1234');
      expect(first.status, 'REWARDED');
      expect(first.rewardedAt, isNotNull);

      final second = summary.referrals[1];
      expect(second.status, 'PENDING');
      expect(second.rewardedAt, isNull);
    });
  });

  group('ApiPointsRepository Tests', () {
    late FakeRewardsApiClient fakeApi;
    late ApiPointsRepository repo;

    setUp(() {
      fakeApi = FakeRewardsApiClient();
      repo = ApiPointsRepository(fakeApi);
    });

    test('getSummary calls GET /rewards/summary and parses response', () async {
      fakeApi.mockResponseData = {
        'balance': 350,
        'expiringPoints': 100,
        'expiringOn': '2026-11-15T00:00:00.000Z',
        'expiredPointsTotal': 0,
      };

      final summary = await repo.getSummary();

      expect(fakeApi.lastPath, '/rewards/summary');
      expect(summary.balance, 350);
      expect(summary.expiringPoints, 100);
    });

    test('getSummary propagates error on API failure', () async {
      fakeApi.throwError = true;
      expect(() => repo.getSummary(), throwsA(isA<DioException>()));
    });

    test('getHistory calls GET /rewards/history?limit=50', () async {
      fakeApi.mockResponseData = {
        'history': [
          {
            'id': 'pts-1',
            'points': 100,
            'type': 'earned_referral',
            'description': 'Welcome referral',
            'createdAt': '2026-10-20T00:00:00.000Z',
          }
        ],
        'total': 1,
      };

      final history = await repo.getHistory(limit: 50);

      expect(fakeApi.lastPath, '/rewards/history');
      expect(fakeApi.lastQueryParams?['limit'], 50);
      expect(history.length, 1);
      expect(history[0].points, 100);
    });

    test('getReferralCode calls GET /rewards/referral-code and returns string', () async {
      fakeApi.mockResponseData = {'referralCode': 'STARQ4K9X2M'};

      final code = await repo.getReferralCode();

      expect(fakeApi.lastPath, '/rewards/referral-code');
      expect(code, 'STARQ4K9X2M');
    });

    test('getReferralSummary calls GET /rewards/referrals', () async {
      fakeApi.mockResponseData = {
        'referralCode': 'STARQ4K9X2M',
        'totalReferrals': 2,
        'successfulReferrals': 1,
        'pendingReferrals': 1,
        'pointsPerSuccessfulReferral': 100,
        'totalPointsEarned': 100,
        'referrals': [],
      };

      final summary = await repo.getReferralSummary();

      expect(fakeApi.lastPath, '/rewards/referrals');
      expect(summary.referralCode, 'STARQ4K9X2M');
      expect(summary.totalReferrals, 2);
    });
  });

  group('RewardsProvider State Management Tests', () {
    late FakeRewardsApiClient fakeApi;
    late ApiPointsRepository repo;
    late RewardsProvider provider;

    setUp(() {
      fakeApi = FakeRewardsApiClient();
      repo = ApiPointsRepository(fakeApi);
      provider = RewardsProvider(repo);
    });

    test('loadSummary updates state and notifies listeners on success', () async {
      fakeApi.mockResponseData = {
        'balance': 150,
        'expiringPoints': 0,
        'expiringOn': null,
        'expiredPointsTotal': 0,
      };

      expect(provider.isLoadingSummary, false);
      expect(provider.summary, isNull);

      await provider.loadSummary();

      expect(provider.isLoadingSummary, false);
      expect(provider.summary?.balance, 150);
      expect(provider.summaryError, isNull);
    });

    test('loadSummary sets summaryError on failure', () async {
      fakeApi.throwError = true;

      await provider.loadSummary();

      expect(provider.isLoadingSummary, false);
      expect(provider.summary, isNull);
      expect(provider.summaryError, isNotNull);
    });

    test('loadHistory updates state on success', () async {
      fakeApi.mockResponseData = {
        'history': [
          {
            'id': 'h-1',
            'points': 100,
            'type': 'earned_referral',
            'description': 'Referral credit',
            'createdAt': '2026-10-23T00:00:00.000Z',
          }
        ]
      };

      await provider.loadHistory();

      expect(provider.isLoadingHistory, false);
      expect(provider.history.length, 1);
      expect(provider.history[0].id, 'h-1');
      expect(provider.historyError, isNull);
    });

    test('loadReferrals updates referralSummary and code on success', () async {
      fakeApi.mockResponseData = {
        'referralCode': 'STARQPROV1',
        'totalReferrals': 1,
        'successfulReferrals': 0,
        'pendingReferrals': 1,
        'pointsPerSuccessfulReferral': 100,
        'totalPointsEarned': 0,
        'referrals': []
      };

      await provider.loadReferrals();

      expect(provider.isLoadingReferrals, false);
      expect(provider.referralSummary?.referralCode, 'STARQPROV1');
      expect(provider.referralCode, 'STARQPROV1');
      expect(provider.referralError, isNull);
    });

    test('refreshAll triggers loadSummary, loadHistory, and loadReferrals', () async {
      fakeApi.mockResponseData = {
        'balance': 200,
        'expiringPoints': 0,
        'expiringOn': null,
        'expiredPointsTotal': 0,
        'history': [],
        'referralCode': 'STARQREFRESH',
        'totalReferrals': 0,
        'successfulReferrals': 0,
        'pendingReferrals': 0,
        'pointsPerSuccessfulReferral': 100,
        'totalPointsEarned': 0,
        'referrals': []
      };

      await provider.refreshAll();

      expect(provider.summary?.balance, 200);
      expect(provider.referralCode, 'STARQREFRESH');
    });
  });

  group('Signup Referral Integration Tests', () {
    late FakeRewardsApiClient fakeApi;
    late FakeSecureStorage fakeStorage;
    late AuthProvider authProvider;

    setUp(() {
      fakeApi = FakeRewardsApiClient();
      fakeStorage = FakeSecureStorage();
      authProvider = AuthProvider(fakeApi, fakeStorage);
    });

    test('register includes referralCode in payload when provided and non-empty', () async {
      fakeApi.mockResponseData = {
        'accessToken': 'jwt_token_123',
        'user': {
          'id': 'u-1',
          'fullName': 'Alice Smith',
          'email': 'alice@example.com',
          'phone': '9876543210',
          'role': 'CUSTOMER',
        }
      };

      final success = await authProvider.register(
        'Alice Smith',
        'alice@example.com',
        '9876543210',
        'Password123!',
        referralCode: 'starqfriend1',
      );

      expect(success, true);
      expect(fakeApi.lastPath, '/auth/register');
      expect(fakeApi.lastData, isA<Map<String, dynamic>>());
      expect(fakeApi.lastData['referralCode'], 'STARQFRIEND1'); // normalized to uppercase
      expect(fakeApi.lastData['fullName'], 'Alice Smith');
    });

    test('register omits referralCode from payload when null or empty', () async {
      fakeApi.mockResponseData = {
        'accessToken': 'jwt_token_456',
        'user': {
          'id': 'u-2',
          'fullName': 'Bob Jones',
          'email': 'bob@example.com',
          'phone': '9876543211',
          'role': 'CUSTOMER',
        }
      };

      // Test with null
      final success1 = await authProvider.register(
        'Bob Jones',
        'bob@example.com',
        '9876543211',
        'Password123!',
        referralCode: null,
      );
      expect(success1, true);
      expect(fakeApi.lastData.containsKey('referralCode'), false);

      // Test with empty string
      final success2 = await authProvider.register(
        'Bob Jones',
        'bob@example.com',
        '9876543211',
        'Password123!',
        referralCode: '   ',
      );
      expect(success2, true);
      expect(fakeApi.lastData.containsKey('referralCode'), false);
    });

    test('register sets error message when backend rejects invalid referral code', () async {
      fakeApi.throwError = true;
      fakeApi.errorMessage = 'Referral code not found';

      final success = await authProvider.register(
        'Charlie',
        'charlie@example.com',
        '9876543212',
        'Password123!',
        referralCode: 'STARQINVALID',
      );

      expect(success, false);
      expect(authProvider.error, 'Referral code not found');
    });
  });
}
