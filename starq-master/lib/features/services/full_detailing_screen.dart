import 'package:flutter/material.dart';
import 'package:starq_app/core/widgets/service_detail_template.dart';

class FullDetailingScreen extends StatelessWidget {
  final Map<String, dynamic>? data;
  const FullDetailingScreen({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return ServiceDetailTemplate(
      image: 'full_detailing.png',
      title: 'Full Detailing',
      price: '₹2,699',
      duration: '2-3 hrs',
      rating: '4.9',
      serviceId: data?['serviceId'],
      extraData: data,
      description:
          'Complete deep cleaning for interior and exterior including seats shampooing, roof lining, carpets, AC grills, underbody rinse, and engine grille polish.',
      included: const {
        'Platinum Deep Cleaning (Interior + Exterior)': [
          'Seats Shampooing & Vacuuming',
          'Roof Lining Cleaning',
          'Floor & Carpet + Mats Cleaning',
          'Dashboard, Console & AC Grills',
          'Door Panels & Trims Detailed',
          'Trunk / Stepney Area Cleaning',
          'AC Vents & Hidden Corners',
          'Germ & Odor Removal',
          'High-Pressure Foam Wash',
          'Tyres, Alloys & Fender Cleaning',
          'Underbody Rinse',
          'Glass & Mirrors (Both Sides)',
          'Silver Trims & Engine Grille Polished',
          'Final Dry & Shine Finish',
        ],
      },
    );
  }
}