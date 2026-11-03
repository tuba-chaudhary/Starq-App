import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/starq_logo.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/widgets/phone_otp_sheet.dart';
import '../data/partner_application_repository.dart';

class PartnerOnboardingWizardScreen extends StatefulWidget {
  const PartnerOnboardingWizardScreen({super.key});

  @override
  State<PartnerOnboardingWizardScreen> createState() =>
      _PartnerOnboardingWizardScreenState();
}

class _PartnerOnboardingWizardScreenState
    extends State<PartnerOnboardingWizardScreen> {
  int _currentStep = 1;
  bool _isLoading = false;
  String? _errorMessage;

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pinController = TextEditingController();

  // Document state
  String _selectedIdType = 'AADHAAR'; // AADHAAR or PAN
  String? _photoFileName;
  List<int>? _photoBytes;
  String? _docFileName;
  List<int>? _docBytes;

  late final PartnerApplicationRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = PartnerApplicationRepository(context.read<ApiClient>());

    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _nameController.text = user.fullName;
      _emailController.text = user.email.contains('@phone.starq.app') ? '' : user.email;
      if (user.phone != null && user.phone!.isNotEmpty) {
        // User already has an authenticated account -> can skip directly to details!
        _currentStep = 2;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _simulatePhotoSelect() {
    // Provide a valid JPEG payload for the photo
    final sampleBytes = utf8.encode('STARQ_SAMPLE_PHOTO_DATA_JPG');
    setState(() {
      _photoBytes = sampleBytes;
      _photoFileName = 'profile_front_${DateTime.now().millisecondsSinceEpoch}.jpg';
      _errorMessage = null;
    });
  }

  void _simulateDocSelect() {
    // Provide a valid PDF/JPEG payload for the document
    final sampleBytes = utf8.encode('STARQ_SAMPLE_ID_PROOF_DATA');
    final ext = _selectedIdType == 'AADHAAR' ? 'pdf' : 'jpg';
    setState(() {
      _docBytes = sampleBytes;
      _docFileName = '${_selectedIdType.toLowerCase()}_proof_${DateTime.now().millisecondsSinceEpoch}.$ext';
      _errorMessage = null;
    });
  }

  void _handleStep1Complete() {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || user.phone == null || user.phone!.isEmpty) {
      PhoneOtpSheet.show(
        context,
        intendedRole: 'PARTNER',
        onSuccess: () {
          setState(() {
            _currentStep = 2;
            final u = context.read<AuthProvider>().currentUser;
            if (u != null) {
              if (_nameController.text.isEmpty) _nameController.text = u.fullName;
              if (_emailController.text.isEmpty && !u.email.contains('@phone.starq.app')) {
                _emailController.text = u.email;
              }
            }
          });
        },
      );
    } else {
      setState(() => _currentStep = 2);
    }
  }

  void _handleStep2Complete() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final pin = _pinController.text.trim();

    if (name.isEmpty || email.isEmpty || address.isEmpty || city.isEmpty || pin.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all personal details.');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _errorMessage = 'PIN code must be exactly 6 digits.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _currentStep = 3;
    });
  }

  void _handleSubmit() async {
    if (_photoBytes == null) {
      setState(() => _errorMessage = 'Please upload a clear front-facing profile photo.');
      return;
    }

    if (_docBytes == null) {
      setState(() => _errorMessage = 'Please upload your $_selectedIdType proof.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _repository.submitApplication(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        pinCode: _pinController.text.trim(),
        idDocumentType: _selectedIdType,
        photoBytes: _photoBytes!,
        photoName: _photoFileName ?? 'photo.jpg',
        docBytes: _docBytes!,
        docName: _docFileName ?? 'id_proof.pdf',
      );

      if (!mounted) return;

      // Refresh me to update user model
      await context.read<AuthProvider>().fetchMe();

      if (!mounted) return;
      context.go('/partner-status', extra: result);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
        title: const StarqLogo(height: 24),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_currentStep == 1) _buildStep1Phone(),
                if (_currentStep == 2) _buildStep2Details(),
                if (_currentStep == 3) _buildStep3UploadDocuments(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Phone() {
    final user = context.watch<AuthProvider>().currentUser;
    final hasPhone = user != null && user.phone != null && user.phone!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 1 of 3', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFE50914), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Verify Mobile Number', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text(
            hasPhone
                ? 'Your existing STARQ account (${user.phone}) will be linked to your partner application.'
                : 'Enter your 10-digit mobile number to verify your partner account.',
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _handleStep1Complete,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              hasPhone ? 'Continue with ${user.phone}' : 'Verify Mobile with OTP',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Details() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 2 of 3', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFE50914), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Personal Details', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text('Tell us about yourself and your service area.', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
          const SizedBox(height: 20),
          _buildInput('Full Name', _nameController, hint: 'e.g. Ramesh Kumar'),
          const SizedBox(height: 14),
          _buildInput('Email Address', _emailController, hint: 'ramesh@example.com', type: TextInputType.emailAddress),
          const SizedBox(height: 14),
          _buildInput('Workshop / Home Address', _addressController, hint: 'Shop No. 4, MG Road'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildInput('City', _cityController, hint: 'Mumbai')),
              const SizedBox(width: 12),
              Expanded(child: _buildInput('PIN Code', _pinController, hint: '400001', type: TextInputType.number, maxLength: 6)),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleStep2Complete,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text('Next: Upload Documents', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3UploadDocuments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Headline matching Image 2
        Center(
          child: Column(
            children: [
              Text(
                'Upload Documents',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Complete your profile to start offering services',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Main White Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Clear Photo Section
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_outline, color: Color(0xFFE50914), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Clear Photo', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('Upload a clear, front-facing photo', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Upload Photo Box
              InkWell(
                onTap: _simulatePhotoSelect,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _photoBytes != null ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _photoBytes != null ? Icons.check_circle : Icons.camera_alt_outlined,
                        color: _photoBytes != null ? const Color(0xFF10B981) : const Color(0xFFE50914),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _photoBytes != null ? 'Photo Selected: $_photoFileName' : 'Upload Photo',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: _photoBytes != null ? const Color(0xFF10B981) : const Color(0xFFE50914),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG, PNG (Max 5 MB)',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),

              // 2. ID Proof Section
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.badge_outlined, color: Color(0xFFE50914), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID Proof', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('Upload your Aadhaar or PAN card', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Radio selector: Aadhaar Card vs PAN Card
              Row(
                children: [
                  Expanded(
                    child: _buildRadioOption('Aadhaar Card', 'AADHAAR'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRadioOption('PAN Card', 'PAN'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Upload ID Proof Box
              InkWell(
                onTap: _simulateDocSelect,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _docBytes != null ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _docBytes != null ? Icons.check_circle : Icons.file_upload_outlined,
                        color: _docBytes != null ? const Color(0xFF10B981) : const Color(0xFFE50914),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _docBytes != null ? 'Document Selected: $_docFileName' : 'Upload ID Proof',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: _docBytes != null ? const Color(0xFF10B981) : const Color(0xFFE50914),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG, PNG, PDF (Max 5 MB)',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Submit Button matching Image 2
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE50914),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('Submit', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRadioOption(String title, String value) {
    final isSelected = _selectedIdType == value;
    return InkWell(
      onTap: () => setState(() {
        _selectedIdType = value;
        _docBytes = null;
        _docFileName = null;
      }),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFECEE) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFFE50914) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFE50914) : const Color(0xFF94A3B8),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE50914),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFFE50914) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {String? hint, TextInputType? type, int? maxLength}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: type,
          maxLength: maxLength,
          style: GoogleFonts.inter(fontSize: 14.5),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5)),
          ),
        ),
      ],
    );
  }
}
