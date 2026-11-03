import 'package:flutter_test/flutter_test.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/features/models/vehicle_model.dart';
import 'package:starq_app/features/models/service_model.dart';
import 'package:dio/dio.dart';

class FakeApiClient implements ApiClient {
  bool getCalled = false;
  bool postCalled = false;
  Map<String, dynamic> mockResponseData = {};
  List<dynamic> mockResponseList = [];
  
  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    getCalled = true;
    return Response(requestOptions: RequestOptions(path: path), data: mockResponseList) as Response<T>;
  }

  @override
  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    postCalled = true;
    return Response(requestOptions: RequestOptions(path: path), data: mockResponseData) as Response<T>;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BookingProvider Tests', () {
    late BookingProvider bookingProvider;
    late FakeApiClient fakeApiClient;

    setUp(() {
      fakeApiClient = FakeApiClient();
      bookingProvider = BookingProvider(fakeApiClient);
    });

    test('getQuote sets current quote', () async {
      final v = Vehicle(id: 'v1', userId: 'u1', vehicleTypeId: 't1', make: 'M', model: 'M');
      final s = Service(id: 's1', name: 'Wash', category: 'CAR', variants: []);
      bookingProvider.selectVehicle(v);
      bookingProvider.selectService(s);

      fakeApiClient.mockResponseData = {
        'serviceName': 'Wash',
        'basePrice': 100,
        'addonsTotal': 0,
        'subtotal': 100,
        'taxes': 0,
        'total': 100,
        'addons': []
      };

      final result = await bookingProvider.getQuote();
      expect(result, isTrue);
      expect(bookingProvider.currentQuote?.total, 100);
      expect(fakeApiClient.postCalled, isTrue);
    });
  });
}
