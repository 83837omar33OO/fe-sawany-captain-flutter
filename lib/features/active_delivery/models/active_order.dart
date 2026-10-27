class OrderItemInfo {
  final String productName;
  final int quantity;
  final double unitPrice;
  final double itemTotal;
  final String storeName;

  OrderItemInfo({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.itemTotal,
    required this.storeName,
  });

  factory OrderItemInfo.fromJson(Map<String, dynamic> json) {
    return OrderItemInfo(
      productName: json["productNameArabic"] ?? json["nameArabic"] ?? json["name"] ?? "صنف",
      quantity: (json["quantity"] as num?)?.toInt() ?? 1,
      unitPrice: (json["unitPrice"] as num?)?.toDouble() ?? 0.0,
      itemTotal: (json["itemTotal"] as num?)?.toDouble() ?? 0.0,
      storeName: json["storeNameArabic"] ?? "المحل الشريك",
    );
  }
}

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
  final double? customerLat;
  final double? customerLng;
  final double totalCashToCollect;
  final double riderEarning;
  final List<OrderItemInfo> items;
  final int totalPiecesCount;
  final String? paymentMethod;
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
    this.customerLat,
    this.customerLng,
    required this.totalCashToCollect,
    required this.riderEarning,
    required this.items,
    required this.totalPiecesCount,
    this.paymentMethod,
    required this.createdAt,
  });

  factory ActiveOrder.fromJson(Map<String, dynamic> json) {
    final customer = json["customer"] as Map<String, dynamic>?;
    final storeDetails = json["storeDetails"] as Map<String, dynamic>?;
    final pricing = json["pricing"] as Map<String, dynamic>?;

    // Parse items breakdown
    final rawItems = (json["items"] as List<dynamic>?) ?? [];
    final itemsList = rawItems
        .map((it) => OrderItemInfo.fromJson(it as Map<String, dynamic>))
        .toList();
    final totalPieces = itemsList.fold<int>(0, (sum, it) => sum + it.quantity);

    // Coordinates extraction
    final lat = (customer?["latitude"] as num?)?.toDouble() ??
        (json["customerLat"] as num?)?.toDouble();
    final lng = (customer?["longitude"] as num?)?.toDouble() ??
        (json["customerLng"] as num?)?.toDouble();

    // Customer address formatting
    final addressDesc = customer?["addressDescription"] ??
        customer?["streetLandmark"] ??
        customer?["addressText"] ??
        "المنطقة";

    final landmark = customer?["nearbyLandmark"] as String?;
    final fullCustomerAddress = (landmark != null && landmark.isNotEmpty)
        ? "$addressDesc - $landmark"
        : addressDesc;

    return ActiveOrder(
      id: json["id"] ?? "",
      orderReference: json["orderReference"] ?? json["id"]?.toString().substring(0, 6),
      status: json["status"] ?? "assigned_to_rider",
      storeName: storeDetails?["nameArabic"] ?? json["storeNameArabic"] ?? "المحل الشريك",
      storeAddress: storeDetails?["addressText"] ?? "الناصرية القديمة",
      storePhone: storeDetails?["phone"],
      customerName: customer?["name"] ?? "عميل في ثواني",
      customerPhone: customer?["phone"] ?? "",
      customerAddress: fullCustomerAddress,
      customerNotes: customer?["notes"],
      customerLat: lat,
      customerLng: lng,
      totalCashToCollect: (pricing?["totalPayable"] as num?)?.toDouble() ??
          (json["cashToCollect"] as num?)?.toDouble() ??
          0.0,
      riderEarning: (json["deliveryEarning"] as num?)?.toDouble() ??
          (pricing?["deliveryFee"] as num?)?.toDouble() ??
          15.0,
      items: itemsList,
      totalPiecesCount: totalPieces > 0 ? totalPieces : 1,
      paymentMethod: json["paymentMethod"] ?? "cash_on_delivery",
      createdAt: json["createdAt"] != null
          ? DateTime.tryParse(json["createdAt"]) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
