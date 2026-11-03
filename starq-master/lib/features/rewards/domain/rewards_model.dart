class RewardLedgerEntry {
  final String id;
  final String userId;
  final String? bookingId;
  final int pointsDelta;
  final int balanceAfter;
  final String description;
  final DateTime createdAt;

  RewardLedgerEntry({
    required this.id,
    required this.userId,
    this.bookingId,
    required this.pointsDelta,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
  });

  factory RewardLedgerEntry.fromJson(Map<String, dynamic> json) {
    return RewardLedgerEntry(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      bookingId: json['booking_id'] as String?,
      pointsDelta: json['points_delta'] is num ? (json['points_delta'] as num).toInt() : 0,
      balanceAfter: json['balance_after'] is num ? (json['balance_after'] as num).toInt() : 0,
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class RewardOffer {
  final String id;
  final String name;
  final int pointsCost;
  final String description;

  RewardOffer({
    required this.id,
    required this.name,
    required this.pointsCost,
    required this.description,
  });

  factory RewardOffer.fromJson(Map<String, dynamic> json) {
    return RewardOffer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pointsCost: json['points_cost'] is num ? (json['points_cost'] as num).toInt() : 0,
      description: json['description'] as String? ?? '',
    );
  }
}

class RewardAccount {
  final int totalBalance;
  final List<RewardLedgerEntry> transactions;
  final List<RewardOffer> rewards;

  RewardAccount({
    required this.totalBalance,
    required this.transactions,
    this.rewards = const [],
  });

  factory RewardAccount.fromJson(Map<String, dynamic> json) {
    return RewardAccount(
      totalBalance: json['total_balance'] is num
          ? (json['total_balance'] as num).toInt()
          : json['balance'] is num
              ? (json['balance'] as num).toInt()
              : 0,
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((e) => RewardLedgerEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      rewards: (json['rewards'] as List<dynamic>?)
              ?.map((e) => RewardOffer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
