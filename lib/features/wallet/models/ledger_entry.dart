class LedgerSummary {
  final int todayDeliveredCount;
  final double todayEarnings;
  final double cashInHand;
  final double totalDeliveredAmount;
  final double totalPaidToOffice;
  final double remainingDue;

  LedgerSummary({
    required this.todayDeliveredCount,
    required this.todayEarnings,
    required this.cashInHand,
    required this.totalDeliveredAmount,
    required this.totalPaidToOffice,
    required this.remainingDue,
  });

  factory LedgerSummary.fromJson(Map<String, dynamic> json) {
    return LedgerSummary(
      todayDeliveredCount: json["todayDeliveredCount"] ?? 0,
      todayEarnings: (json["todayEarnings"] as num?)?.toDouble() ?? 0.0,
      cashInHand: (json["cashInHand"] as num?)?.toDouble() ?? 0.0,
      totalDeliveredAmount: (json["totalDeliveredAmount"] as num?)?.toDouble() ?? 0.0,
      totalPaidToOffice: (json["totalPaidToAdmin"] as num?)?.toDouble() ?? 0.0,
      remainingDue: (json["remainingCashDue"] as num?)?.toDouble() ?? 0.0,
    );
  }
}
