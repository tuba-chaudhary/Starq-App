import 'package:flutter/material.dart';
import 'package:starq_app/core/widgets/service_detail_template.dart';

class InteriorWashScreen extends StatelessWidget {
  final Map<String, dynamic>? data;
  const InteriorWashScreen({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return ServiceDetailTemplate(
      image: 'interior_cleaning.png',
      title: 'Interior Cleaning',
      price: '₹699',
      duration: '60 min',
      serviceId: data?['serviceId'],
      extraData: data,
      description:
          'Everything included in Silver, PLUS: interior vacuum (seats, mats & boot), dashboard, console & door panel wipe, inside glass & mirror cleaning, and scented air freshener spray.',
      included: const {
        'Base Package (Silver Basic Wash)': [
          'Exterior foam wash',
          'Tyre & wheel cleaning',
          'Pressure rinse',
          'Towel dry',
          'Final microfiber wipe-down',
          'Mirror & glass cleaning (exterior only)',
        ],
        'Deluxe Wash Additions': [
          'Interior vacuum (seats, mats & boot)',
          'Dashboard, console & door panel wipe',
          'Inside glass & mirror cleaning',
          'Scented air freshener spray',
        ],
      },
    );
  }
}