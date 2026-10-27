class OrderItemInfo {
  final String? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double itemTotal;
  final String storeName;
  final String? customizationNote;
  final String? priceNote;
  final bool isMarketPrice;

  OrderItemInfo({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.itemTotal,
    required this.storeName,
    this.customizationNote,
    this.priceNote,
    this.isMarketPrice = false,
  });

  factory OrderItemInfo.fromJson(Map<String, dynamic> json) {
    final price = (json["unitPrice"] as num?)?.toDouble() ?? 0.0;
    final isMarket = json["isMarketPrice"] == true ||
        price == 0.0 ||
        (json["priceNote"] != null && json["priceNote"].toString().isNotEmpty);

    return OrderItemInfo(
      productId: json["productId"]?.toString(),
      productName: json["productNameArabic"] ?? json["nameArabic"] ?? json["name"] ?? "صنف",
      quantity: (json["quantity"] as num?)?.toInt() ?? 1,
      unitPrice: price,
      itemTotal: (json["itemTotal"] as num?)?.toDouble() ?? 0.0,
      storeName: json["storeNameArabic"] ?? "المحل الشريك",
      customizationNote: json["customizationNote"]?.toString(),
      priceNote: json["priceNote"]?.toString(),
      isMarketPrice: isMarket,
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
  final String? prescriptionImageUrl;
  final String? prescriptionAudioUrl;
  final String? prescriptionNotes;
  final bool hasUnpricedItems;
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
    this.prescriptionImageUrl,
    this.prescriptionAudioUrl,
    this.prescriptionNotes,
    this.hasUnpricedItems = false,
    required this.createdAt,
  });

  factory ActiveOrder.fromJson(Map<String, dynamic> json) {
    final customer = json["customer"] as Map<String, dynamic>?;
    final storeDetails = json["storeDetails"] as Map<String, dynamic>?;
    final pricing = json["pricing"] as Map<String, dynamic>?;
    final prescription = json["prescriptionData"] as Map<String, dynamic>?;

    // Parse items breakdown
    final rawItems = (json["items"] as List<dynamic>?) ?? [];
    final itemsList = rawItems
        .map((it) => OrderItemInfo.fromJson(it as Map<String, dynamic>))
        .toList();
    final totalPieces = itemsList.fold<int>(0, (sum, it) => sum + it.quantity);

    final unpriced = itemsList.any((it) => it.isMarketPrice || it.unitPrice == 0.0);

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
      prescriptionImageUrl: prescription?["imageUrl"],
      prescriptionAudioUrl: prescription?["audioUrl"],
      prescriptionNotes: prescription?["notes"],
      hasUnpricedItems: unpriced,
      createdAt: json["createdAt"] != null
          ? DateTime.tryParse(json["createdAt"]) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
