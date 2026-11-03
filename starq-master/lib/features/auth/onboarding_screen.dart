import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/core/widgets/starq_logo.dart';
import 'package:starq_app/app/theme/app_theme.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/onbording_picture.png',
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: const Color(0xFF1A1A1A),
                    child: const Center(
                      child: Icon(Icons.local_car_wash,
                          size: 80, color: Colors.white24),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                const StarqLogo.dark(height: 48),
                const SizedBox(height: 12),
                Text(
                  'Premium Car Care At\nYour Doorstep',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subheading.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Get Started',
                  onPressed: () => context.go('/sign-in'),
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: 'Create Account',
                  outlined: true,
                  textColor: Colors.white,
                  borderColor: Colors.white,
                  onPressed: () => context.go('/create-account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}