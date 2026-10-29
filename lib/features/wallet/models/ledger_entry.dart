class CompletedOrderSummary {
  final String id;
  final String orderReference;
  final String storeName;
  final double deliveryFee;
  final double totalCollected;
  final String completedAt;

  CompletedOrderSummary({
    required this.id,
    required this.orderReference,
    required this.storeName,
    required this.deliveryFee,
    required this.totalCollected,
    required this.completedAt,
  });

  factory CompletedOrderSummary.fromJson(Map<String, dynamic> json) {
    final pricing = json["pricing"] as Map<String, dynamic>?;
    return CompletedOrderSummary(
      id: json["id"] ?? "",
      orderReference: json["orderReference"] ?? json["id"]?.toString().substring(0, 6) ?? "",
      storeName: json["storeNameArabic"] ?? "المحل الشريك",
      deliveryFee: (pricing?["deliveryFee"] as num?)?.toDouble() ?? 15.0,
      totalCollected: (pricing?["totalPayable"] as num?)?.toDouble() ?? 0.0,
      completedAt: json["deliveredAt"] ?? json["updatedAt"] ?? "",
    );
  }
}

class LedgerSummary {
  final double walletBalance;
  final int totalDeliveredCount;
  final int todayDeliveredCount;
  final double todayEarnings;
  final double cashInHand;
  final double totalDeliveredAmount;
  final double totalPaidToOffice;
  final double remainingDue;
  final List<CompletedOrderSummary> recentCompleted;

  LedgerSummary({
    required this.walletBalance,
    required this.totalDeliveredCount,
    required this.todayDeliveredCount,
    required this.todayEarnings,
    required this.cashInHand,
    required this.totalDeliveredAmount,
    required this.totalPaidToOffice,
    required this.remainingDue,
    this.recentCompleted = const [],
  });

  factory LedgerSummary.fromJson(Map<String, dynamic> json) {
    final rawList = (json["recentCompleted"] as List<dynamic>?) ?? [];
    return LedgerSummary(
      walletBalance: (json["walletBalance"] as num?)?.toDouble() ?? 0.0,
      totalDeliveredCount: json["totalDeliveredCount"] ?? json["todayDeliveredCount"] ?? 0,
      todayDeliveredCount: json["todayDeliveredCount"] ?? 0,
      todayEarnings: (json["todayEarnings"] as num?)?.toDouble() ?? 0.0,
      cashInHand: (json["cashInHand"] as num?)?.toDouble() ?? 0.0,
      totalDeliveredAmount: (json["totalDeliveredAmount"] as num?)?.toDouble() ?? 0.0,
      totalPaidToOffice: (json["totalPaidToAdmin"] as num?)?.toDouble() ?? 0.0,
      remainingDue: (json["remainingCashDue"] as num?)?.toDouble() ?? (json["cashInHand"] as num?)?.toDouble() ?? 0.0,
      recentCompleted: rawList.map((e) => CompletedOrderSummary.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
