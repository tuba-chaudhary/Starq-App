import 'package:dio/dio.dart';

class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'User-Agent': 'STARQApp/1.0 (contact@starq.com)',
        'Accept': 'application/json',
      },
    ),
  );

  /// Reverse geocodes coordinates (lat, lon) into a clean, human-readable address.
  Future<Map<String, dynamic>?> reverseGeocode(double lat, double lon) async {
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'format': 'json',
          'addressdetails': 1,
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final road = address['road'] ?? address['street'] ?? address['neighbourhood'] ?? address['suburb'] ?? '';
        final area = address['suburb'] ?? address['residential'] ?? address['city_district'] ?? '';
        final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'] ?? 'Noida';
        final state = address['state'] ?? 'Uttar Pradesh';
        final pincode = address['postcode'] ?? '';

        final parts = <String>[];
        if (road.toString().isNotEmpty) parts.add(road.toString());
        if (area.toString().isNotEmpty && area.toString() != road.toString()) parts.add(area.toString());
        if (city.toString().isNotEmpty) parts.add(city.toString());
        if (state.toString().isNotEmpty) parts.add(state.toString());
        if (pincode.toString().isNotEmpty) parts.add(pincode.toString());

        final fullAddress = parts.isNotEmpty ? parts.join(', ') : (data['display_name'] ?? 'Detected Location');
        final label = road.toString().isNotEmpty
            ? road.toString()
            : (area.toString().isNotEmpty ? area.toString() : city.toString());

        return {
          'label': label,
          'fullAddress': fullAddress,
          'street': road.toString(),
          'area': area.toString(),
          'city': city.toString(),
          'state': state.toString(),
          'pincode': pincode.toString(),
          'latitude': lat,
          'longitude': lon,
        };
      }
    } catch (_) {
      // Fallback on network or rate limit
    }

    return {
      'label': 'GPS Location',
      'fullAddress': 'Location (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})',
      'street': '',
      'area': '',
      'city': 'Noida',
      'state': 'Uttar Pradesh',
      'pincode': '',
      'latitude': lat,
      'longitude': lon,
    };
  }

  /// Searches places dynamically with live autocomplete suggestions.
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': q,
          'format': 'json',
          'addressdetails': 1,
          'countrycodes': 'in',
          'limit': 6,
        },
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        return list.map((item) {
          final map = item as Map<String, dynamic>;
          final addr = map['address'] as Map<String, dynamic>? ?? {};

          final name = map['name'] ?? map['display_name']?.toString().split(',').first ?? q;
          final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? '';
          final state = addr['state'] ?? '';
          final postcode = addr['postcode'] ?? '';
          final lat = double.tryParse(map['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(map['lon']?.toString() ?? '') ?? 0.0;

          return {
            'label': name.toString(),
            'fullAddress': map['display_name'] ?? q,
            'street': addr['road'] ?? name.toString(),
            'area': addr['suburb'] ?? addr['neighbourhood'] ?? '',
            'city': city.toString(),
            'state': state.toString(),
            'pincode': postcode.toString(),
            'latitude': lat,
            'longitude': lon,
          };
        }).toList();
      }
    } catch (_) {
      // Fallback
    }

    return [];
  }
}
