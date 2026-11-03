import 'package:flutter_test/flutter_test.dart';
import 'package:starq_app/features/providers/vehicle_provider.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:dio/dio.dart';

class FakeApiClient implements ApiClient {
  bool getCalled = false;
  bool postCalled = false;
  bool deleteCalled = false;
  Map<String, dynamic> mockResponseData = {};
  List<dynamic> mockResponseList = [];
  bool throwError = false;

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    getCalled = true;
    if (throwError) throw DioException(requestOptions: RequestOptions(path: path));
    return Response(requestOptions: RequestOptions(path: path), data: mockResponseList) as Response<T>;
  }

  @override
  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    postCalled = true;
    if (throwError) throw DioException(requestOptions: RequestOptions(path: path));
    return Response(requestOptions: RequestOptions(path: path), data: mockResponseData) as Response<T>;
  }

  @override
  Future<Response<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    deleteCalled = true;
    if (throwError) throw DioException(requestOptions: RequestOptions(path: path));
    return Response(requestOptions: RequestOptions(path: path), data: mockResponseData) as Response<T>;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('VehicleProvider Tests', () {
    late VehicleProvider vehicleProvider;
    late FakeApiClient fakeApiClient;

    setUp(() {
      fakeApiClient = FakeApiClient();
      vehicleProvider = VehicleProvider(fakeApiClient);
    });

    test('fetchVehicles updates list', () async {
      fakeApiClient.mockResponseList = [
        {'id': 'v1', 'userId': 'u1', 'vehicleTypeId': 't1', 'make': 'Honda', 'model': 'City', 'licensePlate': 'KA01'}
      ];

      await vehicleProvider.fetchVehicles();

      expect(vehicleProvider.vehicles.length, 1);
      expect(vehicleProvider.vehicles.first.make, 'Honda');
      expect(fakeApiClient.getCalled, isTrue);
    });

    test('addVehicle calls post and re-fetches', () async {
      fakeApiClient.mockResponseList = [
        {'id': 'v1', 'userId': 'u1', 'vehicleTypeId': 't1', 'make': 'Honda', 'model': 'City', 'licensePlate': 'KA01'}
      ];
      
      final result = await vehicleProvider.addVehicle({'make': 'Honda'});
      
      expect(result, isTrue);
      expect(fakeApiClient.postCalled, isTrue);
      expect(fakeApiClient.getCalled, isTrue); // from fetchVehicles
    });
  });
}
