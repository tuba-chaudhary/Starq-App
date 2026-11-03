import 'dart:async';
import 'package:geolocator/geolocator.dart';

enum LocationStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  error,
}

class LocationResult {
  final LocationStatus status;
  final Position? position;
  final String? message;

  const LocationResult({
    required this.status,
    this.position,
    this.message,
  });

  bool get isSuccess => status == LocationStatus.success && position != null;
}

class LocationService {
  Future<bool> handlePermission() async {
    final result = await checkPermissionStatus();
    return result == LocationStatus.success;
  }

  Future<LocationStatus> checkPermissionStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationStatus.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationStatus.permissionDenied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationStatus.permissionDeniedForever;
    }

    return LocationStatus.success;
  }

  Future<LocationResult> getDetailedCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          status: LocationStatus.serviceDisabled,
          message: 'Location services (GPS) are disabled. Please enable GPS in device settings.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            status: LocationStatus.permissionDenied,
            message: 'Location permission was denied. Please allow location access to use current location.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          status: LocationStatus.permissionDeniedForever,
          message: 'Location permission is permanently denied. Please allow location access in App Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      return LocationResult(
        status: LocationStatus.success,
        position: position,
      );
    } on TimeoutException {
      return const LocationResult(
        status: LocationStatus.timeout,
        message: 'Location request timed out. Please check GPS signal and try again.',
      );
    } catch (e) {
      return LocationResult(
        status: LocationStatus.error,
        message: 'Failed to obtain location: $e',
      );
    }
  }

  Future<Position?> getCurrentPosition() async {
    final result = await getDetailedCurrentPosition();
    return result.position;
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Stream<Position>? getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}

