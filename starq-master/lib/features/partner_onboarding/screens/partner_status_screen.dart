import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/starq_logo.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/partner_application_repository.dart';

class PartnerStatusScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const PartnerStatusScreen({super.key, this.initialData});

  @override
  State<PartnerStatusScreen> createState() => _PartnerStatusScreenState();
}

class _PartnerStatusScreenState extends State<PartnerStatusScreen> {
  late final PartnerApplicationRepository _repository;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _statusData;

  @override
  void initState() {
    super.initState();
    _repository = PartnerApplicationRepository(context.read<ApiClient>());
    if (widget.initialData != null) {
      _statusData = widget.initialData;
      _isLoading = false;
    } else {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repository.fetchStatus();
      if (!mounted) return;
      setState(() {
        _statusData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  void _enterPartnerDashboard() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.switchMode('PARTNER');
    if (!mounted) return;
    if (ok) {
      context.go('/partner-dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Failed to switch to Partner mode')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const StarqLogo(height: 24),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            onPressed: _loadStatus,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
            : _error != null
                ? _buildErrorView()
                : _buildContent(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 14),
            Text(
              _error ?? 'Failed to load status',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14.5, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadStatus,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final status = _statusData?['status']?.toString().toUpperCase() ?? 'PENDING_VERIFICATION';
    final appId = _statusData?['applicationId']?.toString() ?? 'STQ-APP-PENDING';
    final rejectionReason = _statusData?['rejectionReason']?.toString();

    switch (status) {
      case 'APPROVED':
        return _buildApprovedView(appId);
      case 'REJECTED':
        return _buildRejectedView(appId, rejectionReason);
      case 'SUSPENDED':
        return _buildSuspendedView(appId);
      case 'PENDING_VERIFICATION':
      default:
        return _buildPendingView(appId);
    }
  }

  Widget _buildPendingView(String appId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 44),
            ),
            const SizedBox(height: 24),
            Text(
              'Application Under Review',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Text(
              'Your STARQ Service Partner application is under verification. Our team will review your details.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14.5, color: const Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Application ID: ', style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                  Text(appId, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
            ),
            const SizedBox(height: 36),
            OutlinedButton(
              onPressed: () => context.go('/home'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              child: Text(
                'Continue in Customer Mode',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedView(String appId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Congratulations!',
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            Text(
              'Your STARQ Service Partner account has been approved.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: _enterPartnerDashboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                'Enter Partner Dashboard',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => context.go('/home'),
              child: Text(
                'Continue in Customer Mode',
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedView(String appId, String? reason) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'Application Needs Correction',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reason provided by operations team:', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF991B1B))),
                  const SizedBox(height: 6),
                  Text(
                    reason ?? 'Please re-upload a clearer copy of your identity proof.',
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => context.push('/partner-onboarding'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                'Edit & Resubmit Application',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to Home', style: TextStyle(color: Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuspendedView(String appId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.block, color: Color(0xFFDC2626), size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Account Suspended',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Text(
              'Your STARQ Service Partner access has been suspended. Please contact partner support for assistance.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14.5, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => context.go('/home'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Continue in Customer Mode', style: TextStyle(color: Color(0xFF0F172A))),
            ),
          ],
        ),
      ),
    );
  }
}
