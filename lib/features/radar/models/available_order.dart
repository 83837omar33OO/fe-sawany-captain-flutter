import '../../active_delivery/models/active_order.dart';

class AvailableOrder {
  final String id;
  final String? orderReference;
  final String storeName;
  final String storeArea;
  final String? storePhone;
  final double? storeLat;
  final double? storeLng;
  final String deliveryArea;
  final String customerAddress;
  final String? customerNotes;
  final String? customerName;
  final String? customerPhone;
  final double? customerLat;
  final double? customerLng;
  final double orderValue;
  final double deliveryEarning;
  final double subtotal;
  final double serviceFee;
  final double discount;
  final double totalToCollect;
  final List<OrderItemInfo> items;
  final int totalPiecesCount;
  final DateTime createdAt;

  AvailableOrder({
    required this.id,
    this.orderReference,
    required this.storeName,
    required this.storeArea,
    this.storePhone,
    this.storeLat,
    this.storeLng,
    required this.deliveryArea,
    required this.customerAddress,
    this.customerNotes,
    this.customerName,
    this.customerPhone,
    this.customerLat,
    this.customerLng,
    required this.orderValue,
    required this.deliveryEarning,
    required this.subtotal,
    required this.serviceFee,
    required this.discount,
    required this.totalToCollect,
    required this.items,
    required this.totalPiecesCount,
    required this.createdAt,
  });

  factory AvailableOrder.fromJson(Map<String, dynamic> json) {
    final pricing = json["pricing"] as Map<String, dynamic>?;
    final storeDetails = json["storeDetails"] as Map<String, dynamic>?;
    final customer = json["customer"] as Map<String, dynamic>?;

    final rawItems = (json["items"] as List<dynamic>?) ?? [];
    final itemsList = rawItems
        .map((it) => OrderItemInfo.fromJson(it as Map<String, dynamic>))
        .toList();
    final totalPieces = itemsList.fold<int>(0, (sum, it) => sum + it.quantity);

    // Customer address formatting
    final addressDesc = customer?["addressDescription"] ??
        customer?["streetLandmark"] ??
        customer?["addressText"] ??
        json["addressDescription"] ??
        "المنطقة";
    final landmark = customer?["nearbyLandmark"] as String? ?? json["nearbyLandmark"] as String?;
    final fullCustomerAddress = (landmark != null && landmark.isNotEmpty)
        ? "$addressDesc - $landmark"
        : addressDesc;

    // Coordinates extraction
    final cLat = (customer?["latitude"] as num?)?.toDouble() ??
        (json["customerLat"] as num?)?.toDouble();
    final cLng = (customer?["longitude"] as num?)?.toDouble() ??
        (json["customerLng"] as num?)?.toDouble();

    final sLat = (storeDetails?["latitude"] as num?)?.toDouble();
    final sLng = (storeDetails?["longitude"] as num?)?.toDouble();

    final totalPayable = (pricing?["totalPayable"] as num?)?.toDouble() ??
        (json["cashToCollect"] as num?)?.toDouble() ??
        0.0;
    final deliveryFee = (json["deliveryEarning"] as num?)?.toDouble() ??
        (pricing?["deliveryFee"] as num?)?.toDouble() ??
        15.0;
    final sub = (pricing?["subtotal"] as num?)?.toDouble() ??
        (totalPayable > deliveryFee ? (totalPayable - deliveryFee) : totalPayable);
    final service = (pricing?["serviceFee"] as num?)?.toDouble() ?? 0.0;
    final disc = (pricing?["discount"] as num?)?.toDouble() ?? 0.0;

    final custName = customer?["name"] ?? json["customerName"] ?? "عميل في ثواني";
    final custPhone = customer?["phone"] ?? json["customerPhone"] ?? "";

    return AvailableOrder(
      id: json["id"] ?? "",
      orderReference: json["orderReference"] ?? json["id"]?.toString().substring(0, 6),
      storeName: storeDetails?["nameArabic"] ?? json["storeNameArabic"] ?? "المحل الشريك",
      storeArea: storeDetails?["addressText"] ?? "الناصرية القديمة",
      storePhone: storeDetails?["phone"],
      storeLat: sLat,
      storeLng: sLng,
      deliveryArea: customer?["zoneNameArabic"] ?? json["zoneNameArabic"] ?? "الناصرية القديمة / الإسكندرية",
      customerAddress: fullCustomerAddress,
      customerNotes: customer?["notes"] ?? json["notes"],
      customerName: custName,
      customerPhone: custPhone,
      customerLat: cLat,
      customerLng: cLng,
      orderValue: totalPayable,
      deliveryEarning: deliveryFee,
      subtotal: sub,
      serviceFee: service,
      discount: disc,
      totalToCollect: totalPayable,
      items: itemsList,
      totalPiecesCount: totalPieces > 0 ? totalPieces : 1,
      createdAt: json["createdAt"] != null
          ? DateTime.tryParse(json["createdAt"]) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
