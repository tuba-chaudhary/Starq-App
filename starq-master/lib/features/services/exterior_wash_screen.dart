import 'package:flutter/material.dart';
import 'package:starq_app/core/widgets/service_detail_template.dart';

class ExteriorWashScreen extends StatelessWidget {
  final Map<String, dynamic>? data;
  const ExteriorWashScreen({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return ServiceDetailTemplate(
      image: 'exterior_wash.png',
      title: 'Exterior Wash',
      price: '₹399',
      duration: '45 min',
      rating: '4.8',
      serviceId: data?['serviceId'],
      extraData: data,
      description:
          'Exterior foam wash, tyre & wheel cleaning, pressure rinse, towel dry, final microfiber wipe-down, and mirror & glass cleaning (exterior only).',
      included: const {
        'Silver — Basic Wash Inclusions': [
          'Exterior foam wash',
          'Tyre & wheel cleaning',
          'Pressure rinse',
          'Towel dry',
          'Final microfiber wipe-down',
          'Mirror & glass cleaning (exterior only)',
        ],
      },
    );
  }
}