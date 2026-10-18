import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isOnline = false; // Initialized gracefully, synced with server
  bool _isToggling = false;
  bool _isClaiming = false;

  List<AvailableOrder> _availableOrders = [];
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
        setState(() {
          _currentLocation = newPos;
        });
        _mapController.move(newPos, 15.0);
      }
    } catch (_) {}
  }

  Future<void> _fetchRadarData({bool silent = false}) async {
    try {
      final data = await _radarRepo.fetchRadarData();
      final orders = data["orders"] as List<AvailableOrder>;
      final isOnline = data["isOnline"] as bool? ?? false;

      if (orders.length > _lastKnownCount) {
        AudioAlertService.triggerNewOrderAlert();
      }
      _lastKnownCount = orders.length;

      if (mounted) {
        setState(() {
          _availableOrders = orders;
          // Only update duty if not actively in middle of toggle
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
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
                    // Location Pill
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
                            "حي العامرية ثان • الناصرية",
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
                            _isOnline ? "رادار نشط" : "غير متاح",
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

            // 3. Floating "تحديد موقعي" Button (Elevated on right)
            Positioned(
              right: 16,
              bottom: _isOnline && _availableOrders.isNotEmpty ? 190 : 110,
              child: Material(
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
            ),

            // 4. Incoming Order Card (If order waiting)
            if (_isOnline && _availableOrders.isNotEmpty)
              Positioned(
                left: 14,
                right: 14,
                bottom: 100,
                child: _buildIncomingOrderCard(_availableOrders.first, isDark),
              ),

            // 5. Clean Docked Duty Sheet (Bottom docked control bar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  // When Offline: Prominent Green "بدء الوردية" Button
  Widget _buildOfflineDutyBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: const Color(0xFF0B132B),
            minimumSize: const Size.fromHeight(48),
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

  // When Online: Active Radar Status + Pause Option
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
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    "أنت متصل وجاهز للعمل",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.slateDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _availableOrders.isEmpty
                    ? "الرادار يبحث عن طلبات في نطاق العامرية..."
                    : "يوجد ${_availableOrders.length} طلبات متاحة بالرادار",
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFEF4444)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildIncomingOrderCard(AvailableOrder ord, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.slateDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "+${ord.deliveryEarning.toStringAsFixed(0)} ج.م أرباحك",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            "المحل: ${ord.storeArea} • التسليم: ${ord.deliveryArea}",
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 3),
          Text(
            "كاش الفاتورة: ${ord.orderValue.toStringAsFixed(0)} ج.م",
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF97316)),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: const Color(0xFF0B132B),
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isClaiming ? null : () => _claimOrder(ord.id),
            child: _isClaiming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B132B)),
                  )
                : const Text("⚡ قبول واستلام الطلب فوراً", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
