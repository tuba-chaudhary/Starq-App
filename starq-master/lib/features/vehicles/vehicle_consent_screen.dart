import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/core/widgets/custom_text_field.dart';

class VehicleConsentScreen extends StatefulWidget {
  const VehicleConsentScreen({super.key});

  @override
  State<VehicleConsentScreen> createState() => _VehicleConsentScreenState();
}

class _VehicleConsentScreenState extends State<VehicleConsentScreen> {
  final _notes = TextEditingController();
  bool _ack = false;
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _version = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await context.read<BookingFlowProvider>().repository.currentConsent();
    if (mounted) setState(() {
      _version = data;
      _loading = false;
    });
  }

  Future<void> _continue() async {
    final flow = context.read<BookingFlowProvider>();
    if (!_ack || flow.vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acknowledge the consent to continue')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      flow.consentId = await flow.repository.submitConsent(
        vehicleId: flow.vehicle!.id,
        notes: _notes.text.trim(),
        consentVersionId: _version['id']?.toString() ?? '',
      );
      flow.damageNotes = _notes.text.trim();
      final ok = await flow.refreshQuote();
      if (!mounted) return;
      if (ok) {
        context.push('/booking-summary');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(flow.error ?? 'Quote failed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Vehicle condition')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(_version['title']?.toString() ?? 'Consent', style: AppTextStyles.subheading),
                const SizedBox(height: 8),
                Text(
                  'Legal review status: ${_version['legal_review_status'] ?? 'MARKED_FOR_LEGAL_REVIEW'}',
                  style: AppTextStyles.body.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(_version['body']?.toString() ?? '', style: AppTextStyles.body),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'Existing damage, marks, stains, chips or dents',
                  controller: _notes,
                ),
                CheckboxListTile(
                  value: _ack,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I acknowledge the recorded condition of my vehicle for this booking.'),
                  onChanged: (v) => setState(() => _ack = v ?? false),
                ),
                const SizedBox(height: 12),
                AppButton(text: 'Agree and view summary', isLoading: _saving, onPressed: _continue),
              ],
            ),
    );
  }
}
