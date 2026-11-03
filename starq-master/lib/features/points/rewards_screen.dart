import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/bottom_nav_bar.dart';
import 'package:starq_app/features/providers/rewards_provider.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'points_balance_card.dart';
import 'points_repository.dart';
import 'rewards_colors.dart';

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class RewardsScreen extends StatefulWidget {
  final VoidCallback? onRateService;
  final VoidCallback? onRateApp;

  const RewardsScreen({
    super.key,
    this.onRateService,
    this.onRateApp,
  });

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        String? userCode;
        try {
          userCode = context.read<AuthProvider>().currentUser?.referralCode;
        } catch (_) {}
        final rewards = context.read<RewardsProvider>();
        if (userCode != null && userCode.isNotEmpty) {
          rewards.seedReferralCode(userCode);
        }
        rewards.refreshAll(fallbackUserCode: userCode);
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RewardsProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: RewardsColors.red,
          onRefresh: () => provider.refreshAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Title, Subtitle, and Actions (no logo, no location)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rewards',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Earn points, get discounts and save on your next wash.',
                            style: TextStyle(fontSize: 13, color: RewardsColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => provider.refreshAll(),
                      tooltip: 'Refresh Rewards',
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: provider.isLoadingAny
                            ? RewardsColors.red
                            : AppColors.textDark,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryLight,
                        child:
                            Icon(Icons.person, color: AppColors.primary, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Balance Card
                const PointsBalanceCardLoader(),
                const SizedBox(height: 16),

                // Refer & Earn Card
                const _ReferAndEarnCard(),
                const SizedBox(height: 16),

                // Points Ledger History Section
                const _PointsHistorySection(),
                const SizedBox(height: 16),

                // Rate & Earn Card
                _RateAndEarnCard(
                  onRateService: widget.onRateService ??
                      () => _showMessage(
                          context, 'Complete a service to rate it.'),
                  onRateApp: widget.onRateApp ??
                      () => _showMessage(
                          context, 'Play Store rating is not connected yet.'),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          const AppBottomNav(currentIndex: 2, items: customerNavItems),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RewardsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: RewardsColors.lightPink,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: RewardsColors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: RewardsColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ReferAndEarnCard extends StatelessWidget {
  const _ReferAndEarnCard();

  Future<void> _copy(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    _showMessage(context, 'Referral code $code copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RewardsProvider>();
    final code = provider.referralCode;
    final summary = provider.referralSummary;
    final isLoading = provider.isLoadingReferrals && code == null;
    final error = provider.referralError;

    return _SectionCard(
      icon: Icons.people_outline,
      title: 'Refer & Earn',
      subtitle: 'Invite your friends to STARQ and earn rewards.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null && code == null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: RewardsColors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(
                          color: RewardsColors.red, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => provider.loadReferrals(),
                    child: const Text('Retry',
                        style: TextStyle(
                            color: RewardsColors.red,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: (code == null || isLoading)
                      ? null
                      : () => _copy(context, code),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: RewardsColors.red),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Referral Code',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: RewardsColors.textGrey,
                                ),
                              ),
                              if (isLoading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: RewardsColors.red,
                                  ),
                                )
                              else
                                Text(
                                  code ?? 'Unavailable',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.copy, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: (code == null || isLoading)
                    ? null
                    : () => Share.share(
                          'Join STARQ with my referral code $code! We both get 100 points after your first completed paid booking: https://starq.in',
                        ),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RewardsColors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(110, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RewardsColors.softPink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.card_giftcard,
                  size: 20,
                  color: RewardsColors.red,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 12),
                      children: [
                        TextSpan(text: 'You and your friend both get '),
                        TextSpan(
                          text: '100 points',
                          style: TextStyle(
                            color: RewardsColors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' when they complete their first paid booking.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (summary != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Referral Progress',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatChip(
                  label: 'Invited',
                  value: '${summary.totalReferrals}',
                  color: Colors.blue.shade50,
                  textColor: Colors.blue.shade800,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Completed',
                  value: '${summary.successfulReferrals}',
                  color: Colors.green.shade50,
                  textColor: Colors.green.shade800,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Pending',
                  value: '${summary.pendingReferrals}',
                  color: Colors.orange.shade50,
                  textColor: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Earned',
                  value: '${summary.totalPointsEarned} pts',
                  color: RewardsColors.lightPink,
                  textColor: RewardsColors.red,
                ),
              ],
            ),
            if (summary.referrals.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...summary.referrals.map((r) => _ReferralTile(item: r)),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color textColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: textColor.withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralTile extends StatelessWidget {
  final ReferralItem item;
  const _ReferralTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isRewarded = item.status == 'REWARDED';
    final dateStr = DateFormat('dd MMM yyyy').format(item.createdAt);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                isRewarded ? Colors.green.shade100 : Colors.orange.shade100,
            child: Icon(
              isRewarded ? Icons.check_circle_outline : Icons.schedule,
              size: 16,
              color: isRewarded ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.refereeName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (item.refereePhoneMasked != null)
                  Text(
                    item.refereePhoneMasked!,
                    style: const TextStyle(
                        fontSize: 11, color: RewardsColors.textGrey),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRewarded
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isRewarded ? '+100 pts' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isRewarded
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 10, color: RewardsColors.textGrey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PointsHistorySection extends StatelessWidget {
  const _PointsHistorySection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RewardsProvider>();
    final history = provider.history;
    final isLoading = provider.isLoadingHistory && history.isEmpty;
    final error = provider.historyError;

    return _SectionCard(
      icon: Icons.history,
      title: 'Points History',
      subtitle: 'Your recent earnings, redemptions and expirations.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: RewardsColors.red),
              ),
            )
          else if (error != null && history.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: RewardsColors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(
                          color: RewardsColors.red, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => provider.loadHistory(),
                    child: const Text('Retry',
                        style: TextStyle(
                            color: RewardsColors.red,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else if (history.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No points transactions yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Complete your first wash or invite friends to start earning points.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: RewardsColors.textGrey),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final item = history[index];
                return _HistoryRow(item: item);
              },
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final PointsEntry item;
  const _HistoryRow({required this.item});

  IconData _iconForType(String type) {
    switch (type) {
      case 'earned_referral':
        return Icons.people_outline;
      case 'earned_service':
        return Icons.local_car_wash_outlined;
      case 'redeemed':
        return Icons.shopping_bag_outlined;
      case 'expired':
        return Icons.timer_off_outlined;
      default:
        return Icons.stars_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = item.points > 0;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(item.date);
    final expiryStr = item.expiresAt != null
        ? DateFormat('dd MMM yyyy').format(item.expiresAt!)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCredit ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _iconForType(item.type),
            size: 20,
            color: isCredit ? Colors.green.shade700 : RewardsColors.red,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.note.isNotEmpty ? item.note : item.type.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 11, color: RewardsColors.textGrey)),
              if (expiryStr != null && isCredit) ...[
                const SizedBox(height: 2),
                Text(
                  'Expires: $expiryStr',
                  style: TextStyle(
                      fontSize: 10, color: Colors.orange.shade800),
                ),
              ],
            ],
          ),
        ),
        Text(
          isCredit ? '+${item.points} pts' : '${item.points} pts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isCredit ? Colors.green.shade700 : RewardsColors.red,
          ),
        ),
      ],
    );
  }
}

class _RateAndEarnCard extends StatelessWidget {
  final VoidCallback onRateService;
  final VoidCallback onRateApp;

  const _RateAndEarnCard({
    required this.onRateService,
    required this.onRateApp,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.star_border,
      title: 'Rate & Earn',
      subtitle: 'Your feedback helps us improve!',
      child: Column(
        children: [
          _RateRow(
            icon: Icons.chat_bubble_outline,
            iconColor: RewardsColors.red,
            title: 'Rate a completed service',
            subtitle: 'Get 5 points for every service rating.',
            buttonText: 'Rate Now',
            onPressed: onRateService,
          ),
          const SizedBox(height: 10),
          _RateRow(
            icon: Icons.play_arrow_rounded,
            iconColor: Colors.green,
            title: 'Rate the STARQ app on Play Store',
            subtitle: 'Get 5 points (one time only).',
            buttonText: 'Rate App',
            onPressed: onRateApp,
          ),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _RateRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RewardsColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: RewardsColors.lightPink,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: RewardsColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: RewardsColors.red,
              side: const BorderSide(color: RewardsColors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
