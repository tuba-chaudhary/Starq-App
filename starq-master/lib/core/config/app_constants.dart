class AppConstants {
  static const String appName = 'STARQ';
  static const String currencySymbol = '₹';
  static const int connectTimeoutSeconds = 15;
  static const int receiveTimeoutSeconds = 15;

  // Storage Keys
  static const String keyAccessToken = 'starq_access_token';
  static const String keyRefreshToken = 'starq_refresh_token';
  static const String keyUserId = 'starq_user_id';
  static const String keySelectedVehicleId = 'starq_selected_vehicle_id';

  // Booking Business Rules
  static const double defaultConvenienceFee = 0.0;
  static const double gstRatePercent = 18.0;
  static const double pointsRewardMultiplier = 0.10; // 10% of total
}
