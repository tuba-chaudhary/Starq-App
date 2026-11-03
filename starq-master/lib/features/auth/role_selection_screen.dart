import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/core/widgets/starq_logo.dart';
import 'package:starq_app/app/theme/app_theme.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const StarqLogo(fontSize: 34),
              const SizedBox(height: 24),
              Text(
                'How would you like\nto use STARQ?',
                textAlign: TextAlign.center,
                style: AppTextStyles.subheading.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text('Choose your role to get started', style: AppTextStyles.body),
              const SizedBox(height: 32),
              _RoleCard(
                icon: Icons.directions_car,
                title: "I'm a Customer",
                subtitle: 'Book professional car care at your doorstep',
                onTap: () => context.go('/home'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.engineering,
                title: "I'm a Service Provider",
                subtitle: 'Provide car wash services and earn with STARQ',
                onTap: () => context.go('/partner'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primaryLight,
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.subheading.copyWith(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.body),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}