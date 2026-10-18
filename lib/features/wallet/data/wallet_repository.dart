import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/ledger_entry.dart';

class WalletRepository {
  Future<LedgerSummary> getLedgerSummary(String riderId) async {
    final response = await ApiClient.get(ApiEndpoints.orders);
    final completedOrders = response["completedOrders"] as List<dynamic>? ?? [];

    double todayEarnings = 0;
    double cashInHand = 0;

    for (final ord in completedOrders) {
      final pricing = ord["pricing"] as Map<String, dynamic>?;
      final deliveryFee = (pricing?["deliveryFee"] as num?)?.toDouble() ?? 15.0;
      final totalPayable = (pricing?["totalPayable"] as num?)?.toDouble() ?? 0.0;

      todayEarnings += deliveryFee;
      cashInHand += totalPayable;
    }

    return LedgerSummary(
      todayDeliveredCount: completedOrders.length,
      todayEarnings: todayEarnings,
      cashInHand: cashInHand,
      totalDeliveredAmount: cashInHand,
      totalPaidToOffice: 0,
      remainingDue: cashInHand,
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
