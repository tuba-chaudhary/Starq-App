import 'package:flutter/material.dart';
import 'package:starq_app/core/widgets/service_detail_template.dart';

class BucketWashScreen extends StatelessWidget {
  final Map<String, dynamic>? data;
  const BucketWashScreen({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return ServiceDetailTemplate(
      image: 'Bike_Bucket_wash.png',
      title: 'Bucket Wash',
      price: '₹299',
      duration: '20 min',
      rating: '4.7',
      serviceId: data?['serviceId'],
      extraData: data,
      description:
          'A quick and thorough manual wash using bucket and soap. Perfect for regular upkeep and everyday grime.',
      included: const {
        'Included Services': [
          'Bucket foam wash',
          'Wheel & tyre cleaning',
          'Chain cleaning',
          'Seat wipe down',
          'Hand dry',
        ],
      },
    );
  }
}