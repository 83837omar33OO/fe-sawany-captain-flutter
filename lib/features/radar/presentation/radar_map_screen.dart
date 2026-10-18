import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/audio_alert_service.dart';
import '../data/radar_repository.dart';
import '../models/available_order.dart';

class RadarMapScreen extends StatefulWidget {
  final VoidCallback onOpenActiveTab;

  const RadarMapScreen({super.key, required this.onOpenActiveTab});

  @override
  State<RadarMapScreen> createState() => _RadarMapScreenState();
}

class _RadarMapScreenState extends State<RadarMapScreen> {
  final MapController _mapController = MapController();
  final _radarRepo = RadarRepository();

  // Default coordinate: Al Ameriya 2 / Damanhour & Western Alexandria
  LatLng _currentLocation = const LatLng(31.0185, 29.8130);
  bool _hasLocation = false;
  bool _isOnline = true;
  bool _isToggling = false;
  bool _isClaiming = false;

  List<AvailableOrder> _availableOrders = [];
  int _lastKnownCount = 0;
  Timer? _pollingTimer;

  // Key Zone Points (Stores in Al Ameriya 2 / Nasriya)
  final List<Map<String, dynamic>> _hubPoints = [
    {"name": "كبدة الفلاح", "pos": const LatLng(31.0210, 29.8150)},
    {"name": "سوبرماركت الخير", "pos": const LatLng(31.0160, 29.8110)},
    {"name": "مشويات النزاوى", "pos": const LatLng(31.0195, 29.8220)},
  ];

  @override
  void initState() {
    super.initState();
    _fetchLiveLocation();
    _fetchRadar();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_isOnline) _fetchRadar(silent: true);
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
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final newPos = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentLocation = newPos;
          _hasLocation = true;
        });
        _mapController.move(newPos, 15.0);
      }
    } catch (_) {}
  }

  Future<void> _fetchRadar({bool silent = false}) async {
    try {
      final list = await _radarRepo.getAvailableOrders();
      if (list.length > _lastKnownCount) {
        AudioAlertService.triggerNewOrderAlert();
      }
      _lastKnownCount = list.length;
      if (mounted) {
        setState(() => _availableOrders = list);
      }
    } catch (_) {}
  }

  Future<void> _toggleDuty() async {
    setState(() => _isToggling = true);
    final nextStatus = !_isOnline;
    try {
      await _radarRepo.toggleDuty(nextStatus);
      setState(() => _isOnline = nextStatus);
      AudioAlertService.triggerSuccessFeedback();
    } catch (_) {
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
      await _fetchRadar();
      widget.onOpenActiveTab();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Live Interactive Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 14.5,
              minZoom: 10,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'online.fesawany.captain',
              ),
              // Hub Markers & Store Pins
              MarkerLayer(
                markers: [
                  // Rider's Live Marker
                  Marker(
                    point: _currentLocation,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1),
                        ],
                      ),
                      child: const Icon(
                        Icons.motorcycle,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  // Store Hubs
                  ..._hubPoints.map((hub) => Marker(
                        point: hub["pos"] as LatLng,
                        width: 34,
                        height: 34,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 1.5),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.store, color: AppColors.primary, size: 18),
                        ),
                      )),
                ],
              ),
            ],
          ),

          // 2. Top Status Badge (Calm Floating Header)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Zone Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B).withOpacity(0.95) : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.primaryMint),
                        const SizedBox(width: 4),
                        Text(
                          "قطاع العامرية ثان والناصرية",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slateDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Radar status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isOnline ? AppColors.primaryMint : const Color(0xFF64748B),
                      ),
                    ),
                    child: Text(
                      _isOnline ? "🟢 الرادار نشط" : "⚪ غير متاح",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isOnline ? (isDark ? const Color(0xFFA7F3D0) : AppColors.primary) : (isDark ? const Color(0xFFCBD5E1) : AppColors.slateLight),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating GPS "تحديد موقعي" Button
          Positioned(
            left: 16,
            bottom: _availableOrders.isNotEmpty ? 220 : 100,
            child: FloatingActionButton.small(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              foregroundColor: isDark ? Colors.white : AppColors.slateDark,
              elevation: 3,
              tooltip: "تحديد موقعي",
              onPressed: _fetchLiveLocation,
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),

          // 4. Incoming Order Floating Card (If any available in radar)
          if (_isOnline && _availableOrders.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 92,
              child: _buildIncomingOrderCard(_availableOrders.first, isDark),
            ),

          // 5. Docked Bottom Control Bar (Online / Offline Toggle)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1),
                ],
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isOnline ? "أنت متصل بالخدمة" : "أنت في وضع استراحة",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _isOnline ? (isDark ? AppColors.primaryMint : AppColors.primary) : (isDark ? const Color(0xFF94A3B8) : AppColors.slateLight),
                          ),
                        ),
                        Text(
                          _isOnline
                              ? "${_availableOrders.length} طلبات متاحة بالرادار"
                              : "اضغط لبدء استقبال الطلبات",
                          style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isOnline ? const Color(0xFFDC2626) : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isToggling ? null : _toggleDuty,
                      child: _isToggling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isOnline ? "إيقاف الوردية" : "بدء الوردية",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingOrderCard(AvailableOrder ord, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.slateDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B) : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "+${ord.deliveryEarning.toStringAsFixed(0)} ج.م أرباحك",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.primaryMint : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "المحل: ${ord.storeArea} • التسليم: ${ord.deliveryArea}",
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            "كاش الفاتورة: ${ord.orderValue.toStringAsFixed(0)} ج.م",
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFFB923C)),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(38),
            ),
            onPressed: _isClaiming ? null : () => _claimOrder(ord.id),
            child: _isClaiming
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text("⚡ قبول واستلام الطلب فوراً", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
