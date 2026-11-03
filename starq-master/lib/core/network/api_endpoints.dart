class ApiEndpoints {
  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';
  static const String refreshToken = '/auth/refresh';
  static const String profile = '/auth/me';
  static const String logout = '/auth/logout';

  // Vehicles
  static const String vehicles = '/vehicles';
  static String vehicle(String id) => '/vehicles/$id';
  static String setPrimaryVehicle(String id) => '/vehicles/$id/primary';

  // Services & Catalog
  static const String services = '/services';
  static String service(String id) => '/services/$id';
  static const String addOns = '/addons';

  // Addresses & Locations
  static const String addresses = '/addresses';
  static String address(String id) => '/addresses/$id';
  static const String checkServiceability = '/service-areas/check';

  // Bookings & Quotes
  static const String availableSlots = '/bookings/available-slots';
  static const String quote = '/bookings/quote';
  static const String bookings = '/bookings';
  static String booking(String id) => '/bookings/$id';
  static String cancelBooking(String id) => '/bookings/$id/cancel';
  static String rebook(String id) => '/bookings/$id/rebook';
  static const String currentConsent = '/consents/current';
  static const String consents = '/consents';

  // Payments
  static const String createPaymentOrder = '/payments/create-order';
  static const String verifyPayment = '/payments/verify';
  static String paymentStatus(String id) => '/payments/status/$id';

  // Tracking & GPS
  static String bookingTracking(String id) => '/bookings/$id/partner-location';

  // Inspections & Pre-wash
  static String bookingInspection(String id) => '/inspections/$id';
  static String consentInspection(String id) => '/inspections/$id/consent';

  // Reviews & Rewards
  static const String reviews = '/reviews';
  static const String rewards = '/rewards';
  static const String redeemReward = '/rewards/redeem';
  static const String notifications = '/notifications';
}
