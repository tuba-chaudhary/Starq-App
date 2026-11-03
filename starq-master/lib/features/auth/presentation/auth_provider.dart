import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../domain/user_model.dart';


class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  final SecureStorageService _storageService;

  User? _currentUser;
  bool _isLoading = true;
  String? _error;
  bool _isServerUnavailable = false;

  AuthProvider(this._apiClient, this._storageService) {
    _init();
  }

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isServerUnavailable => _isServerUnavailable;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  Future<void> _init() async {
    _setLoading(true);
    _setError(null);
    _isServerUnavailable = false;

    // 1. Try restoring cached user profile so UI does not flicker or dump to login on blip
    final cachedJson = LocalCacheService().getString('cached_user_json');
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        _currentUser = User.fromJson(decoded);
      } catch (_) {
        _currentUser = null;
      }
    }

    // 2. Check saved access token
    final token = await _storageService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      await fetchMe();
    } else {
      _currentUser = null;
      await LocalCacheService().remove('cached_user_json');
      _setLoading(false);
    }
  }

  Future<void> retryInit() async {
    await _init();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    _isServerUnavailable = false;
    final normalizedEmail = email.trim().toLowerCase();

    final emailError = AppValidators.email(normalizedEmail);
    if (emailError != null) {
      _setError(emailError);
      _setLoading(false);
      return false;
    }

    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {'email': normalizedEmail, 'password': password},
      );

      final token = response.data['accessToken'];
      await _storageService.saveTokens(accessToken: token);
      final userData = response.data['user'] is Map<String, dynamic>
          ? response.data['user']
          : Map<String, dynamic>.from(response.data['user'] as Map);
      _currentUser = User.fromJson(userData);
      await LocalCacheService().setString('cached_user_json', jsonEncode(userData));
      _setLoading(false);
      return true;
    } on UnauthorizedException catch (_) {
      _setError('Invalid email or password');
      _setLoading(false);
      return false;
    } on NetworkException catch (_) {
      _isServerUnavailable = true;
      _setError('Unable to connect to STARQ server. Please verify your connection and try again.');
      _setLoading(false);
      return false;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        _setError('Invalid email or password');
      } else {
        _setError(e.response?.data['message'] ?? 'Failed to login');
      }
      _setLoading(false);
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendOtp(String phone) async {
    _setLoading(true);
    _setError(null);
    _isServerUnavailable = false;
    try {
      await _apiClient.post(
        '/auth/otp/send',
        data: {'phone': phone.trim()},
      );
      _setLoading(false);
      return true;
    } on DioException catch (e) {
      _setError(e.response?.data['message'] ?? 'Failed to send verification code');
      _setLoading(false);
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to send verification code. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyOtp(
    String phone,
    String otp, {
    String? fullName,
    String? email,
    String? intendedRole,
  }) async {
    _setLoading(true);
    _setError(null);
    _isServerUnavailable = false;
    try {
      final payload = <String, dynamic>{
        'phone': phone.trim(),
        'otp': otp.trim(),
        if (fullName != null && fullName.trim().isNotEmpty) 'fullName': fullName.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim().toLowerCase(),
        if (intendedRole != null) 'intendedRole': intendedRole,
      };

      final response = await _apiClient.post(
        '/auth/otp/verify',
        data: payload,
      );

      final token = response.data['accessToken'];
      await _storageService.saveTokens(accessToken: token);
      final userData = response.data['user'] is Map<String, dynamic>
          ? response.data['user']
          : Map<String, dynamic>.from(response.data['user'] as Map);
      _currentUser = User.fromJson(userData);
      await LocalCacheService().setString('cached_user_json', jsonEncode(userData));
      _setLoading(false);
      return true;
    } on DioException catch (e) {
      _setError(e.response?.data['message'] ?? 'Invalid verification code');
      _setLoading(false);
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to verify code. Please check and try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> switchMode(String targetRole) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _apiClient.post(
        '/auth/switch-mode',
        data: {'role': targetRole},
      );
      final token = response.data['accessToken'];
      if (token != null) {
        await _storageService.saveTokens(accessToken: token);
      }
      final userData = response.data['user'] is Map<String, dynamic>
          ? response.data['user']
          : Map<String, dynamic>.from(response.data['user'] as Map);
      _currentUser = User.fromJson(userData);
      await LocalCacheService().setString('cached_user_json', jsonEncode(userData));
      _setLoading(false);
      return true;
    } on DioException catch (e) {
      _setError(e.response?.data['message'] ?? 'Failed to switch mode');
      _setLoading(false);
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to switch mode. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register(
    String fullName,
    String email,
    String phone,
    String password, {
    String? referralCode,
  }) async {
    _setLoading(true);
    _setError(null);
    _isServerUnavailable = false;
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final payload = <String, dynamic>{
        'fullName': fullName.trim(),
        'email': normalizedEmail,
        'phone': phone.trim(),
        'password': password,
      };
      if (referralCode != null && referralCode.trim().isNotEmpty) {
        payload['referralCode'] = referralCode.trim().toUpperCase();
      }
      final response = await _apiClient.post(
        '/auth/register',
        data: payload,
      );
      final token = response.data['accessToken'];
      await _storageService.saveTokens(accessToken: token);
      final userData = response.data['user'] is Map<String, dynamic>
          ? response.data['user']
          : Map<String, dynamic>.from(response.data['user'] as Map);
      _currentUser = User.fromJson(userData);
      await LocalCacheService().setString('cached_user_json', jsonEncode(userData));
      _setLoading(false);
      return true;
    } on NetworkException catch (_) {
      _isServerUnavailable = true;
      _setError('Unable to connect to STARQ server. Please verify your connection and try again.');
      _setLoading(false);
      return false;
    } on DioException catch (e) {
      _setError(e.response?.data['message'] ?? 'Failed to register');
      _setLoading(false);
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> socialLogin(String provider, {String? email, String? fullName}) async {
    _setLoading(true);
    _setError(null);
    _isServerUnavailable = false;
    try {
      final isApple = provider.toLowerCase() == 'apple';
      final safeEmail = email ?? (isApple ? 'apple.user@starq.com' : 'google.user@starq.com');
      final safeName = fullName ?? (isApple ? 'Apple User' : 'Google User');

      final response = await _apiClient.post(
        '/auth/social',
        data: {
          'provider': provider,
          'email': safeEmail,
          'fullName': safeName,
        },
      );
      final token = response.data['accessToken'];
      await _storageService.saveTokens(accessToken: token);
      final userData = response.data['user'] is Map<String, dynamic>
          ? response.data['user']
          : Map<String, dynamic>.from(response.data['user'] as Map);
      _currentUser = User.fromJson(userData);
      await LocalCacheService().setString('cached_user_json', jsonEncode(userData));
      _setLoading(false);
      return true;
    } on NetworkException catch (_) {
      _isServerUnavailable = true;
      _setError('Unable to connect to STARQ server. Please verify your connection and try again.');
      _setLoading(false);
      return false;
    } on DioException catch (e) {
      _setError(e.response?.data['message'] ?? 'Failed to authenticate with $provider');
      _setLoading(false);
      return false;
    } on AppException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to authenticate with $provider. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<void> fetchMe() async {
    try {
      final response = await _apiClient.get('/auth/me');
      final userData = response.data is Map<String, dynamic>
          ? response.data
          : Map<String, dynamic>.from(response.data as Map);
      _currentUser = User.fromJson(userData);
      await LocalCacheService().setString('cached_user_json', jsonEncode(userData));
      _error = null;
      _isServerUnavailable = false;
    } on UnauthorizedException catch (_) {
      // 401 Unauthorized: token genuinely expired or invalid.
      await _storageService.clearAll();
      await LocalCacheService().remove('cached_user_json');
      _currentUser = null;
      _setError('Session expired. Please sign in again.');
      _isServerUnavailable = false;
    } on NetworkException catch (_) {
      // Server unreachable: preserve token and do NOT log out!
      _isServerUnavailable = true;
      _setError('Unable to reach STARQ server. Please check your connection.');
    } catch (e) {
      if (e is AppException && e.statusCode == 401) {
        await _storageService.clearAll();
        await LocalCacheService().remove('cached_user_json');
        _currentUser = null;
        _setError('Session expired. Please sign in again.');
        _isServerUnavailable = false;
      } else {
        // Unknown or network error: preserve session token
        _isServerUnavailable = true;
        _setError('Unable to reach STARQ server. Please check your connection.');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    _setError(null);
    try {
      await _apiClient.delete('/auth/me');
      await logout();
      return true;
    } on DioException catch (e) {
      _setError(e.response?.data['message'] ?? 'Failed to delete account');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    final uid = _currentUser?.id;
    await _storageService.clearAll();
    await LocalCacheService().remove('cached_user_json');
    await LocalCacheService().remove('cached_referral_code');
    await LocalCacheService().remove('selected_address_id');
    await LocalCacheService().remove('selected_vehicle_id');
    if (uid != null && uid.isNotEmpty) {
      await LocalCacheService().remove('cached_addresses_$uid');
      await LocalCacheService().remove('selected_address_id_$uid');
    }
    await LocalCacheService().remove('cached_addresses_default');
    _currentUser = null;
    _error = null;
    _isServerUnavailable = false;
    notifyListeners();
  }

}
