import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/network/api_endpoints.dart';
import 'package:starq_app/core/utils/json_helpers.dart';
import 'package:starq_app/features/services/domain/add_on.dart';
import 'package:starq_app/features/services/domain/service_item.dart';

class ServiceRepository {
  final ApiClient _api = ApiClient();

  Future<List<ServiceItem>> list({required String vehicleType, String? category}) async {
    final res = await _api.get(ApiEndpoints.services, queryParameters: {
      'vehicle_type': vehicleType,
      if (category != null) 'category': category,
    });
    return asJsonList(asJsonMap(res.data)['data']).map(ServiceItem.fromJson).toList();
  }

  Future<List<AddOn>> addOns({required String vehicleType, required String category}) async {
    final res = await _api.get(ApiEndpoints.addOns, queryParameters: {
      'vehicle_type': vehicleType,
      'category': category,
    });
    return asJsonList(asJsonMap(res.data)['data']).map(AddOn.fromJson).toList();
  }
}
