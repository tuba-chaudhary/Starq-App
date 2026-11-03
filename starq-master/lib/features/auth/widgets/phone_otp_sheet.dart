import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../presentation/auth_provider.dart';

class PhoneOtpSheet extends StatefulWidget {
  final String? initialPhone;
  final String intendedRole;
  final VoidCallback? onSuccess;

  const PhoneOtpSheet({
    super.key,
    this.initialPhone,
    this.intendedRole = 'CUSTOMER',
    this.onSuccess,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialPhone,
    String intendedRole = 'CUSTOMER',
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: PhoneOtpSheet(
          initialPhone: initialPhone,
          intendedRole: intendedRole,
          onSuccess: onSuccess,
        ),
      ),
    );
  }

  @override
  State<PhoneOtpSheet> createState() => _PhoneOtpSheetState();
}

class _PhoneOtpSheetState extends State<PhoneOtpSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isOtpSent = false;
  int _resendCountdown = 60;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _handleSendOtp() async {
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit Indian mobile number');
      return;
    }

    setState(() => _errorMessage = null);
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendOtp(phone);
    if (!mounted) return;

    if (ok) {
      setState(() => _isOtpSent = true);
      _startTimer();
    } else {
      setState(() => _errorMessage = auth.error ?? 'Failed to send OTP');
    }
  }

  void _handleVerifyOtp() async {
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit verification code');
      return;
    }

    setState(() => _errorMessage = null);
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(
      phone,
      otp,
      fullName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      intendedRole: widget.intendedRole,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        if (widget.intendedRole == 'PARTNER' && auth.currentUser?.role == 'PARTNER') {
          context.go('/partner-dashboard');
        } else {
          context.go('/home');
        }
      }
    } else {
      setState(() => _errorMessage = auth.error ?? 'Verification failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isOtpSent ? 'Verify Phone' : 'Enter Mobile Number',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isOtpSent
                ? 'Enter the 6-digit code sent to +91 ${_phoneController.text}'
                : 'We will send a 6-digit verification code via SMS.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),

          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFDC2626)),
              ),
            ),

          if (!_isOtpSent) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Text(
                      '+91',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText: 'Mobile Number',
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: auth.isLoading ? null : _handleSendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Get OTP',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ] else ...[
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 10,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isOtpSent = false;
                      _otpController.clear();
                      _errorMessage = null;
                    });
                  },
                  child: Text(
                    'Change Number',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                ),
                TextButton(
                  onPressed: _resendCountdown == 0 ? _handleSendOtp : null,
                  child: Text(
                    _resendCountdown > 0
                        ? 'Resend code in ${_resendCountdown}s'
                        : 'Resend OTP',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _resendCountdown > 0 ? const Color(0xFF94A3B8) : const Color(0xFFE50914),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: auth.isLoading ? null : _handleVerifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Verify & Continue',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
