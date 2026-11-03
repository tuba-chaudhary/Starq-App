import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/network/api_endpoints.dart';
import 'package:starq_app/core/utils/json_helpers.dart';
import 'package:starq_app/features/addresses/domain/address.dart';

class AddressRepository {
  final ApiClient _api = ApiClient();

  Future<List<Address>> list() async {
    final res = await _api.get(ApiEndpoints.addresses);
    final dynamic raw = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
    if (raw is List) {
      return raw.map((e) => Address.fromJson(asJsonMap(e))).toList();
    }
    return const [];
  }

  Future<Address> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.addresses, data: body);
    final dynamic raw = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
    return Address.fromJson(asJsonMap(raw));
  }

  Future<bool> isServiceable(String pincode) async {
    final res = await _api.get(ApiEndpoints.checkServiceability, queryParameters: {'pincode': pincode});
    final dynamic raw = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
    final data = asJsonMap(raw);
    return data['serviceable'] == true;
  }

  Future<void> delete(String id) async {
    await _api.delete(ApiEndpoints.address(id));
  }
}

