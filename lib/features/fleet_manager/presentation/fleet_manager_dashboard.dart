import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/fleet_repository.dart';
import '../models/fleet_rider.dart';

class FleetManagerDashboard extends StatefulWidget {
  const FleetManagerDashboard({super.key});

  @override
  State<FleetManagerDashboard> createState() => _FleetManagerDashboardState();
}

class _FleetManagerDashboardState extends State<FleetManagerDashboard> with SingleTickerProviderStateMixin {
  final _fleetRepo = FleetRepository();
  final _authRepo = AuthRepository();
  final MapController _mapController = MapController();

  List<FleetRider> _riders = [];
  FleetSummary? _summary;
  bool _isLoading = true;
  String _filter = "all"; // "all" | "available" | "delivering" | "offline"
  String _searchQuery = "";
  Timer? _refreshTimer;
  int _currentTabIndex = 0; // 0 = Map, 1 = List

  @override
  void initState() {
    super.initState();
    _loadFleetData();
    // Live polling every 12 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) _loadFleetData(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFleetData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final res = await _fleetRepo.getFleetData();
      if (mounted) {
        setState(() {
          _riders = res["riders"] as List<FleetRider>;
          _summary = res["summary"] as FleetSummary?;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _dialPhone(String phone) async {
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openWhatsApp(String phone, String name) async {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('0')) clean = '2$clean';
    final msg = Uri.encodeComponent("السلام عليكم يا كابتن $name، بخصوص متابعة حركة أسطول في ثواني...");
    final uri = Uri.parse("https://wa.me/$clean?text=$msg");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تسجيل الخروج"),
          content: const Text("هل تريد تسجيل الخروج من لوحة مدير الأسطول؟"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("تسجيل الخروج"),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _authRepo.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  List<FleetRider> get _filteredRiders {
    return _riders.filter((r) {
      if (_filter != "all" && r.status != _filter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = r.name.toLowerCase().contains(q);
        final phoneMatches = r.phone.contains(q);
        return nameMatches || phoneMatches;
      }
      return true;
    }).toList();
  }

  void _focusRiderOnMap(FleetRider r) {
    setState(() => _currentTabIndex = 0);
    Future.delayed(const Duration(milliseconds: 200), () {
      _mapController.move(LatLng(r.lat, r.lng), 16.0);
      _showRiderDetailSheet(r);
    });
  }

  void _showRiderDetailSheet(FleetRider r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _statusColor(r.status).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.two_wheeler, color: _statusColor(r.status), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text("${r.vehicleType} • ${r.zoneName}", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(r.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _statusColor(r.status)),
                    ),
                    child: Text(_statusLabel(r.status), style: TextStyle(color: _statusColor(r.status), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Indicators Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricCol("أوردرات اليوم", "${r.todayOrdersCount}", Icons.inventory_2_outlined, const Color(0xFF38BDF8)),
                    _metricCol("سرعة التوصيل", "${r.averageDeliveryMinutes} دقيقة", Icons.speed, const Color(0xFFFBBF24)),
                    _metricCol("التقييم", "⭐ ${r.rating}", Icons.star, const Color(0xFFF59E0B)),
                    _metricCol("الكاش معه", "${r.cashOnHandEgp.toStringAsFixed(0)} ج.م", Icons.payments_outlined, const Color(0xFF4ADE80)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text("اتصال هاتفي", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _dialPhone(r.phone),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text("واتساب", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _openWhatsApp(r.phone, r.name),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCol(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "available":
        return const Color(0xFF22C55E); // Green
      case "delivering":
        return const Color(0xFF0284C7); // Blue
      default:
        return const Color(0xFF64748B); // Gray
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "available":
        return "🟢 متاح الآن";
      case "delivering":
        return "🔵 في مشوار توصيل";
      default:
        return "⚪ غير متصل";
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRiders;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primaryMint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hub_rounded, size: 18, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("غرفة عمليات أسطول في ثواني", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFF22C55E), size: 8),
                      SizedBox(width: 4),
                      Text("بث حي ومباشر لكافة الطيارين", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primaryMint),
              onPressed: () => _loadFleetData(),
              tooltip: "تحديث لحظي",
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
              onPressed: _handleLogout,
              tooltip: "خروج",
            ),
          ],
        ),
        body: Column(
          children: [
            // KPI Summary Strip
            if (_summary != null)
              Container(
                color: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _kpiBadge("إجمالي الأسطول", "${_summary!.totalRiders}", const Color(0xFF94A3B8)),
                    _kpiBadge("متاح الآن", "${_summary!.availableRiders}", const Color(0xFF22C55E)),
                    _kpiBadge("في مشاوير", "${_summary!.deliveringRiders}", const Color(0xFF0284C7)),
                    _kpiBadge("أوردرات اليوم", "${_summary!.totalTodayOrders}", const Color(0xFFFBBF24)),
                  ],
                ),
              ),

            // Tab Selector
            Container(
              padding: const EdgeInsets.all(8),
              color: const Color(0xFF0F172A),
              child: Row(
                children: [
                  Expanded(
                    child: _tabButton(
                      index: 0,
                      label: "🗺️ خريطة الأسطول الحية",
                      isSelected: _currentTabIndex == 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _tabButton(
                      index: 1,
                      label: "📋 قائمة الطيارين والمؤشرات (${_riders.length})",
                      isSelected: _currentTabIndex == 1,
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryMint))
                  : _currentTabIndex == 0
                      ? _buildLiveMap(filtered)
                      : _buildRidersList(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _tabButton({required int index, required String label, required bool isSelected}) {
    return InkWell(
      onTap: () => setState(() => _currentTabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryMint : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primaryMint : const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  // Tab 1: Live Interactive OpenStreetMap
  Widget _buildLiveMap(List<FleetRider> riders) {
    final markers = riders.map((r) {
      final color = _statusColor(r.status);
      return Marker(
        point: LatLng(r.lat, r.lng),
        width: 100,
        height: 55,
        child: GestureDetector(
          onTap: () => _showRiderDetailSheet(r),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color, width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                ),
                child: Text(
                  r.name.split(' ').first,
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.location_on, color: color, size: 28),
            ],
          ),
        ),
      );
    }).toList();

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(31.037, 30.472), // Centered on Damanhour / Al Nassriya
        initialZoom: 14.2,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.fesawany.captain',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  // Tab 2: Full Detailed Riders List & Indicators
  Widget _buildRidersList(List<FleetRider> riders) {
    return Column(
      children: [
        // Search & Filter Strip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: "بحث باسم الطيار أو رقم الموبايل...",
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip("الكل", "all"),
                    _filterChip("🟢 متاح الآن", "available"),
                    _filterChip("🔵 في مشوار", "delivering"),
                    _filterChip("⚪ غير متصل", "offline"),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: riders.isEmpty
              ? const Center(
                  child: Text("لا يوجد طيارين مطابقين للبحث", style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: riders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) => _buildRiderCard(riders[idx]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF0F172A) : Colors.white)),
        selected: isSelected,
        selectedColor: AppColors.primaryMint,
        backgroundColor: const Color(0xFF1E293B),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _buildRiderCard(FleetRider r) {
    final color = _statusColor(r.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withOpacity(0.2),
                    child: Icon(Icons.two_wheeler, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text("${r.vehicleType} • ${r.phone}", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color),
                ),
                child: Text(_statusLabel(r.status), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Live Metrics Row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem("أوردرات اليوم", "${r.todayOrdersCount}", const Color(0xFF38BDF8)),
                _statItem("إجمالي الطلبات", "${r.totalDeliveries}", Colors.white70),
                _statItem("سرعة التوصيل", "${r.averageDeliveryMinutes} د", const Color(0xFFFBBF24)),
                _statItem("التقييم", "⭐ ${r.rating}", const Color(0xFFF59E0B)),
                _statItem("الكاش معه", "${r.cashOnHandEgp.toStringAsFixed(0)} ج", const Color(0xFF4ADE80)),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text("تتبع على الخريطة", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _focusRiderOnMap(r),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.phone, size: 18, color: Color(0xFF0284C7)),
                onPressed: () => _dialPhone(r.phone),
                tooltip: "اتصال",
              ),
              IconButton(
                icon: const Icon(Icons.chat, size: 18, color: Color(0xFF22C55E)),
                onPressed: () => _openWhatsApp(r.phone, r.name),
                tooltip: "واتساب",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
      ],
    );
  }
}

extension IterableExtension<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) {
    return where(test);
  }
}
