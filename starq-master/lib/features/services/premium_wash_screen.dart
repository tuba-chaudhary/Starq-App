import 'package:flutter/material.dart';
import 'package:starq_app/core/widgets/service_detail_template.dart';

class PremiumWashScreen extends StatelessWidget {
  final Map<String, dynamic>? data;
  const PremiumWashScreen({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return ServiceDetailTemplate(
      image: 'premium_wash.png',
      title: 'Premium Wash',
      price: '₹1,099',
      duration: '90 min',
      serviceId: data?['serviceId'],
      extraData: data,
      description:
          'Everything included in Gold, PLUS: underbody wash, tyre polish & shine, full boot vacuum & cleaning, air freshener, and special care for every corner and final detail.',
      included: const {
        'Base Package (Gold Deluxe Wash)': [
          'Exterior foam wash',
          'Tyre & wheel cleaning',
          'Pressure rinse',
          'Towel dry',
          'Final microfiber wipe-down',
          'Mirror & glass cleaning (exterior only)',
          'Interior vacuum (seats, mats & boot)',
          'Dashboard, console & door panel wipe',
          'Inside glass & mirror cleaning',
          'Scented air freshener spray',
        ],
        'Premium Wash Additions': [
          'Underbody wash',
          'Tyre polish & shine',
          'Full boot vacuum & cleaning',
          'Air freshener',
          'Special care for every corner and final detail',
        ],
      },
    );
  }
}