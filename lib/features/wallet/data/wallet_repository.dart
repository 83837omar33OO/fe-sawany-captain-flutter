import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/ledger_entry.dart';

class WalletRepository {
  Future<LedgerSummary> getLedgerSummary(String riderId) async {
    final response = await ApiClient.get(ApiEndpoints.orders);
    final completedOrders = response["completedOrders"] as List<dynamic>? ?? [];
    final rider = response["rider"] as Map<String, dynamic>? ?? {};

    final walletBal = (rider["walletBalance"] as num?)?.toDouble() ??
        (rider["walletBalanceEgp"] as num?)?.toDouble() ??
        0.0;
    final totalDelivered = (rider["totalDeliveriesCompleted"] as num?)?.toInt() ??
        (rider["totalDeliveries"] as num?)?.toInt() ??
        completedOrders.length;

    double todayEarnings = 0;
    double cashInHand = 0;
    final List<CompletedOrderSummary> list = [];

    for (final ord in completedOrders) {
      final pricing = ord["pricing"] as Map<String, dynamic>?;
      final deliveryFee = (pricing?["deliveryFee"] as num?)?.toDouble() ?? 15.0;
      final totalPayable = (pricing?["totalPayable"] as num?)?.toDouble() ?? 0.0;

      todayEarnings += deliveryFee;
      cashInHand += totalPayable;

      list.add(CompletedOrderSummary(
        id: ord["id"] ?? "",
        orderReference: ord["orderReference"] ?? ord["id"]?.toString().substring(0, 6) ?? "",
        storeName: ord["storeNameArabic"] ?? "المحل الشريك",
        deliveryFee: deliveryFee,
        totalCollected: totalPayable,
        completedAt: ord["deliveredAt"] ?? ord["updatedAt"] ?? "",
      ));
    }

    final effectiveWallet = walletBal > 0 ? walletBal : todayEarnings;

    return LedgerSummary(
      walletBalance: effectiveWallet,
      totalDeliveredCount: totalDelivered,
      todayDeliveredCount: completedOrders.length,
      todayEarnings: todayEarnings,
      cashInHand: cashInHand,
      totalDeliveredAmount: cashInHand,
      totalPaidToOffice: 0,
      remainingDue: cashInHand,
      recentCompleted: list,
    );
  }

  Future<void> submitSettlement(String riderId, double amount, String note) async {
    await ApiClient.post(ApiEndpoints.settlement, {
      "riderId": riderId,
      "amount": amount,
      "note": note,
    });
  }
}
