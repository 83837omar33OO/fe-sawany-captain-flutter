import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/active_order.dart';
import '../../radar/models/available_order.dart';

class ActiveOrderRepository {
  Future<List<ActiveOrder>> getActiveOrders() async {
    final response = await ApiClient.get(ApiEndpoints.orders);
    final rawActive = response["activeOrders"] as List<dynamic>? ?? [];

    return rawActive
        .map((item) => ActiveOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AvailableOrder>> getAvailableOrders() async {
    final response = await ApiClient.get(ApiEndpoints.orders);
    final rawAvailable = response["availableOrders"] as List<dynamic>? ?? [];

    return rawAvailable
        .map((item) => AvailableOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> fetchDeliveriesData() async {
    final response = await ApiClient.get(ApiEndpoints.orders);
    final rawActive = response["activeOrders"] as List<dynamic>? ?? [];
    final rawAvailable = response["availableOrders"] as List<dynamic>? ?? [];
    final rider = response["rider"] as Map<String, dynamic>? ?? {};

    return {
      "activeOrders": rawActive
          .map((item) => ActiveOrder.fromJson(item as Map<String, dynamic>))
          .toList(),
      "availableOrders": rawAvailable
          .map((item) => AvailableOrder.fromJson(item as Map<String, dynamic>))
          .toList(),
      "rider": rider,
      "isOnline": rider["isOnline"] == true,
      "isSuspended": rider["isSuspended"] == true,
    };
  }

  Future<void> claimOrder(String orderId) async {
    await ApiClient.post(ApiEndpoints.orders, {
      "orderId": orderId,
      "action": "claim",
    });
  }

  Future<void> rejectOrder(String orderId) async {
    await ApiClient.post(ApiEndpoints.orders, {
      "orderId": orderId,
      "action": "reject",
    });
  }

  Future<void> arriveAtStore(String orderId) async {
    await ApiClient.post(ApiEndpoints.orders, {
      "orderId": orderId,
      "action": "arrive_store",
    });
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

  Future<void> updatePricing(String orderId, List<Map<String, dynamic>> itemPrices) async {
    await ApiClient.post(ApiEndpoints.updatePricing, {
      "orderId": orderId,
      "itemPrices": itemPrices,
    });
  }
}
