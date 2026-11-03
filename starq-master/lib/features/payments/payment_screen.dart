import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/app/theme/app_theme.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic>? data;
  const PaymentScreen({super.key, this.data});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _selected = 0;

  final _methods = const [
    {'icon': Icons.bolt, 'title': 'UPI', 'subtitle': 'PhonePe, GPay, Paytm'},
    {
      'icon': Icons.credit_card,
      'title': 'CREDIT / DEBIT CARD',
      'subtitle': 'Visa, Mastercard, Rupay'
    },
    {
      'icon': Icons.account_balance,
      'title': 'NET BANKING',
      'subtitle': 'All major banks supported'
    },
    {
      'icon': Icons.account_balance_wallet,
      'title': 'WALLETS',
      'subtitle': 'Paytm, Amazon Pay, Freecharge'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final total = widget.data?['total'] ?? 279;
    final serviceTitle = widget.data?['serviceTitle'] ?? 'Exterior Wash';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back_ios_new,
                        size: 18, color: AppColors.textDark),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment', style: AppTextStyles.subheading),
                      Text('choose payment method', style: AppTextStyles.body),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text('TOTAL AMOUNT',
                              style: AppTextStyles.body
                                  .copyWith(fontSize: 12, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Text('₹$total',
                              style: AppTextStyles.heading
                                  .copyWith(fontSize: 32, color: AppColors.primary)),
                          const SizedBox(height: 6),
                          Text(serviceTitle.toString().toUpperCase(),
                              style: AppTextStyles.body.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('PAYMENT METHODS',
                        style: AppTextStyles.body
                            .copyWith(fontSize: 11, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    ...List.generate(_methods.length, (i) {
                      final m = _methods[i];
                      final selected = i == _selected;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: HoverCard(
                          onTap: () => setState(() => _selected = i),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primaryLight.withOpacity(0.25)
                                  : Colors.white,
                              border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: selected ? 1.5 : 1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(m['icon'] as IconData,
                                      color: selected ? Colors.white : AppColors.textDark,
                                      size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m['title'] as String,
                                          style: AppTextStyles.subheading
                                              .copyWith(fontSize: 14)),
                                      Text(m['subtitle'] as String,
                                          style: AppTextStyles.body),
                                    ],
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color:
                                      selected ? AppColors.primary : Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, size: 14, color: AppColors.textLight),
                          const SizedBox(width: 6),
                          Text('100% SECURE PAYMENT',
                              style: AppTextStyles.body
                                  .copyWith(fontSize: 11, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppButton(
                text: 'Pay ₹$total',
                trailingIcon: Icons.arrow_forward,
                onPressed: () => context.push('/order-confirmed'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}