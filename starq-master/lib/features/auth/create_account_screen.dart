import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/utils/validators.dart';
import 'package:starq_app/core/widgets/google_logo.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:starq_app/features/auth/widgets/auth_text_field.dart';
import 'package:starq_app/features/auth/widgets/social_sign_in_button.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();

  bool _obscurePassword = true;
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _referralError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final referralCode = _referralController.text.trim().toUpperCase();

    setState(() {
      _nameError = AppValidators.name(name);
      _emailError = AppValidators.email(email);
      _phoneError = AppValidators.phone(phone);
      _passwordError = AppValidators.password(password);
      if (referralCode.isNotEmpty &&
          !RegExp(r'^STARQ[A-Z0-9]{3,8}$').hasMatch(referralCode)) {
        _referralError = 'Invalid code format (e.g. STARQ123)';
      } else {
        _referralError = null;
      }
    });

    if (_nameError != null ||
        _emailError != null ||
        _phoneError != null ||
        _passwordError != null ||
        _referralError != null) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      name,
      email,
      phone,
      password,
      referralCode: referralCode.isNotEmpty ? referralCode : null,
    );

    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      final errorMsg = authProvider.error ?? 'Registration failed';
      if (errorMsg.toLowerCase().contains('referral')) {
        setState(() => _referralError = errorMsg);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  void _handleSocial(String provider) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.socialLogin(provider);
    if (!mounted) return;
    if (success) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error ?? 'Authentication failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 6),

                  // STARQ Logo - Centered
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 38,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Tagline - Centered (14–16 sp)
                  Center(
                    child: Text(
                      'Join STARQ for premium car care',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // White Rounded Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Centered "Create Account" heading (25–27 sp, bold)
                        Center(
                          child: Text(
                            'Create Account',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Centered "Get started with STARQ" subtitle (14–16 sp)
                        Center(
                          child: Text(
                            'Get started with STARQ',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (authProvider.isServerUnavailable)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    authProvider.error ?? 'Unable to connect to STARQ server.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: const Color(0xFF991B1B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => authProvider.retryInit(),
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                ),
                              ],
                            ),
                          ),

                        // Full Name Field (Height ~52px, Input ~14.5sp)
                        AuthTextField(
                          controller: _nameController,
                          hintText: 'Full Name',
                          prefixIcon: Icons.person_outline_rounded,
                          errorText: _nameError,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 10),

                        // Email Address Field (Height ~52px, Input ~14.5sp)
                        AuthTextField(
                          controller: _emailController,
                          hintText: 'Email Address',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 10),

                        // Phone Number Field (Height ~52px, Input ~14.5sp)
                        AuthTextField(
                          controller: _phoneController,
                          hintText: 'Phone Number',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          errorText: _phoneError,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 10),

                        // Password Field (Height ~52px, Input ~14.5sp)
                        AuthTextField(
                          controller: _passwordController,
                          hintText: 'Password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          errorText: _passwordError,
                          textInputAction: TextInputAction.next,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF475569),
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Referral Code Field (Optional, e.g. STARQ123)
                        AuthTextField(
                          controller: _referralController,
                          hintText: 'Referral Code (Optional)',
                          prefixIcon: Icons.card_giftcard_outlined,
                          errorText: _referralError,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _register(),
                        ),
                        const SizedBox(height: 18),

                        // Create Account CTA Button (Height ~52px, Text 16–17 sp)
                        Material(
                          color: const Color(0xFFE31B38),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: authProvider.isLoading ? null : _register,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Create Account',
                                      style: GoogleFonts.inter(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Divider
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: Color(0xFFE2E8F0),
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                'or continue with',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: Color(0xFFE2E8F0),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Social Buttons Row (Height 48px, Text 15sp)
                        Row(
                          children: [
                            Expanded(
                              child: SocialSignInButton(
                                icon: const GoogleLogo(size: 20),
                                label: 'Google',
                                onTap: () => _handleSocial('google'),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: SocialSignInButton(
                                icon: const Icon(
                                  Icons.apple,
                                  color: Colors.black,
                                  size: 22,
                                ),
                                label: 'Apple',
                                onTap: () => _handleSocial('apple'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Footer (14–15 sp)
                        Center(
                          child: GestureDetector(
                            onTap: () => context.go('/sign-in'),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  color: const Color(0xFF64748B),
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Already have an account? ',
                                  ),
                                  TextSpan(
                                    text: 'Login',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFE31B38),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}