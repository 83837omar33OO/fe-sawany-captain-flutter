class AvailableOrder {
  final String id;
  final String? orderReference;
  final String storeName;
  final String storeArea;
  final String deliveryArea;
  final double orderValue;
  final double deliveryEarning;
  final DateTime createdAt;

  AvailableOrder({
    required this.id,
    this.orderReference,
    required this.storeName,
    required this.storeArea,
    required this.deliveryArea,
    required this.orderValue,
    required this.deliveryEarning,
    required this.createdAt,
  });

  factory AvailableOrder.fromJson(Map<String, dynamic> json) {
    final pricing = json["pricing"] as Map<String, dynamic>?;
    final storeDetails = json["storeDetails"] as Map<String, dynamic>?;
    final customer = json["customer"] as Map<String, dynamic>?;

    return AvailableOrder(
      id: json["id"] ?? "",
      orderReference: json["orderReference"] ?? json["id"]?.toString().substring(0, 6),
      storeName: storeDetails?["nameArabic"] ?? json["storeNameArabic"] ?? "المحل الشريك",
      storeArea: storeDetails?["addressText"] ?? "الناصرية القديمة",
      deliveryArea: customer?["addressText"] ?? "نطاق دمنهور",
      orderValue: (pricing?["totalPayable"] as num?)?.toDouble() ?? 0.0,
      deliveryEarning: (json["deliveryEarning"] as num?)?.toDouble() ??
          (pricing?["deliveryFee"] as num?)?.toDouble() ??
          15.0,
      createdAt: json["createdAt"] != null
          ? DateTime.tryParse(json["createdAt"]) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
