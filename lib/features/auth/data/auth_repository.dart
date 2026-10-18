import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage_service.dart';

class AuthRepository {
  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await ApiClient.post(ApiEndpoints.login, {
      "phone": phone.trim(),
      "password": password.trim(),
    });

    final token = response["token"] as String?;
    final rider = response["rider"] as Map<String, dynamic>?;

    if (token != null && rider != null) {
      await SecureStorageService.saveSession(
        token: token,
        id: rider["id"] ?? "",
        name: rider["name"] ?? "كابتن في ثواني",
        phone: rider["phone"] ?? phone,
        zone: rider["zone"],
      );
    }

    return response;
  }

  Future<void> logout() async {
    try {
      await ApiClient.post(ApiEndpoints.logout, {});
    } catch (_) {}
    await SecureStorageService.clearSession();
  }

  Future<bool> isAuthenticated() async {
    final token = await SecureStorageService.getToken();
    return token != null && token.isNotEmpty;
  }
}
