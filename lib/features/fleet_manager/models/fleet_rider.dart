class FleetRider {
  final String id;
  final String name;
  final String phone;
  final String vehicleType;
  final String zoneName;
  final String role;
  final bool isOnline;
  final String status; // "available" | "delivering" | "offline"
  final int activeOrdersCount;
  final int todayOrdersCount;
  final int totalDeliveries;
  final double rating;
  final int reviewsCount;
  final int averageDeliveryMinutes;
  final double cashOnHandEgp;
  final double walletBalanceEgp;
  final double lat;
  final double lng;
  final DateTime lastLocationUpdate;

  FleetRider({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.zoneName,
    required this.role,
    required this.isOnline,
    required this.status,
    required this.activeOrdersCount,
    required this.todayOrdersCount,
    required this.totalDeliveries,
    required this.rating,
    required this.reviewsCount,
    required this.averageDeliveryMinutes,
    required this.cashOnHandEgp,
    required this.walletBalanceEgp,
    required this.lat,
    required this.lng,
    required this.lastLocationUpdate,
  });

  factory FleetRider.fromJson(Map<String, dynamic> json) {
    return FleetRider(
      id: json["id"] ?? "",
      name: json["name"] ?? "كابتن",
      phone: json["phone"] ?? "",
      vehicleType: json["vehicleType"] ?? "موتوسيكل",
      zoneName: json["zoneName"] ?? json["zoneNameArabic"] ?? "الناصرية",
      role: json["role"] ?? "rider",
      isOnline: json["isOnline"] ?? false,
      status: json["status"] ?? (json["isOnline"] == true ? "available" : "offline"),
      activeOrdersCount: (json["activeOrdersCount"] as num?)?.toInt() ?? 0,
      todayOrdersCount: (json["todayOrdersCount"] as num?)?.toInt() ?? 0,
      totalDeliveries: (json["totalDeliveries"] as num?)?.toInt() ?? 0,
      rating: (json["rating"] as num?)?.toDouble() ?? 5.0,
      reviewsCount: (json["reviewsCount"] as num?)?.toInt() ?? 0,
      averageDeliveryMinutes: (json["averageDeliveryMinutes"] as num?)?.toInt() ?? 18,
      cashOnHandEgp: (json["cashOnHandEgp"] as num?)?.toDouble() ?? 0.0,
      walletBalanceEgp: (json["walletBalanceEgp"] as num?)?.toDouble() ?? 0.0,
      lat: (json["lat"] as num?)?.toDouble() ?? 31.037,
      lng: (json["lng"] as num?)?.toDouble() ?? 30.472,
      lastLocationUpdate: json["lastLocationUpdate"] != null
          ? DateTime.tryParse(json["lastLocationUpdate"]) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class FleetSummary {
  final int totalRiders;
  final int onlineRiders;
  final int deliveringRiders;
  final int availableRiders;
  final int totalTodayOrders;

  FleetSummary({
    required this.totalRiders,
    required this.onlineRiders,
    required this.deliveringRiders,
    required this.availableRiders,
    required this.totalTodayOrders,
  });

  factory FleetSummary.fromJson(Map<String, dynamic> json) {
    return FleetSummary(
      totalRiders: (json["totalRiders"] as num?)?.toInt() ?? 0,
      onlineRiders: (json["onlineRiders"] as num?)?.toInt() ?? 0,
      deliveringRiders: (json["deliveringRiders"] as num?)?.toInt() ?? 0,
      availableRiders: (json["availableRiders"] as num?)?.toInt() ?? 0,
      totalTodayOrders: (json["totalTodayOrders"] as num?)?.toInt() ?? 0,
    );
  }
}
