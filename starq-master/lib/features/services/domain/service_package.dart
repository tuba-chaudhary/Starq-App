import 'package:starq_app/features/vehicles/domain/vehicle.dart';

enum PackageTier { silver, gold, diamond, platinum }

class ServicePackage {
  final PackageTier tier;
  final String customerName;
  final String subtitle;
  final String backendServiceId;
  final String route;
  final String image;
  final String duration;

  const ServicePackage({
    required this.tier,
    required this.customerName,
    required this.subtitle,
    required this.backendServiceId,
    required this.route,
    required this.image,
    required this.duration,
  });

  String get fullCustomerTitle => '$customerName — $subtitle';

  int? getPrice(VehicleCategory category) {
    switch (category) {
      case VehicleCategory.hatchback:
        switch (tier) {
          case PackageTier.silver:
            return 399;
          case PackageTier.gold:
            return 699;
          case PackageTier.diamond:
            return 1099;
          case PackageTier.platinum:
            return 2699;
        }
      case VehicleCategory.sedan:
        switch (tier) {
          case PackageTier.silver:
            return 599;
          case PackageTier.gold:
            return 799;
          case PackageTier.diamond:
            return 1199;
          case PackageTier.platinum:
            return 3099;
        }
      case VehicleCategory.muv:
        switch (tier) {
          case PackageTier.silver:
            return 699;
          case PackageTier.gold:
            return 899;
          case PackageTier.diamond:
            return 1399;
          case PackageTier.platinum:
            return 3399;
        }
      case VehicleCategory.suv:
        switch (tier) {
          case PackageTier.silver:
            return 799;
          case PackageTier.gold:
            return 999;
          case PackageTier.diamond:
            return 1499;
          case PackageTier.platinum:
            return 3599;
        }
      case VehicleCategory.luxury:
        switch (tier) {
          case PackageTier.silver:
            return null; // Explicitly omitted for Luxury
          case PackageTier.gold:
            return 1899;
          case PackageTier.diamond:
            return 2599;
          case PackageTier.platinum:
            return 5099;
        }
      case VehicleCategory.bike:
        return null;
    }
  }

  String getDescription(VehicleCategory category) {
    if (category == VehicleCategory.luxury) {
      switch (tier) {
        case PackageTier.gold:
          return 'Soft-touch foam wash with luxury paint-safe shampoo, delicate care for ceramic, PPF and matte finishes, with interior leather-safe wipe.';
        case PackageTier.diamond:
          return 'Everything included in Luxury Gold, PLUS underbody wash, tyre polish, alloy finishing and enhanced shine, light scratch reduction, and leather-safe interior conditioning.';
        case PackageTier.platinum:
          return 'Seats shampooing & vacuuming, roof lining, carpet cleaning, dashboard, console & AC grills, underbody rinse, and final dry & shine finish.';
        case PackageTier.silver:
          return '';
      }
    }

    switch (tier) {
      case PackageTier.silver:
        return 'Exterior foam wash, tyre & wheel cleaning, pressure rinse, towel dry, final microfiber wipe-down, and mirror & glass cleaning (exterior only).';
      case PackageTier.gold:
        return 'Everything included in Silver, PLUS: interior vacuum (seats, mats & boot), dashboard, console & door panel wipe, inside glass & mirror cleaning, and scented air freshener spray.';
      case PackageTier.diamond:
        return 'Everything included in Gold, PLUS: underbody wash, tyre polish & shine, full boot vacuum & cleaning, air freshener, and special care for every corner and final detail.';
      case PackageTier.platinum:
        return 'Complete deep cleaning for interior and exterior including seats shampooing, roof lining, carpets, AC grills, underbody rinse, and engine grille polish.';
    }
  }

  /// Returns organized sections of inclusions, clearly indicating base inclusions + additions
  Map<String, List<String>> getInclusions(VehicleCategory category) {
    if (category == VehicleCategory.luxury) {
      switch (tier) {
        case PackageTier.gold:
          return {
            'Luxury Deluxe Wash Inclusions': const [
              'Soft-touch foam wash with luxury paint-safe shampoo',
              'Safe care for ceramic, PPF and matte finishes',
              'Detailed alloy wheel, tyre and wheel-arch cleaning',
              'Pressure rinse and scratch-safe microfiber drying',
              'Interior vacuum for seats, carpets, mats and boot',
              'Leather-safe dashboard, console and door-panel wipe',
              'Door jamb, inside glass and mirror cleaning',
              'Subtle luxury fragrance and final inspection',
            ],
          };
        case PackageTier.diamond:
          return {
            'Base Package (Luxury Gold / Deluxe Wash)': const [
              'Soft-touch foam wash with luxury paint-safe shampoo',
              'Safe care for ceramic, PPF and matte finishes',
              'Detailed alloy wheel, tyre and wheel-arch cleaning',
              'Pressure rinse and scratch-safe microfiber drying',
              'Interior vacuum for seats, carpets, mats and boot',
              'Leather-safe dashboard, console and door-panel wipe',
              'Door jamb, inside glass and mirror cleaning',
              'Subtle luxury fragrance and final inspection',
            ],
            'Premium Diamond Additions': const [
              'Underbody wash',
              'Tyre polish, alloy finishing and enhanced shine',
              'Light scratch reduction and exterior gloss restoration',
              'Leather-safe interior conditioning and surface finishing',
              'Detailed boot vacuum and cleaning',
              'Special attention to corners, trims and final detailing',
            ],
          };
        case PackageTier.platinum:
          return {
            'Platinum Deep Cleaning (Interior + Exterior)': const [
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
          };
        case PackageTier.silver:
          return {};
      }
    }

    // Standard Car categories: Hatchback, Sedan, MUV, SUV
    switch (tier) {
      case PackageTier.silver:
        return {
          'Silver — Basic Wash Inclusions': const [
            'Exterior foam wash',
            'Tyre & wheel cleaning',
            'Pressure rinse',
            'Towel dry',
            'Final microfiber wipe-down',
            'Mirror & glass cleaning (exterior only)',
          ],
        };
      case PackageTier.gold:
        return {
          'Base Package (Silver Basic Wash)': const [
            'Exterior foam wash',
            'Tyre & wheel cleaning',
            'Pressure rinse',
            'Towel dry',
            'Final microfiber wipe-down',
            'Mirror & glass cleaning (exterior only)',
          ],
          'Deluxe Wash Additions': const [
            'Interior vacuum (seats, mats & boot)',
            'Dashboard, console & door panel wipe',
            'Inside glass & mirror cleaning',
            'Scented air freshener spray',
          ],
        };
      case PackageTier.diamond:
        return {
          'Base Package (Gold Deluxe Wash)': const [
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
          'Premium Wash Additions': const [
            'Underbody wash',
            'Tyre polish & shine',
            'Full boot vacuum & cleaning',
            'Air freshener',
            'Special care for every corner and final detail',
          ],
        };
      case PackageTier.platinum:
        return {
          'Platinum Deep Cleaning (Interior + Exterior)': const [
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
        };
    }
  }

  /// Returns complete combined list of inclusions without omitting base services
  List<String> getAllInclusions(VehicleCategory category) {
    final sections = getInclusions(category);
    final List<String> combined = [];
    for (final items in sections.values) {
      combined.addAll(items);
    }
    return combined;
  }
}

const List<ServicePackage> kAllServicePackages = [
  ServicePackage(
    tier: PackageTier.silver,
    customerName: 'Silver',
    subtitle: 'Basic Wash',
    backendServiceId: 'a0000001-0000-4000-8000-000000000001',
    route: '/exterior-wash',
    image: 'exterior_wash.png',
    duration: '45 min',
  ),
  ServicePackage(
    tier: PackageTier.gold,
    customerName: 'Gold',
    subtitle: 'Deluxe Wash',
    backendServiceId: 'a0000002-0000-4000-8000-000000000002',
    route: '/interior-wash',
    image: 'interior_cleaning.png',
    duration: '60 min',
  ),
  ServicePackage(
    tier: PackageTier.diamond,
    customerName: 'Diamond',
    subtitle: 'Premium Wash',
    backendServiceId: 'a0000004-0000-4000-8000-000000000004',
    route: '/premium-wash',
    image: 'premium_wash.png',
    duration: '90 min',
  ),
  ServicePackage(
    tier: PackageTier.platinum,
    customerName: 'Platinum',
    subtitle: 'Deep Cleaning (Interior + Exterior)',
    backendServiceId: 'a0000003-0000-4000-8000-000000000003',
    route: '/full-detailing',
    image: 'full_detailing.png',
    duration: '2-3 hrs',
  ),
];

/// Returns the packages available for a given vehicle category.
/// For Luxury: strictly excludes Silver (returns Gold, Diamond, Platinum only).
List<ServicePackage> getPackagesForCategory(VehicleCategory category) {
  if (category == VehicleCategory.luxury) {
    return kAllServicePackages.where((p) => p.tier != PackageTier.silver).toList();
  }
  if (category == VehicleCategory.bike) {
    return const [];
  }
  return kAllServicePackages;
}

class BikeServicePackage {
  final String id;
  final String variantId;
  final String title;
  final String route;
  final String image;
  final String duration;
  final int price;
  final String description;
  final List<String> inclusions;

  const BikeServicePackage({
    required this.id,
    required this.variantId,
    required this.title,
    required this.route,
    required this.image,
    required this.duration,
    required this.price,
    required this.description,
    required this.inclusions,
  });

  String get displayPrice => '₹$price';
}

const List<BikeServicePackage> kBikeServicePackages = [
  BikeServicePackage(
    id: 'a0000005-0000-4000-8000-000000000005',
    variantId: 'b0000005-0000-4000-8000-000000000005',
    title: 'Bucket Wash',
    route: '/bucket-wash',
    image: 'Bike_Bucket_wash.png',
    duration: '20 min',
    price: 299,
    description: 'A quick and thorough manual wash using bucket and soap. Perfect for regular upkeep and everyday grime.',
    inclusions: [
      'Bucket foam wash',
      'Wheel & tyre cleaning',
      'Chain cleaning',
      'Seat wipe down',
      'Hand dry',
    ],
  ),
  BikeServicePackage(
    id: 'a0000006-0000-4000-8000-000000000006',
    variantId: 'b0000006-0000-4000-8000-000000000006',
    title: 'Pressure Wash',
    route: '/pressure-wash',
    image: 'Bike_Pressure_Wash.png',
    duration: '30 min',
    price: 399,
    description: 'High-pressure water jet wash that removes tough dirt and grime from every corner of the bike.',
    inclusions: [
      'High-pressure rinse',
      'Wheel & tyre cleaning',
      'Chain & engine cleaning',
      'Seat & mirror cleaning',
      'Hand dry & polish',
    ],
  ),
];
