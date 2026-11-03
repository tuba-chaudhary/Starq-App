import 'package:starq_app/core/errors/app_exception.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/network/api_endpoints.dart';
import 'package:starq_app/core/storage/secure_storage_service.dart';
import 'package:starq_app/core/utils/json_helpers.dart';
import 'package:starq_app/features/auth/domain/user.dart';

class AuthSession {
  final User user;
  final String accessToken;
  final String refreshToken;

  AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });
}

class AuthRepository {
  final ApiClient _api = ApiClient();
  final SecureStorageService _storage = SecureStorageService();

  Future<AuthSession> login({required String email, required String password}) async {
    final res = await _api.post(ApiEndpoints.login, data: {
      'email': email.trim(),
      'password': password,
    });
    return _persist(res.data);
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await _api.post(ApiEndpoints.register, data: {
      'full_name': fullName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
    });
    return _persist(res.data);
  }

  Future<User> me() async {
    final res = await _api.get(ApiEndpoints.profile);
    return User.fromJson(asJsonMap(asJsonMap(res.data)['data']));
  }

  Future<void> logout() async {
    try {
      final refresh = await _storage.getRefreshToken();
      await _api.post(ApiEndpoints.logout, data: {'refresh_token': refresh});
    } catch (_) {
      // Always clear local session.
    }
    await _storage.clearAll();
  }

  Future<AuthSession> _persist(dynamic body) async {
    final json = asJsonMap(body);
    if (json['success'] != true) {
      throw AppException(json['message']?.toString() ?? 'Authentication failed');
    }
    final data = asJsonMap(json['data']);
    final user = User.fromJson(asJsonMap(data['user']));
    final access = data['access_token']?.toString() ?? '';
    final refresh = data['refresh_token']?.toString() ?? '';
    await _storage.saveTokens(accessToken: access, refreshToken: refresh);
    await _storage.saveUserId(user.id);
    return AuthSession(user: user, accessToken: access, refreshToken: refresh);
  }
}
