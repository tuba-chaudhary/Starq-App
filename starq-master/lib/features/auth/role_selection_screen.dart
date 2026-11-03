import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starq_app/core/widgets/starq_logo.dart';
import 'package:starq_app/app/theme/app_theme.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const StarqLogo(fontSize: 36),
              const SizedBox(height: 28),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.subheading.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    height: 1.25,
                  ),
                  children: const [
                    TextSpan(text: 'How would you like\nto use '),
                    TextSpan(
                      text: 'STARQ',
                      style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.w900),
                    ),
                    TextSpan(text: '?'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose your role to get started',
                style: AppTextStyles.body.copyWith(
                  color: const Color(0xFF64748B),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 36),
              _RoleCard(
                icon: Icons.directions_car_filled_outlined,
                title: "I'm a Customer",
                subtitle: 'Book professional car care at your doorstep',
                onTap: () => context.push('/sign-in'),
              ),
              const SizedBox(height: 18),
              _RoleCard(
                icon: Icons.person_pin_outlined,
                title: "I'm a Service Provider",
                subtitle: 'Provide car wash services and earn with STARQ',
                onTap: () => context.push('/partner-onboarding'),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEDED),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFFE50914),
                size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.subheading.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF0F172A),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}