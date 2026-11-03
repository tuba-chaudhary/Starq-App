import 'package:starq_app/core/network/api_client.dart';

class PointsSummary {
  final int balance;
  final int expiringPoints; // points that expire soonest
  final DateTime? expiringOn;
  final int expiredPointsTotal;

  const PointsSummary({
    required this.balance,
    this.expiringPoints = 0,
    this.expiringOn,
    this.expiredPointsTotal = 0,
  });

  factory PointsSummary.fromJson(Map<String, dynamic> json) {
    return PointsSummary(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      expiringPoints: (json['expiringPoints'] as num?)?.toInt() ?? 0,
      expiringOn: json['expiringOn'] != null
          ? DateTime.tryParse(json['expiringOn'].toString())
          : null,
      expiredPointsTotal: (json['expiredPointsTotal'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'balance': balance,
        'expiringPoints': expiringPoints,
        'expiringOn': expiringOn?.toIso8601String(),
        'expiredPointsTotal': expiredPointsTotal,
      };
}

class PointsEntry {
  final String id;
  final String type; // earned_referral, earned_service, redeemed, expired, etc.
  final int points; // positive = earned, negative = used or expired
  final String note;
  final String? bookingId;
  final DateTime date;
  final DateTime? expiresAt;

  const PointsEntry({
    required this.id,
    required this.type,
    required this.points,
    required this.note,
    this.bookingId,
    required this.date,
    this.expiresAt,
  });

  factory PointsEntry.fromJson(Map<String, dynamic> json) {
    return PointsEntry(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'earned_referral',
      points: (json['points'] as num?)?.toInt() ?? 0,
      note: json['description']?.toString() ?? json['note']?.toString() ?? '',
      bookingId: json['bookingId']?.toString(),
      date: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
    );
  }
}

class ReferralItem {
  final String id;
  final String refereeId;
  final String refereeName;
  final String? refereePhoneMasked;
  final String status; // PENDING, REWARDED, EXPIRED
  final DateTime? rewardedAt;
  final DateTime createdAt;

  const ReferralItem({
    required this.id,
    required this.refereeId,
    required this.refereeName,
    this.refereePhoneMasked,
    required this.status,
    this.rewardedAt,
    required this.createdAt,
  });

  factory ReferralItem.fromJson(Map<String, dynamic> json) {
    return ReferralItem(
      id: json['id']?.toString() ?? '',
      refereeId: json['refereeId']?.toString() ?? '',
      refereeName: json['refereeName']?.toString() ?? 'STARQ Customer',
      refereePhoneMasked: json['refereePhoneMasked']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      rewardedAt: json['rewardedAt'] != null
          ? DateTime.tryParse(json['rewardedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

class ReferralSummary {
  final String referralCode;
  final int totalReferrals;
  final int successfulReferrals;
  final int pendingReferrals;
  final int pointsPerSuccessfulReferral;
  final int totalPointsEarned;
  final List<ReferralItem> referrals;

  const ReferralSummary({
    required this.referralCode,
    this.totalReferrals = 0,
    this.successfulReferrals = 0,
    this.pendingReferrals = 0,
    this.pointsPerSuccessfulReferral = 100,
    this.totalPointsEarned = 0,
    this.referrals = const [],
  });

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    final list = json['referrals'] as List? ?? [];
    return ReferralSummary(
      referralCode: json['referralCode']?.toString() ?? '',
      totalReferrals: (json['totalReferrals'] as num?)?.toInt() ?? 0,
      successfulReferrals: (json['successfulReferrals'] as num?)?.toInt() ?? 0,
      pendingReferrals: (json['pendingReferrals'] as num?)?.toInt() ?? 0,
      pointsPerSuccessfulReferral:
          (json['pointsPerSuccessfulReferral'] as num?)?.toInt() ?? 100,
      totalPointsEarned: (json['totalPointsEarned'] as num?)?.toInt() ?? 0,
      referrals: list
          .map((item) => ReferralItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

abstract class PointsRepository {
  Future<PointsSummary> getSummary();
  Future<List<PointsEntry>> getHistory({int limit = 50});
  Future<String> getReferralCode();
  Future<ReferralSummary> getReferralSummary();
}

class ApiPointsRepository implements PointsRepository {
  final ApiClient _api;

  ApiPointsRepository([ApiClient? api]) : _api = api ?? ApiClient();

  @override
  Future<PointsSummary> getSummary() async {
    final res = await _api.get('/rewards/summary');
    final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
    return PointsSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<List<PointsEntry>> getHistory({int limit = 50}) async {
    final res = await _api.get(
      '/rewards/history',
      queryParameters: {'limit': limit},
    );
    final data = res.data is Map ? res.data : {};
    final list = (data['history'] ?? data['data'] ?? res.data) as List? ?? [];
    return list
        .map((item) => PointsEntry.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<String> getReferralCode() async {
    final res = await _api.get('/rewards/referral-code');
    final data = res.data is Map ? res.data : {};
    final code = data['referralCode']?.toString();
    if (code == null || code.isEmpty) {
      throw Exception('Referral code was not returned by server');
    }
    return code;
  }

  @override
  Future<ReferralSummary> getReferralSummary() async {
    final res = await _api.get('/rewards/referrals');
    final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
    return ReferralSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

// Points repository singleton connected to real backend
final PointsRepository pointsRepository = ApiPointsRepository();

// Points earned on a booking: 5 per Rs 100 of the amount actually paid, rounded down.
int pointsForAmount(int amountInRupees) {
  if (amountInRupees < 100) return 0;
  return (amountInRupees ~/ 100) * 5;
}

// Most points usable on one booking: limited by the balance and by 30% of the total.
int maxRedeemablePoints({required int balance, required int bookingTotal}) {
  if (balance <= 0 || bookingTotal <= 0) return 0;
  final cap = (bookingTotal * 30) ~/ 100;
  return balance < cap ? balance : cap;
}
