import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/core/widgets/starq_logo.dart';
import 'package:starq_app/core/widgets/bottom_nav_bar.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:starq_app/features/providers/rewards_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().fetchMe();
        context.read<RewardsProvider>().loadSummary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final rewardsProvider = context.watch<RewardsProvider>();
    final summary = rewardsProvider.summary;

    final menuItems = [
      if (user?.isApprovedPartner == true)
        {
          'icon': Icons.swap_horiz_rounded,
          'title': 'Switch to Partner Mode',
          'subtitle': 'Manage your service jobs',
          'action': 'switch_to_partner',
        }
      else if (user?.partnerApplication != null)
        {
          'icon': Icons.assignment_outlined,
          'title': 'Partner Application Status',
          'subtitle': 'Status: ${user!.partnerApplication!['status'] ?? 'Under Review'}',
          'route': '/partner-status',
        }
      else
        {
          'icon': Icons.handyman_outlined,
          'title': 'Join as Service Partner',
          'subtitle': 'Register to provide services with STARQ',
          'route': '/partner-onboarding',
        },
      {
        'icon': Icons.directions_car_outlined,
        'title': 'My Garage',
        'subtitle': 'Vehicles & preferences',
        'route': '/my-garage'
      },
      {
        'icon': Icons.map_outlined,
        'title': 'Saved Addresses',
        'subtitle': 'Manage service locations',
        'route': '/saved-addresses'
      },
      {
        'icon': Icons.event_available_outlined,
        'title': 'Past Bookings',
        'subtitle': 'Active & completed orders',
        'route': '/bookings'
      },
      {
        'icon': Icons.star_border,
        'title': 'STARQ Rewards',
        'subtitle': summary != null
            ? '${summary.balance} points available · Tap to view'
            : 'Points & vouchers',
        'route': '/rewards',
        'badge': summary != null ? '${summary.balance} pts' : null,
      },
      {
        'icon': Icons.description_outlined,
        'title': 'Terms & Conditions',
        'subtitle': 'Legal agreement',
        'route': '/legal-terms'
      },
      {
        'icon': Icons.privacy_tip_outlined,
        'title': 'Privacy Policy',
        'subtitle': 'Data protection',
        'route': '/legal-privacy'
      },
      {
        'icon': Icons.refresh_outlined,
        'title': 'Cancellation & Refund',
        'subtitle': 'Policy details',
        'route': '/legal-refund'
      },
      {
        'icon': Icons.delete_forever_outlined,
        'title': 'Delete Account',
        'subtitle': 'Account data removal',
        'action': 'delete_account'
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back_ios_new,
                        size: 18, color: AppColors.textDark),
                  ),
                  Text('Profile', style: AppTextStyles.subheading),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (user?.fullName != null && user!.fullName.isNotEmpty) ? user.fullName : 'User',
                            style: AppTextStyles.subheading
                                .copyWith(color: Colors.white, fontSize: 18),
                          ),
                          if (user?.email != null && user!.email.isNotEmpty)
                            Text(user.email,
                                style:
                                    AppTextStyles.body.copyWith(color: Colors.white70)),
                          if (user?.phone != null && user!.phone!.isNotEmpty)
                            Text(user.phone!,
                                style:
                                    AppTextStyles.body.copyWith(color: Colors.white70)),
                          if (user?.referralCode != null && user!.referralCode!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Referral: ${user.referralCode}',
                                  style: AppTextStyles.body.copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Edit', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...menuItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: HoverCard(
                      onTap: () async {
                        final action = item['action'] as String?;
                        if (action == 'switch_to_partner') {
                          final ok = await authProvider.switchMode('PARTNER');
                          if (context.mounted) {
                            if (ok) {
                              context.go('/partner-dashboard');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(authProvider.error ?? 'Failed to switch to Partner mode')),
                              );
                            }
                          }
                          return;
                        }
                        if (action == 'delete_account') {
                          final confirm = await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Account'),
                              content: const Text(
                                  'Are you sure you want to delete your account? This action cannot be undone. Financial records will be retained as required by law.'),
                              actions: [
                                TextButton(
                                    onPressed: () => ctx.pop(false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => ctx.pop(true),
                                    child: const Text('Delete',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final success = await authProvider.deleteAccount();
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Account deleted')));
                              context.go('/onboarding');
                            }
                          }
                          return;
                        }
                        final route = item['route'] as String?;
                        if (route != null) {
                          await context.push(route);
                          // Refresh balance when returning to profile
                          if (context.mounted) {
                            context.read<RewardsProvider>().loadSummary();
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('coming soon')),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(item['icon'] as IconData,
                                color: AppColors.primary),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['title'] as String,
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700)),
                                  Text(item['subtitle'] as String,
                                      style: AppTextStyles.body),
                                ],
                              ),
                            ),
                            if (item['badge'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item['badge'] as String,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
              const Center(child: StarqLogo(height: 24)),
              const SizedBox(height: 6),
              Center(
                child: Text('STARQ Premium Vehicle Care • v1.0.0',
                    style: AppTextStyles.body
                        .copyWith(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Log out',
                trailingIcon: Icons.logout,
                onPressed: () {
                  context.read<RewardsProvider>().clear();
                  authProvider.logout();
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(
        currentIndex: 3,
        items: customerNavItems,
      ),
    );
  }
}