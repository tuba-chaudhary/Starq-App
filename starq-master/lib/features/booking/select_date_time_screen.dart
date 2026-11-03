import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/app/theme/app_theme.dart';

class SelectDateTimeScreen extends StatefulWidget {
  final Map<String, dynamic>? data;
  const SelectDateTimeScreen({super.key, this.data});

  @override
  State<SelectDateTimeScreen> createState() => _SelectDateTimeScreenState();
}

class _SelectDateTimeScreenState extends State<SelectDateTimeScreen> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;
  String? _selectedTime;

  static const _timeSlots = [
    '08:00 AM', '09:00 AM', '10:00 AM',
    '11:00 AM', '01:00 PM', '03:00 PM', '05:00 PM',
  ];

  List<DateTime?> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysBefore = first.weekday - 1; // Monday = 0 offset
    final totalDays = DateTime(month.year, month.month + 1, 0).day;
    return [
      ...List.filled(daysBefore, null),
      ...List.generate(totalDays, (i) => DateTime(month.year, month.month, i + 1)),
    ];
  }

  void _continue() {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }
    final combined = {
      ...?widget.data,
      'date': _selectedDate,
      'time': _selectedTime,
    };
    context.push('/choose-location', extra: combined);
  }

  @override
  Widget build(BuildContext context) {
    final serviceTitle = widget.data?['serviceTitle'] ?? 'Service';
    final servicePrice = widget.data?['servicePrice'] ?? '';
    final days = _daysInMonth(_visibleMonth);
    const weekdayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

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
                      Text('Select Date & Time', style: AppTextStyles.subheading),
                      Text('$serviceTitle · $servicePrice', style: AppTextStyles.body),
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
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setState(() => _visibleMonth =
                              DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
                        ),
                        Text(
                          '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                          style: AppTextStyles.subheading,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setState(() => _visibleMonth =
                              DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
                        ),
                      ],
                    ),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: weekdayLabels
                          .map((d) => Center(
                                child: Text(d,
                                    style: AppTextStyles.body.copyWith(fontSize: 11)),
                              ))
                          .toList(),
                    ),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: days.map((day) {
                        if (day == null) return const SizedBox();
                        final isSelected = _selectedDate != null &&
                            _selectedDate!.year == day.year &&
                            _selectedDate!.month == day.month &&
                            _selectedDate!.day == day.day;
                        final isPast = day
                            .isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
                        return GestureDetector(
                          onTap: isPast ? null : () => setState(() => _selectedDate = day),
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                color: isPast
                                    ? Colors.grey.shade300
                                    : isSelected
                                        ? Colors.white
                                        : AppColors.textDark,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 18, color: AppColors.textDark),
                          const SizedBox(width: 6),
                          Text('Select Time', style: AppTextStyles.subheading.copyWith(fontSize: 15)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _timeSlots.map((slot) {
                        final selected = slot == _selectedTime;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTime = slot),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary : Colors.white,
                              border: Border.all(
                                  color: selected ? AppColors.primary : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              slot,
                              style: TextStyle(
                                  color: selected ? Colors.white : AppColors.textDark),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Flexible Rescheduling',
                                    style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark)),
                                Text(
                                  'Reschedule your service up to 4 hours before the appointment at no extra cost.',
                                  style: AppTextStyles.body,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppButton(text: 'CONTINUE', onPressed: _continue),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month - 1];
  }
}