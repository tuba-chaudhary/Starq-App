import 'package:flutter/material.dart';
import 'package:starq_app/features/rewards/data/rewards_repository.dart';
import 'package:starq_app/features/rewards/domain/rewards_model.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/bottom_nav_bar.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final _repo = RewardsRepository();
  RewardAccount? _account;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final account = await _repo.load();
      if (mounted) setState(() => _account = account);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('STARQ Points')),
      body: account == null
          ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Balance', style: AppTextStyles.body.copyWith(color: Colors.white70)),
                      Text('${account.totalBalance}', style: AppTextStyles.heading.copyWith(color: Colors.white, fontSize: 36)),
                      Text('Auditable ledger — not a hidden mutable number', style: AppTextStyles.body.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Redeem', style: AppTextStyles.subheading),
                ...account.rewards.map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.name),
                      subtitle: Text('${r.description} · ${r.pointsCost} pts'),
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            await _repo.redeem(r.id);
                            await _load();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                            }
                          }
                        },
                        child: const Text('Redeem'),
                      ),
                    )),
                const SizedBox(height: 12),
                Text('Ledger', style: AppTextStyles.subheading),
                ...account.transactions.map((t) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.description),
                      subtitle: Text(t.createdAt.toLocal().toString()),
                      trailing: Text(t.pointsDelta > 0 ? '+${t.pointsDelta}' : '${t.pointsDelta}',
                          style: TextStyle(color: t.pointsDelta > 0 ? Colors.green : AppColors.primary, fontWeight: FontWeight.bold)),
                    )),
              ],
            ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2, items: customerNavItems),
    );
  }
}
