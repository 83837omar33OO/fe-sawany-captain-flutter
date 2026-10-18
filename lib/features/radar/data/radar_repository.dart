import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/available_order.dart';

class RadarRepository {
  Future<List<AvailableOrder>> getAvailableOrders() async {
    final response = await ApiClient.get(ApiEndpoints.orders);
    final rawAvailable = response["availableOrders"] as List<dynamic>? ?? [];

    return rawAvailable
        .map((item) => AvailableOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> claimOrder(String orderId) async {
    await ApiClient.post(ApiEndpoints.orders, {
      "orderId": orderId,
      "action": "claim",
    });
  }

  Future<void> toggleDuty(bool isOnline) async {
    await ApiClient.post(ApiEndpoints.orders, {
      "action": "toggle_duty",
      "isOnline": isOnline,
    });
  }
}
