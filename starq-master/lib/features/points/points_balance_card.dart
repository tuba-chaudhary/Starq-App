import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/features/providers/rewards_provider.dart';
import 'points_repository.dart';
import 'rewards_colors.dart';

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

class PointsBalanceCard extends StatelessWidget {
  final PointsSummary summary;
  final VoidCallback? onRefresh;

  const PointsBalanceCard({
    super.key,
    required this.summary,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final showExpiry = summary.expiringPoints > 0 && summary.expiringOn != null;
    final hasExpired = summary.expiredPointsTotal > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RewardsColors.lightPink,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RewardsColors.softPink, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your STARQ Points',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${summary.balance}',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'points',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: RewardsColors.red,
                      ),
                    ),
                  ],
                ),
                if (showExpiry) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: RewardsColors.softPink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: RewardsColors.red,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${summary.expiringPoints} points expiring on ${_formatDate(summary.expiringOn!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: RewardsColors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (hasExpired && !showExpiry) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${summary.expiredPointsTotal} points expired past 90 days',
                    style: const TextStyle(
                      fontSize: 11,
                      color: RewardsColors.textGrey,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  '1 point = ₹1 discount on any wash',
                  style: TextStyle(
                    fontSize: 12,
                    color: RewardsColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.card_giftcard,
            size: 64,
            color: RewardsColors.red,
          ),
        ],
      ),
    );
  }
}

class PointsBalanceCardLoader extends StatelessWidget {
  const PointsBalanceCardLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RewardsProvider>();

    if (provider.isLoadingSummary && provider.summary == null) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: RewardsColors.lightPink.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: RewardsColors.red),
        ),
      );
    }

    if (provider.summaryError != null && provider.summary == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: RewardsColors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                provider.summaryError!,
                style: const TextStyle(color: RewardsColors.red, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => provider.loadSummary(),
              child: const Text('Retry', style: TextStyle(color: RewardsColors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final summary = provider.summary ??
        const PointsSummary(balance: 0, expiringPoints: 0);

    return PointsBalanceCard(
      summary: summary,
      onRefresh: () => provider.loadSummary(),
    );
  }
}
