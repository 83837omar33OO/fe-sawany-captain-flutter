class ActiveOrder {
  final String id;
  final String? orderReference;
  final String status;
  final String storeName;
  final String storeAddress;
  final String? storePhone;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String? customerNotes;
  final double totalCashToCollect;
  final double riderEarning;
  final DateTime createdAt;

  ActiveOrder({
    required this.id,
    this.orderReference,
    required this.status,
    required this.storeName,
    required this.storeAddress,
    this.storePhone,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.customerNotes,
    required this.totalCashToCollect,
    required this.riderEarning,
    required this.createdAt,
  });

  factory ActiveOrder.fromJson(Map<String, dynamic> json) {
    final customer = json["customer"] as Map<String, dynamic>?;
    final storeDetails = json["storeDetails"] as Map<String, dynamic>?;
    final pricing = json["pricing"] as Map<String, dynamic>?;

    return ActiveOrder(
      id: json["id"] ?? "",
      orderReference: json["orderReference"] ?? json["id"]?.toString().substring(0, 6),
      status: json["status"] ?? "assigned_to_rider",
      storeName: storeDetails?["nameArabic"] ?? json["storeNameArabic"] ?? "المحل الشريك",
      storeAddress: storeDetails?["addressText"] ?? "الناصرية القديمة",
      storePhone: storeDetails?["phone"],
      customerName: customer?["name"] ?? "عميل في ثواني",
      customerPhone: customer?["phone"] ?? "",
      customerAddress: customer?["addressText"] ?? "عنوان التسليم بالمنطقة",
      customerNotes: customer?["notes"],
      totalCashToCollect: (pricing?["totalPayable"] as num?)?.toDouble() ?? 0.0,
      riderEarning: (json["deliveryEarning"] as num?)?.toDouble() ??
          (pricing?["deliveryFee"] as num?)?.toDouble() ??
          15.0,
      createdAt: json["createdAt"] != null
          ? DateTime.tryParse(json["createdAt"]) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
