import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/audio_alert_service.dart';
import '../../../core/services/duty_controller.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/order_filter_service.dart';
import '../../../core/utils/time_formatter.dart';
import '../data/radar_repository.dart';
import '../models/available_order.dart';
import '../../active_delivery/models/active_order.dart';
import '../../active_delivery/data/active_order_repository.dart';

class RadarMapScreen extends StatefulWidget {
  final VoidCallback onOpenActiveTab;

  const RadarMapScreen({super.key, required this.onOpenActiveTab});

  @override
  State<RadarMapScreen> createState() => _RadarMapScreenState();
}

class _RadarMapScreenState extends State<RadarMapScreen> {
  final MapController _mapController = MapController();
  final _radarRepo = RadarRepository();
  final _activeRepo = ActiveOrderRepository();

  // Default coordinate: Al Ameriya 2 / Damanhour / Alexandria
  LatLng _currentLocation = const LatLng(31.0185, 29.8130);
  bool _isOnline = false;
  bool _isToggling = false;
  bool _isClaiming = false;

  List<AvailableOrder> _availableOrders = [];
  List<ActiveOrder> _activeOrders = [];
  int _lastKnownCount = 0;
  Timer? _pollingTimer;

  // Key Zone Points (Stores in Al Ameriya 2 / Nasriya)
  final List<Map<String, dynamic>> _hubPoints = [
    {"name": "النزاوى للمشويات", "pos": const LatLng(31.0195, 29.8220)},
    {"name": "كبدة الفلاح", "pos": const LatLng(31.0210, 29.8150)},
    {"name": "أولاد رزق للأسماك", "pos": const LatLng(31.0160, 29.8110)},
    {"name": "صيدلية العهد الجديد", "pos": const LatLng(31.0180, 29.8180)},
  ];

  @override
  void initState() {
    super.initState();
    _fetchLiveLocation();
    _fetchRadarData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_isOnline) _fetchRadarData(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveLocation() async {
    try {
      HapticFeedback.lightImpact();
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final newPos = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _currentLocation = newPos);
        _mapController.move(newPos, 15.0);
      }
    } catch (_) {}
  }

  Future<void> _fetchRadarData({bool silent = false}) async {
    try {
      final radarData = await _radarRepo.fetchRadarData();
      List<AvailableOrder> orders = radarData["orders"] as List<AvailableOrder>;
      final isOnline = radarData["isOnline"] as bool? ?? false;
      final activeList = await _activeRepo.getActiveOrders();

      // 1. Filter out rejected orders
      orders = OrderFilterService().filter(orders);

      // 2. Sort by FIFO priority queue (oldest requested first)
      orders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      activeList.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // 3. Audio & Push Notifications
      if (orders.length > _lastKnownCount && _lastKnownCount >= 0) {
        AudioAlertService.triggerNewOrderAlert();
        final latest = orders.first;
        if (isOnline) {
          NotificationService().showNewOrderAlert(
            orderId: latest.id,
            orderRef: latest.orderReference ?? latest.id,
            storeName: latest.storeName,
            earning: latest.deliveryEarning,
          );
        } else {
          NotificationService().showUrgentOrderAlert(
            orderId: latest.id,
            orderRef: latest.orderReference ?? latest.id,
            area: latest.deliveryArea,
            amount: latest.totalToCollect,
          );
        }
      }

      // Check for delayed orders (> 20 mins)
      for (final ord in orders) {
        if (TimeFormatter.isDelayed(ord.createdAt)) {
          NotificationService().showDelayedOrderAlert(
            orderId: ord.id,
            orderRef: ord.orderReference ?? ord.id,
            elapsedMinutes: TimeFormatter.elapsedMinutes(ord.createdAt),
          );
          break;
        }
      }
      for (final ord in activeList) {
        if (TimeFormatter.isDelayed(ord.createdAt)) {
          NotificationService().showDelayedOrderAlert(
            orderId: ord.id,
            orderRef: ord.orderReference ?? ord.id,
            elapsedMinutes: TimeFormatter.elapsedMinutes(ord.createdAt),
          );
          break;
        }
      }

      _lastKnownCount = orders.length;

      if (mounted) {
        setState(() {
          _availableOrders = orders;
          _activeOrders = activeList;
          if (!_isToggling) _isOnline = isOnline;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleDuty() async {
    setState(() => _isToggling = true);
    final nextStatus = !_isOnline;
    try {
      await _radarRepo.toggleDuty(nextStatus);
      await DutyController().setDutyStatus(nextStatus);
      if (mounted) {
        setState(() => _isOnline = nextStatus);
        AudioAlertService.triggerSuccessFeedback();
      }
      await _fetchRadarData(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception:", "").trim()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("رفض الطلب ✕", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: const Text("هل تريد رفض هذا الطلب واستبعاده من قائمتك؟", style: TextStyle(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("تراجع"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("نعم، رفض"),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await OrderFilterService().reject(orderId);
      setState(() {
        _availableOrders = OrderFilterService().filter(_availableOrders);
      });
      try {
        await _activeRepo.rejectOrder(orderId);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم رفض الطلب واستبعاده"),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _claimOrder(String orderId) async {
    setState(() => _isClaiming = true);
    try {
      await _radarRepo.claimOrder(orderId);
      AudioAlertService.triggerSuccessFeedback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.claimSuccess),
            backgroundColor: AppColors.primary,
          ),
        );
      }
      await _fetchRadarData(silent: true);
      widget.onOpenActiveTab();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception:", "").trim()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  void _dialPhone(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openNavigation({double? lat, double? lng, required String addressQuery}) async {
    Uri uri;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      uri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
    } else {
      final encoded = Uri.encodeComponent("$addressQuery, الناصرية القديمة, الإسكندرية, مصر");
      uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encoded");
    }
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActiveOrder = _activeOrders.isNotEmpty;
    final ActiveOrder? primaryActive = hasActiveOrder ? _activeOrders.first : null;

    final hasCustomerGps = primaryActive != null &&
        primaryActive.customerLat != null &&
        primaryActive.customerLng != null &&
        primaryActive.customerLat != 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Live Interactive OpenStreetMap
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 14.5,
                minZoom: 11,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'online.fesawany.captain',
                ),
                MarkerLayer(
                  markers: [
                    // Captain Marker
                    Marker(
                      point: _currentLocation,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isOnline ? AppColors.primary : AppColors.textMutedLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(
                          Icons.motorcycle_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),

                    // Customer GPS Marker
                    if (hasCustomerGps)
                      Marker(
                        point: LatLng(primaryActive!.customerLat!, primaryActive.customerLng!),
                        width: 140,
                        height: 64,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.info,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                              ),
                              child: Text(
                                primaryActive.customerName,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.location_on, color: AppColors.info, size: 30),
                          ],
                        ),
                      ),

                    // Store Hub Markers
                    ..._hubPoints.map(
                      (hub) => Marker(
                        point: hub["pos"] as LatLng,
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 2. Sleek Floating Header Pill (Zone, Shift Duration & Real Battery)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: ListenableBuilder(
                  listenable: DutyController(),
                  builder: (context, _) {
                    final duty = DutyController();
                    final isCharging = duty.isCharging;
                    final batteryLevel = duty.batteryLevel;

                    return Row(
                      children: [
                        // Zone Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark.withOpacity(0.95) : Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 15, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                "الناصرية",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Battery Pill (Real-Time)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark.withOpacity(0.95) : Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCharging
                                    ? Icons.battery_charging_full_rounded
                                    : (batteryLevel > 50
                                        ? Icons.battery_full_rounded
                                        : (batteryLevel > 20
                                            ? Icons.battery_4_bar_rounded
                                            : Icons.battery_alert_rounded)),
                                size: 16,
                                color: isCharging
                                    ? AppColors.primaryMint
                                    : (batteryLevel > 20 ? AppColors.primary : AppColors.danger),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                duty.formattedBattery,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Shift Timer / Duty Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isOnline
                                ? (isDark ? AppColors.primaryMint.withOpacity(0.18) : AppColors.primaryLight)
                                : (isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isOnline ? AppColors.primary : AppColors.textMutedLight,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isOnline ? "🟢 ${duty.formattedShiftDuration}" : "⚪ غير متاح",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isOnline
                                      ? (isDark ? AppColors.primaryMint : AppColors.primary)
                                      : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // 3. Floating Quick Location Re-center
            Positioned(
              right: 16,
              bottom: hasActiveOrder ? 210 : (_availableOrders.isNotEmpty ? 190 : 90),
              child: Column(
                children: [
                  if (hasCustomerGps) ...[
                    FloatingActionButton.small(
                      heroTag: "fabCustomerLocation",
                      backgroundColor: AppColors.info,
                      elevation: 3,
                      onPressed: () {
                        _mapController.move(
                          LatLng(primaryActive!.customerLat!, primaryActive.customerLng!),
                          16.0,
                        );
                      },
                      child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 22),
                    ),
                    const SizedBox(height: 10),
                  ],
                  FloatingActionButton.small(
                    heroTag: "fabMyLocation",
                    backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                    elevation: 3,
                    onPressed: _fetchLiveLocation,
                    child: Icon(
                      Icons.my_location_rounded,
                      color: isDark ? AppColors.primaryMint : AppColors.primary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // 4. Mission Card for Active Order (Docked Above Bottom Bar)
            if (hasActiveOrder)
              Positioned(
                left: 16,
                right: 16,
                bottom: 85,
                child: _buildActiveOrderMissionCard(primaryActive!, isDark),
              )
            // 4b. Or Incoming Offer Card if no active order
            else if (_isOnline && _availableOrders.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 85,
                child: _buildIncomingOrderCard(_availableOrders.first, isDark),
              ),

            // 5. Sleek Bottom Duty Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: _isOnline ? _buildOnlineDutyBar(isDark) : _buildOfflineDutyBar(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Active Mission Card (Docked on Map Screen)
  Widget _buildActiveOrderMissionCard(ActiveOrder ord, bool isDark) {
    final isOut = ord.status == "out_for_delivery";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isOut ? Icons.navigation_rounded : Icons.storefront_rounded,
                    size: 18,
                    color: isOut ? AppColors.info : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOut ? "في الطريق للعميل" : "استلام من المحل",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isOut ? AppColors.info : AppColors.warning,
                    ),
                  ),
                ],
              ),
              Text(
                "طلب #${ord.orderReference}",
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isOut
                ? "${ord.customerName} • ${ord.customerAddress}"
                : "${ord.storeName} • ${ord.storeAddress}",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOut ? AppColors.primary : AppColors.info,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (isOut) {
                      _openNavigation(
                        lat: ord.customerLat,
                        lng: ord.customerLng,
                        addressQuery: ord.customerAddress,
                      );
                    } else {
                      _openNavigation(addressQuery: "${ord.storeName} ${ord.storeAddress}");
                    }
                  },
                  icon: const Icon(Icons.directions, size: 18),
                  label: Text(
                    isOut ? "ملاحة للعميل" : "ملاحة للمحل",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _dialPhone(isOut ? ord.customerPhone : (ord.storePhone ?? ord.customerPhone)),
                icon: const Icon(Icons.phone, size: 18),
                label: const Text("اتصال", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppColors.surfaceDarkHover : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: widget.onOpenActiveTab,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                tooltip: "التفاصيل",
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Incoming Order Card (Floating on Map)
  Widget _buildIncomingOrderCard(AvailableOrder ord, bool isDark) {
    final isDelayed = TimeFormatter.isDelayed(ord.createdAt);
    final elapsedStr = TimeFormatter.formatElapsedTime(ord.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with store name & Time Elapsed Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        ord.storeName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDelayed
                            ? (isDark ? AppColors.danger.withOpacity(0.2) : const Color(0xFFFEE2E2))
                            : (isDark ? AppColors.surfaceDarkHover : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isDelayed ? "⚠️ $elapsedStr" : "⏱️ $elapsedStr",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDelayed ? AppColors.danger : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primaryMint.withOpacity(0.18) : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "+${ord.deliveryEarning.toStringAsFixed(0)} ج.م أرباحك",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.primaryMint : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "من: ${ord.storeArea} ⬅️ إلى: ${ord.deliveryArea}",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
          const SizedBox(height: 8),

          // Total Cash Breakdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDarkHover : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "مشتريات: ${ord.subtotal.toStringAsFixed(0)} ج.م • توصيل: ${ord.deliveryEarning.toStringAsFixed(0)} ج.م",
                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                ),
                Text(
                  "المطلوب كاش: ${ord.totalToCollect.toStringAsFixed(0)} ج.م",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.primaryMint : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Punchy, single-word + emoji
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isClaiming ? null : () => _claimOrder(ord.id),
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  label: _isClaiming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("قبول ⚡", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _rejectOrder(ord.id),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text("رفض ✕", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 48),
                  foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
                  backgroundColor: isDark ? AppColors.surfaceDarkHover : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: widget.onOpenActiveTab,
                icon: const Icon(Icons.receipt_long_rounded, size: 20),
                tooltip: "معاينة 📋",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineDutyBar() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: _isToggling
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
            )
          : const Icon(Icons.power_settings_new_rounded, size: 22),
      label: Text(
        _isToggling ? "جاري..." : "بدء الوردية 🟢",
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
      onPressed: _isToggling ? null : _toggleDuty,
    );
  }

  Widget _buildOnlineDutyBar(bool isDark) {
    final duty = DutyController();

    return ListenableBuilder(
      listenable: duty,
      builder: (context, _) {
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "متصل • ${duty.formattedShiftDuration}",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _activeOrders.isNotEmpty
                        ? "${_activeOrders.length} طلبات جارية • 🔋 ${duty.formattedBattery}"
                        : _availableOrders.isEmpty
                            ? "الرادار يبحث... • 🔋 ${duty.formattedBattery}"
                            : "${_availableOrders.length} طلبات متاحة بالرادار",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isToggling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.8, color: AppColors.danger),
                    )
                  : const Icon(Icons.pause_circle_outline, size: 18),
              label: Text(
                _isToggling ? "لحظة..." : "إنهاء 🔴",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: _isToggling ? null : _toggleDuty,
            ),
          ],
        );
      },
    );
  }
}
