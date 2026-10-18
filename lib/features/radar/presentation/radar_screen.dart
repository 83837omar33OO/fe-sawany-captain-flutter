import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/audio_alert_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../duty/presentation/duty_switch_widget.dart';
import '../data/radar_repository.dart';
import '../models/available_order.dart';
import '../../active_delivery/data/active_order_repository.dart';
import '../../active_delivery/models/active_order.dart';
import '../../active_delivery/presentation/delivery_exception_dialog.dart';

class RadarScreen extends StatefulWidget {
  final VoidCallback onOpenWallet;
  final VoidCallback onLogout;

  const RadarScreen({
    super.key,
    required this.onOpenWallet,
    required this.onLogout,
  });

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final _radarRepo = RadarRepository();
  final _activeRepo = ActiveOrderRepository();

  bool _isOnline = true;
  bool _isToggling = false;
  bool _isLoading = true;
  bool _isActionLoading = false;

  List<AvailableOrder> _availableOrders = [];
  List<ActiveOrder> _activeOrders = [];
  String _riderName = "كابتن في ثواني";
  String _riderZone = "الناصرية القديمة";
  int _lastKnownAvailableCount = 0;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await SecureStorageService.getRiderProfile();
    setState(() {
      _riderName = profile["name"] ?? "كابتن في ثواني";
      _riderZone = profile["zone"] ?? "الناصرية القديمة";
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_isOnline) {
        _fetchData(isSilent: true);
      }
    });
  }

  Future<void> _fetchData({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);

    try {
      final available = await _radarRepo.getAvailableOrders();
      final active = await _activeRepo.getActiveOrders();

      // Trigger loud alert & vibration when new orders arrive
      if (available.length > _lastKnownAvailableCount) {
        AudioAlertService.triggerNewOrderAlert();
      }
      _lastKnownAvailableCount = available.length;

      if (mounted) {
        setState(() {
          _availableOrders = available;
          _activeOrders = active;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !isSilent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleDuty(bool value) async {
    setState(() => _isToggling = true);
    try {
      await _radarRepo.toggleDuty(value);
      setState(() => _isOnline = value);
      AudioAlertService.triggerSuccessFeedback();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Future<void> _handleClaim(String orderId) async {
    setState(() => _isActionLoading = true);
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
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handlePickup(String orderId) async {
    setState(() => _isActionLoading = true);
    try {
      await _activeRepo.pickupOrder(orderId);
      AudioAlertService.triggerSuccessFeedback();
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleComplete(ActiveOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("تأكيد التسليم والتحصيل"),
          content: Text(
            "هل تم تسليم الطلب للعميل وتحصيل مبلغ ${order.totalCashToCollect} ج.م نقداً بنجاح؟",
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("نعم، تم التسليم"),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isActionLoading = true);
      try {
        await _activeRepo.completeDelivery(order.id);
        AudioAlertService.triggerSuccessFeedback();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("ألف مبروك! تم تسجيل تسليم الطلب وإيداع أرباحك بالمحفظة."),
              backgroundColor: AppColors.primary,
            ),
          );
        }
        await _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
          );
        }
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  void _handleDial(String phone) async {
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _handleOpenMaps(String query) async {
    final encoded = Uri.encodeComponent("$query, مركز دمنهور, البحيرة");
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encoded");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showExceptionDialog(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => DeliveryExceptionDialog(
        onSubmit: (reason, details) async {
          setState(() => _isActionLoading = true);
          try {
            await _activeRepo.reportException(orderId, reason, details);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("تم إرسال تقرير التعثر للمشرف وجاري المتابعة."),
                  backgroundColor: AppColors.warning,
                ),
              );
            }
            await _fetchData();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
              );
            }
          } finally {
            if (mounted) setState(() => _isActionLoading = false);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_riderName),
          leading: IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: "المحفظة والعهد",
            onPressed: widget.onOpenWallet,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "تسجيل الخروج",
              onPressed: widget.onLogout,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _fetchData(),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Top Circular Duty Switch Section
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: DutySwitchWidget(
                  isOnline: _isOnline,
                  isToggling: _isToggling,
                  onToggle: _toggleDuty,
                ),
              ),
              const SizedBox(height: 16),

              // Active Deliveries (Post-Claim Section)
              if (_activeOrders.isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.directions_bike, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "الطلب الجاري توصيله",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slateDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._activeOrders.map((order) => _buildActiveOrderCard(order)),
                const SizedBox(height: 16),
              ],

              // Radar Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.radar, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Text(
                        AppStrings.radarTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slateDark,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${_availableOrders.length} متاح",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Radar List / Empty State
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_availableOrders.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    child: Column(
                      children: [
                        Text("📡", style: TextStyle(fontSize: 40)),
                        SizedBox(height: 12),
                        Text(
                          AppStrings.radarEmpty,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 6),
                        Text(
                          AppStrings.radarSearching,
                          style: TextStyle(fontSize: 12, color: AppColors.slateLight),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._availableOrders.map((ord) => _buildAvailableOrderCard(ord)),
            ],
          ),
        ),
      ),
    );
  }

  // Pre-claim card (Privacy-First)
  Widget _buildAvailableOrderCard(AvailableOrder ord) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFDE68A), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ord.storeName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryMint),
                  ),
                  child: Text(
                    "أرباحك: ${ord.deliveryEarning.toStringAsFixed(0)} ج.م",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.storefront, size: 16, color: AppColors.slateLight),
                const SizedBox(width: 6),
                Text(
                  "المحل: ${ord.storeArea}",
                  style: const TextStyle(fontSize: 12, color: AppColors.slateMedium),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.slateLight),
                const SizedBox(width: 6),
                Text(
                  "نطاق التوصيل: ${ord.deliveryArea}",
                  style: const TextStyle(fontSize: 12, color: AppColors.slateMedium),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "إجمالي كاش الفاتورة للتحصيل: ${ord.orderValue.toStringAsFixed(0)} ج.م",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC2410C),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _isActionLoading ? null : () => _handleClaim(ord.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                "⚡ قبول واستلام الطلب فوراً",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Active delivery card (Post-Claim: Revealed customer data & actions)
  Widget _buildActiveOrderCard(ActiveOrder order) {
    final isOutForDelivery = order.status == "out_for_delivery";

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.primaryMint, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOutForDelivery ? AppColors.infoLight : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOutForDelivery ? "🚀 في الطريق للعميل" : "⏳ توجه للمحل للاستلام",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOutForDelivery ? AppColors.info : AppColors.primary,
                    ),
                  ),
                ),
                Text(
                  "طلب #${order.orderReference}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slateLight),
                ),
              ],
            ),
            const Divider(height: 20),

            // Store Info
            Text(
              "1. استلام من: ${order.storeName}",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              order.storeAddress,
              style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (order.storePhone != null && order.storePhone!.isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(90, 36)),
                    icon: const Icon(Icons.phone, size: 14),
                    label: const Text("المحل", style: TextStyle(fontSize: 11)),
                    onPressed: () => _handleDial(order.storePhone!),
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(90, 36)),
                  icon: const Icon(Icons.map, size: 14),
                  label: const Text("خريطة", style: TextStyle(fontSize: 11)),
                  onPressed: () => _handleOpenMaps(order.storeAddress),
                ),
              ],
            ),
            const Divider(height: 20),

            // Customer Info (Revealed)
            Text(
              "2. تسليم إلى: ${order.customerName}",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              order.customerAddress,
              style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
            ),
            if (order.customerNotes != null && order.customerNotes!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "ملاحظة العميل: ${order.customerNotes}",
                  style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(120, 38),
                  ),
                  icon: const Icon(Icons.call, size: 16, color: Colors.white),
                  label: const Text("اتصال بالعميل", style: TextStyle(fontSize: 12, color: Colors.white)),
                  onPressed: () => _handleDial(order.customerPhone),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(110, 38)),
                  icon: const Icon(Icons.navigation, size: 16),
                  label: const Text("ملاحة GPS", style: TextStyle(fontSize: 12)),
                  onPressed: () => _handleOpenMaps(order.customerAddress),
                ),
              ],
            ),
            const Divider(height: 20),

            // Cash & Stage Transition Buttons
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("أرباح مشوارك", style: TextStyle(fontSize: 11, color: AppColors.slateLight)),
                      Text(
                        "+${order.riderEarning.toStringAsFixed(0)} ج.م",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("الكاش للتحصيل", style: TextStyle(fontSize: 11, color: AppColors.slateLight)),
                      Text(
                        "${order.totalCashToCollect.toStringAsFixed(0)} ج.م",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slateDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (!isOutForDelivery)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
                onPressed: _isActionLoading ? null : () => _handlePickup(order.id),
                child: const Text("🛍️ تم استلام الأوردر من المحل"),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _isActionLoading ? null : () => _handleComplete(order),
                child: Text("✅ تم التسليم وتحصيل ${order.totalCashToCollect.toStringAsFixed(0)} ج.م"),
              ),

            const SizedBox(height: 6),
            TextButton.icon(
              icon: const Icon(Icons.report_problem_outlined, size: 16, color: AppColors.danger),
              label: const Text("الإبلاغ عن مشكلة أو تعثر التسليم", style: TextStyle(fontSize: 12, color: AppColors.danger)),
              onPressed: () => _showExceptionDialog(order.id),
            ),
          ],
        ),
      ),
    );
  }
}
