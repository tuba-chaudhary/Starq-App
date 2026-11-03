import 'package:flutter/material.dart';
import 'package:starq_app/core/widgets/service_detail_template.dart';

class PressureWashScreen extends StatelessWidget {
  final Map<String, dynamic>? data;
  const PressureWashScreen({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return ServiceDetailTemplate(
      image: 'Bike_Pressure_Wash.png',
      title: 'Pressure Wash',
      price: '₹399',
      duration: '30 min',
      rating: '4.8',
      serviceId: data?['serviceId'],
      extraData: data,
      description:
          'High-pressure water jet wash that removes tough dirt and grime from every corner of the bike.',
      included: const {
        'Included Services': [
          'High-pressure rinse',
          'Wheel & tyre cleaning',
          'Chain & engine cleaning',
          'Seat & mirror cleaning',
          'Hand dry & polish',
        ],
      },
    );
  }
}