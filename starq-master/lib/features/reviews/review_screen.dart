import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starq_app/features/booking/data/booking_repository.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/custom_button.dart';

class ReviewScreen extends StatefulWidget {
  final String bookingId;
  const ReviewScreen({super.key, required this.bookingId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _repo = BookingRepository();
  final _comment = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await _repo.submitReview(bookingId: widget.bookingId, rating: _rating, comment: _comment.text.trim());
      if (mounted) context.go('/rewards');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate your wash')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('How was your STARQ service?', style: AppTextStyles.subheading),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => IconButton(
                    onPressed: () => setState(() => _rating = i + 1),
                    icon: Icon(i < _rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                  )),
            ),
            TextField(
              controller: _comment,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Tell us what went well'),
            ),
            const SizedBox(height: 20),
            AppButton(text: 'Submit review', isLoading: _saving, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
