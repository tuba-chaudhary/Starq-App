import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class EnvConfig {
  static const String devLanUrl = 'http://127.0.0.1:3000/api/v1';

  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      try {
        await dotenv.load(fileName: '.env.example');
      } catch (_) {
        // Tests and platforms without bundled env files use defaults.
      }
    }
  }

  static String get apiBaseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url != null && url.isNotEmpty) {
      // If localhost is specified but running on physical Android device, use LAN IP
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && url.contains('localhost')) {
        return devLanUrl;
      }
      return url;
    }
    if (kReleaseMode) return 'https://api.yourproductiondomain.com/api/v1';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return devLanUrl;
    }
    return 'http://localhost:3000/api/v1';
  }

  static String get razorpayKeyId =>
      dotenv.env['RAZORPAY_KEY_ID'] ?? 'rzp_test_placeholder';

  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';

  static bool get isDev => appEnv == 'development';
}
