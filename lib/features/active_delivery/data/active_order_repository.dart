import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/active_order.dart';

class ActiveOrderRepository {
  Future<List<ActiveOrder>> getActiveOrders() async {
    final response = await ApiClient.get(ApiEndpoints.orders);
    final rawActive = response["activeOrders"] as List<dynamic>? ?? [];

    return rawActive
        .map((item) => ActiveOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> pickupOrder(String orderId) async {
    await ApiClient.post(ApiEndpoints.orders, {
      "orderId": orderId,
      "action": "pickup",
    });
  }

  Future<void> completeDelivery(String orderId, {String? note}) async {
    await ApiClient.post(ApiEndpoints.orders, {
      "orderId": orderId,
      "action": "complete",
      "note": note,
    });
  }

  Future<void> reportException(String orderId, String reason, String details) async {
    await ApiClient.post(ApiEndpoints.orders, {
      "orderId": orderId,
      "action": "report_issue",
      "reason": reason,
      "note": details,
    });
  }

  Future<void> reportDeliveryIssue(String orderId, String reason, String details) async {
    return reportException(orderId, reason, details);
  }
}
