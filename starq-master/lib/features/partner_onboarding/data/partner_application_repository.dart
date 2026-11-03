import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

class PartnerApplicationRepository {
  final ApiClient _apiClient;

  PartnerApplicationRepository(this._apiClient);

  Future<Map<String, dynamic>> fetchStatus() async {
    final response = await _apiClient.get('/partners/application-status');
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> submitApplication({
    required String fullName,
    required String email,
    required String address,
    required String city,
    required String pinCode,
    required String idDocumentType,
    required List<int> photoBytes,
    required String photoName,
    required List<int> docBytes,
    required String docName,
  }) async {
    final formData = FormData.fromMap({
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'address': address.trim(),
      'city': city.trim(),
      'pinCode': pinCode.trim(),
      'idDocumentType': idDocumentType,
      'profilePhoto': MultipartFile.fromBytes(
        photoBytes,
        filename: photoName,
      ),
      'idDocument': MultipartFile.fromBytes(
        docBytes,
        filename: docName,
      ),
    });

    final response = await _apiClient.post(
      '/partners/apply',
      data: formData,
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(response.data as Map);
  }
}
