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

  // Default coordinate: Al Ameriya 2 / Damanhour
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
      final orders = radarData["orders"] as List<AvailableOrder>;
      final isOnline = radarData["isOnline"] as bool? ?? false;
      final activeList = await _activeRepo.getActiveOrders();

      if (orders.length > _lastKnownCount) {
        AudioAlertService.triggerNewOrderAlert();
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
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isOnline ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 8, spreadRadius: 1),
                          ],
                        ),
                        child: const Icon(
                          Icons.motorcycle_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),

                    // Customer GPS Marker (if active delivery has GPS coordinates)
                    if (hasCustomerGps)
                      Marker(
                        point: LatLng(primaryActive!.customerLat!, primaryActive.customerLng!),
                        width: 130,
                        height: 64,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Text(
                                "عميل: ${primaryActive.customerName}",
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.location_on, color: Color(0xFF0284C7), size: 30),
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
                            border: Border.all(color: const Color(0xFF00875A), width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.store_rounded, color: Color(0xFF00875A), size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 2. Compact Top Floating Pill (Zone & Radar Status)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B132B).withOpacity(0.92) : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 15, color: Color(0xFF10B981)),
                          const SizedBox(width: 5),
                          Text(
                            "نطاق الناصرية القديمة • غرب الإسكندرية",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.slateDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Online/Offline Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _isOnline
                            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isOnline ? "متصل بالرادار" : "غير متاح",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isOnline
                                  ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF00875A))
                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Floating Quick Location Buttons
            Positioned(
              right: 16,
              bottom: hasActiveOrder ? 230 : (_availableOrders.isNotEmpty ? 200 : 110),
              child: Column(
                children: [
                  if (hasCustomerGps) ...[
                    Material(
                      color: const Color(0xFF0284C7),
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          _mapController.move(
                            LatLng(primaryActive!.customerLat!, primaryActive.customerLng!),
                            16.0,
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(11),
                          child: Icon(Icons.person_pin_circle, size: 22, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Material(
                    color: isDark ? const Color(0xFF0B132B) : Colors.white,
                    shape: const CircleBorder(),
                    elevation: 4,
                    shadowColor: Colors.black38,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _fetchLiveLocation,
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Icon(
                          Icons.my_location_rounded,
                          size: 22,
                          color: isDark ? const Color(0xFF10B981) : const Color(0xFF00875A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Mission Card for Active Order (Docked above bottom bar)
            if (hasActiveOrder)
              Positioned(
                left: 14,
                right: 14,
                bottom: 85,
                child: _buildActiveOrderMissionCard(primaryActive!, isDark),
              )
            // 4b. Or Incoming Offer Card if no active order
            else if (_isOnline && _availableOrders.isNotEmpty)
              Positioned(
                left: 14,
                right: 14,
                bottom: 85,
                child: _buildIncomingOrderCard(_availableOrders.first, isDark),
              ),

            // 5. Docked Duty Sheet (Bottom docked control bar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B132B) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOut ? const Color(0xFF0284C7) : const Color(0xFFD97706),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
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
                    size: 16,
                    color: isOut ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOut ? "مهمة جارية: في الطريق للعميل" : "مهمة جارية: استلام من المحل",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOut ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
              Text(
                "طلب #${ord.orderReference}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isOut
                ? "تسليم لـ: ${ord.customerName} (${ord.customerPhone.isNotEmpty ? ord.customerPhone : 'الهاتف متاح بالداخل'}) • ${ord.customerAddress}"
                : "استلام من: ${ord.storeName} (${ord.storeAddress})",
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOut ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  icon: const Icon(Icons.directions, size: 16),
                  label: Text(
                    isOut ? "ملاحة للعميل 🏠" : "ملاحة للمحل 🏬",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _dialPhone(isOut ? ord.customerPhone : (ord.storePhone ?? ord.customerPhone)),
                icon: const Icon(Icons.phone, size: 16),
                label: const Text("اتصال", style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: widget.onOpenActiveTab,
                child: const Text("تفاصيل 📋", style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingOrderCard(AvailableOrder ord, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ord.storeName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.slateDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B).withOpacity(0.5) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "+${ord.deliveryEarning.toStringAsFixed(0)} ج.م أرباحك",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "المحل: ${ord.storeArea} • التسليم: ${ord.deliveryArea}",
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          // Clear pricing breakdown preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "مشتريات: ${ord.subtotal.toStringAsFixed(0)} ج | خدمة: ${ord.serviceFee > 0 ? ord.serviceFee.toStringAsFixed(1) : '0'} ج",
                  style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                ),
                Text(
                  "كاش للتحصيل: ${ord.totalToCollect.toStringAsFixed(0)} ج.م",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMint,
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isClaiming ? null : () => _claimOrder(ord.id),
                  child: _isClaiming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                        )
                      : const Text("⚡ قبول واستلام الطلب", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : const Color(0xFF64748B),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: widget.onOpenActiveTab,
                child: const Text("معاينة 📋", style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineDutyBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: const Color(0xFF0B132B),
            minimumSize: const Size.fromHeight(46),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isToggling
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF0B132B)),
                )
              : const Icon(Icons.power_settings_new_rounded, size: 22),
          label: Text(
            _isToggling ? "جاري بدء الوردية..." : "بدء الوردية واستقبال الطلبات",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          onPressed: _isToggling ? null : _toggleDuty,
        ),
      ],
    );
  }

  Widget _buildOnlineDutyBar(bool isDark) {
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
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "أنت متصل وجاهز للعمل",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.slateDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _activeOrders.isNotEmpty
                    ? "لديك ${_activeOrders.length} طلبات جارية بعهدتك"
                    : _availableOrders.isEmpty
                        ? "الرادار يبحث عن طلبات جديدة..."
                        : "يوجد ${_availableOrders.length} طلبات متاحة بالرادار",
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFEF4444)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: _isToggling
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFFEF4444)),
                )
              : const Icon(Icons.pause_circle_outline, size: 16),
          label: Text(
            _isToggling ? "لحظة..." : "إيقاف مؤقت",
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          onPressed: _isToggling ? null : _toggleDuty,
        ),
      ],
    );
  }
}
