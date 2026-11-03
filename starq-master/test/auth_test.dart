import 'package:flutter_test/flutter_test.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/secure_storage_service.dart';
import 'package:starq_app/core/errors/app_exception.dart';
import 'package:dio/dio.dart';

class FakeApiClient implements ApiClient {
  bool getCalled = false;
  bool postCalled = false;
  Map<String, dynamic> mockResponseData = {};
  bool throwError = false;
  int statusCode = 401;
  String? lastPath;
  dynamic lastData;

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    getCalled = true;
    lastPath = path;
    if (throwError) {
      if (statusCode == 401) {
        throw UnauthorizedException('Invalid or expired token');
      }
      throw NetworkException();
    }
    return Response(requestOptions: RequestOptions(path: path), data: mockResponseData) as Response<T>;
  }

  @override
  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    postCalled = true;
    lastPath = path;
    lastData = data;
    if (throwError) {
      if (statusCode == 401) {
        throw UnauthorizedException('Invalid credentials');
      }
      throw NetworkException();
    }
    return Response(requestOptions: RequestOptions(path: path), data: mockResponseData) as Response<T>;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSecureStorage implements SecureStorageService {
  String? token;
  bool cleared = false;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<void> saveTokens({required String accessToken, String? refreshToken}) async { token = accessToken; }

  @override
  Future<void> clearAll() async { cleared = true; token = null; }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProvider Tests', () {
    late AuthProvider authProvider;
    late FakeApiClient fakeApiClient;
    late FakeSecureStorage fakeStorage;

    setUp(() {
      fakeApiClient = FakeApiClient();
      fakeStorage = FakeSecureStorage();
    });

    test('Initial state uses stored token if available', () async {
      fakeStorage.token = 'fake_token';
      fakeApiClient.mockResponseData = {'id': '1', 'email': 'test@example.com', 'fullName': 'Test User', 'role': 'CUSTOMER'};

      authProvider = AuthProvider(fakeApiClient, fakeStorage);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser?.email, 'test@example.com');
      expect(fakeApiClient.getCalled, isTrue);
      expect(authProvider.isServerUnavailable, isFalse);
    });

    test('Initial state clears auth if token is 401 invalid', () async {
      fakeStorage.token = 'invalid_token';
      fakeApiClient.throwError = true;
      fakeApiClient.statusCode = 401;

      authProvider = AuthProvider(fakeApiClient, fakeStorage);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(authProvider.isAuthenticated, isFalse);
      expect(fakeStorage.cleared, isTrue);
      expect(authProvider.error, contains('Session expired'));
    });

    test('Initial state preserves token when backend is unreachable (NetworkException)', () async {
      fakeStorage.token = 'saved_token_123';
      fakeApiClient.throwError = true;
      fakeApiClient.statusCode = 503; // Network error

      authProvider = AuthProvider(fakeApiClient, fakeStorage);
      await Future.delayed(const Duration(milliseconds: 100));

      // Token must NOT be wiped
      expect(fakeStorage.cleared, isFalse);
      expect(fakeStorage.token, 'saved_token_123');
      expect(authProvider.isServerUnavailable, isTrue);
      expect(authProvider.error, contains('Unable to reach STARQ server'));
    });

    test('Login success updates state, storage, and normalizes email', () async {
      fakeStorage.token = null;
      authProvider = AuthProvider(fakeApiClient, fakeStorage);
      
      fakeApiClient.mockResponseData = {
        'accessToken': 'new_token',
        'user': {'id': '1', 'email': 'login@example.com', 'fullName': 'Login User', 'role': 'CUSTOMER'}
      };

      final result = await authProvider.login('  LogIn@Example.com  ', 'password123');
      
      expect(result, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(fakeStorage.token, 'new_token');
      expect(fakeApiClient.lastData['email'], 'login@example.com');
      expect(authProvider.isServerUnavailable, isFalse);
    });
    
    test('Logout clears storage and state', () async {
      fakeStorage.token = null;
      authProvider = AuthProvider(fakeApiClient, fakeStorage);
      
      await authProvider.logout();
      
      expect(authProvider.isAuthenticated, isFalse);
      expect(fakeStorage.cleared, isTrue);
      expect(authProvider.isServerUnavailable, isFalse);
    });
  });
}
