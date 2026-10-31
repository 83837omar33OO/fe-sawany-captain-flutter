import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/audio_alert_service.dart';
import '../../../core/services/telemetry_service.dart';
import '../../../core/network/api_client.dart';
import '../data/active_order_repository.dart';
import '../models/active_order.dart';
import '../../radar/models/available_order.dart';
import 'delivery_exception_dialog.dart';
import 'order_completion_celebration_dialog.dart';

class ActiveDeliveriesTab extends StatefulWidget {
  const ActiveDeliveriesTab({super.key});

  @override
  State<ActiveDeliveriesTab> createState() => _ActiveDeliveriesTabState();
}

class _ActiveDeliveriesTabState extends State<ActiveDeliveriesTab>
    with SingleTickerProviderStateMixin {
  final _activeRepo = ActiveOrderRepository();
  final _telemetry = TelemetryService();
  final _connectivity = Connectivity();

  late TabController _tabController;
  StreamSubscription? _connectivitySubscription;
  Timer? _pollingTimer;

  bool _isLoading = true;
  bool _isActionLoading = false;
  bool _isOffline = false;
  bool _isSuspended = false;
  String? _suspensionError;

  List<ActiveOrder> _activeOrders = [];
  List<AvailableOrder> _availableOrders = [];
  int _maxActiveOrders = 1;
  int _lastAvailableCount = 0;

  // Track expanded item list per order
  final Set<String> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);

    _telemetry.startStreaming();
    _telemetry.setSuspensionListener((suspended, message) {
      if (mounted) {
        setState(() {
          _isSuspended = suspended;
          if (message != null) _suspensionError = message;
        });
      }
    });

    _loadData();

    // Auto-refresh every 8 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!_isOffline) _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _connectivitySubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (_) {}
  }

  void _updateConnectionStatus(dynamic results) {
    bool offline = false;
    if (results is List<ConnectivityResult>) {
      offline = results.isEmpty || results.contains(ConnectivityResult.none);
    } else if (results is ConnectivityResult) {
      offline = results == ConnectivityResult.none;
    }
    if (mounted && _isOffline != offline) {
      setState(() => _isOffline = offline);
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final data = await _activeRepo.fetchDeliveriesData();
      final List<ActiveOrder> active = data["activeOrders"] ?? [];
      final List<AvailableOrder> available = data["availableOrders"] ?? [];
      final bool suspended = data["isSuspended"] == true;
      final int maxOrders = (data["rider"]?["maxActiveOrders"] as num?)?.toInt() ?? 1;

      if (available.length > _lastAvailableCount && _lastAvailableCount >= 0) {
        AudioAlertService.triggerNewOrderAlert();
      }
      _lastAvailableCount = available.length;

      if (mounted) {
        setState(() {
          _activeOrders = active;
          _availableOrders = available;
          _isSuspended = suspended;
          _maxActiveOrders = maxOrders;
          _isOffline = false;
        });
      }
    } catch (e) {
      if (e is ApiException && e.code == "ACCOUNT_SUSPENDED") {
        if (mounted) {
          setState(() {
            _isSuspended = true;
            _suspensionError = e.message;
          });
        }
      }
    } finally {
      if (!silent && mounted) setState(() => _isLoading = false);
    }
  }

  void _dialPhone(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWhatsApp(String phone, String orderRef) async {
    if (phone.isEmpty) return;
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = '2$cleanPhone';
    final message = Uri.encodeComponent("مساء الخير يا فندم، أنا كابتن في ثواني بخصوص طلبك رقم #$orderRef");
    final uri = Uri.parse("https://wa.me/$cleanPhone?text=$message");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openNavigation({double? lat, double? lng, required String addressQuery}) async {
    Uri uri;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      uri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
    } else {
      final encoded = Uri.encodeComponent("$addressQuery, الناصرية القديمة, الإسكندرية, مصر");
      uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encoded");
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleClaim(String orderId) async {
    if (_activeOrders.length >= _maxActiveOrders) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("الحد الأقصى لحسابك ($_maxActiveOrders) طلب نشط. سلّم طلبك الحالي أولاً."),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _activeRepo.claimOrder(orderId);
      AudioAlertService.triggerSuccessFeedback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم قبول الطلب بنجاح! توجه للمحل الآن 🛵"),
            backgroundColor: AppColors.primary,
          ),
        );
      }
      await _loadData();
      _tabController.animateTo(1);
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

  Future<void> _handleReject(String orderId) async {
    setState(() => _isActionLoading = true);
    try {
      await _activeRepo.rejectOrder(orderId);
      await _loadData();
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
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم تأكيد الاستلام من المحل، وفي الطريق للعميل 🛵"),
            backgroundColor: AppColors.primary,
          ),
        );
      }
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
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 26),
              SizedBox(width: 8),
              Text("تأكيد التسليم والتحصيل", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "طلب #${order.orderReference}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMutedLight),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("المطلوب كاش:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(
                      "${order.totalCashToCollect.toStringAsFixed(0)} ج.م",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "هل قمت بتسليم الطلب للعميل واستلام كامل المبلغ؟",
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("رجوع"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("نعم، تم التسليم والتحصيل", style: TextStyle(fontWeight: FontWeight.bold)),
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
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => OrderCompletionCelebrationDialog(
              order: order,
              onDismiss: () => _loadData(),
            ),
          );
        }
        await _loadData();
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

  Future<void> _showUpdatePricingDialog(ActiveOrder order) async {
    final Map<String, TextEditingController> controllers = {};
    for (final item in order.items) {
      final key = item.productId ?? item.productName;
      controllers[key] = TextEditingController(
        text: item.unitPrice > 0 ? item.unitPrice.toStringAsFixed(0) : "",
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: AppColors.warning, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "تعديل أسعار الفاتورة الفعلية",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...order.items.map((item) {
                    final key = item.productId ?? item.productName;
                    final ctrl = controllers[key];
                    if (ctrl == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "الكمية: ${item.quantity} • الحالي: ${item.unitPrice} ج.م",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 85,
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                suffixText: "ج",
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final List<Map<String, dynamic>> priceList = [];
                controllers.forEach((key, controller) {
                  final val = double.tryParse(controller.text.trim());
                  if (val != null) {
                    priceList.add({"productId": key, "unitPrice": val});
                  }
                });

                if (priceList.isNotEmpty) {
                  setState(() => _isActionLoading = true);
                  try {
                    await _activeRepo.updatePricing(order.id, priceList);
                    await _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("تم تحديث أسعار الفاتورة بنجاح"),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("تعذر حفظ الأسعار، تحقق من الاتصال."),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isActionLoading = false);
                  }
                }
              },
              child: const Text("حفظ الفاتورة"),
            ),
          ],
        ),
      ),
    );
  }

  void _showException(String orderId) {
    showDialog(
      context: context,
      builder: (_) => DeliveryExceptionDialog(
        onSubmit: (reason, notes) async {
          setState(() => _isActionLoading = true);
          try {
            await _activeRepo.reportDeliveryIssue(orderId, reason, notes);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("تم تسجيل البلاغ وإشعار غرفة العمليات"),
                  backgroundColor: AppColors.danger,
                ),
              );
            }
            await _loadData();
          } catch (_) {
          } finally {
            if (mounted) setState(() => _isActionLoading = false);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("الطلبات", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          actions: [
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh_rounded),
              onPressed: () => _loadData(),
              tooltip: "تحديث",
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryMint,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("عروض الرادار"),
                    if (_availableOrders.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${_availableOrders.length}",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("طلبات بعهدتي"),
                    if (_activeOrders.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${_activeOrders.length}",
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Offline Warning Strip
            if (_isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                color: AppColors.danger,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      "غير متصل بالإنترنت - يتم عرض البيانات المحفوظة",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            // Main Content Area
            Expanded(
              child: _isSuspended
                  ? _buildSuspendedScreen(isDark)
                  : _isLoading && _activeOrders.isEmpty && _availableOrders.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Available Offers
                            RefreshIndicator(
                              onRefresh: () => _loadData(),
                              child: _availableOrders.isEmpty
                                  ? _buildEmptyState("لا توجد عروض جديدة متاحة بالرادار حالياً", isDark)
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _availableOrders.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                                      itemBuilder: (ctx, idx) => _buildOfferCard(_availableOrders[idx], isDark),
                                    ),
                            ),

                            // Tab 2: Active Orders
                            RefreshIndicator(
                              onRefresh: () => _loadData(),
                              child: _activeOrders.isEmpty
                                  ? _buildEmptyState("لا توجد طلبات جارية بعهدتك حالياً", isDark)
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _activeOrders.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                                      itemBuilder: (ctx, idx) => _buildActiveOrderCard(_activeOrders[idx], isDark),
                                    ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.two_wheeler_outlined, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "أنت متصل وجاهز فور ورود أي طلب جديد.",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Ultra-Clean Active Order Card (NO nested boxes within boxes)
  Widget _buildActiveOrderCard(ActiveOrder ord, bool isDark) {
    final isOut = ord.status == "out_for_delivery";
    final cardId = ord.id;
    final isItemsExpanded = _expandedItems.contains(cardId);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: Order Ref + Status Pill
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOut ? AppColors.primary : AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "طلب #${ord.orderReference}",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOut
                        ? (isDark ? AppColors.primaryMint.withOpacity(0.18) : AppColors.primaryLight)
                        : (isDark ? AppColors.warning.withOpacity(0.18) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isOut ? "في الطريق للعميل 🛵" : "استلام من المحل 🏪",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isOut ? (isDark ? AppColors.primaryMint : AppColors.primary) : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 2. Open Route Flow (Store -> Customer) - Minimal, zero nested boxes!
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                // Store Step
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.storefront_rounded, size: 20, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ord.storeName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ord.storeAddress,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ord.storePhone != null && ord.storePhone!.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.phone_outlined, size: 20, color: AppColors.warning),
                        onPressed: () => _dialPhone(ord.storePhone!),
                        tooltip: "اتصال بالمحل",
                      ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.only(right: 9, top: 4, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 16,
                      child: VerticalDivider(width: 1, thickness: 1.5, color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),

                // Customer Step
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ord.customerName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ord.customerAddress,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                          if (ord.customerNotes != null && ord.customerNotes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "💡 ${ord.customerNotes}",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Three 1-Tap Ergonomic Action Pills (Direct Call, WhatsApp, Navigation)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // 1-Tap Call
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.surfaceDarkHover : const Color(0xFFF1F5F9),
                      foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
                      elevation: 0,
                      minimumSize: const Size(0, 42),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _dialPhone(ord.customerPhone),
                    icon: const Icon(Icons.phone_rounded, size: 16, color: AppColors.primary),
                    label: const Text("اتصال", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),

                // 1-Tap Direct WhatsApp (wa.me)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366).withOpacity(0.12),
                      foregroundColor: const Color(0xFF25D366),
                      elevation: 0,
                      minimumSize: const Size(0, 42),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _openWhatsApp(ord.customerPhone, ord.orderReference ?? ord.id),
                    icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFF25D366)),
                    label: const Text("واتساب", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),

                // 1-Tap Google Maps Navigation
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.surfaceDarkHover : const Color(0xFFF1F5F9),
                      foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
                      elevation: 0,
                      minimumSize: const Size(0, 42),
                      padding: EdgeInsets.zero,
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
                    icon: const Icon(Icons.near_me_rounded, size: 16, color: AppColors.info),
                    label: const Text("ملاحة", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 4. Items Summary Bar (Expandable on tap)
          InkWell(
            onTap: () {
              setState(() {
                if (isItemsExpanded) {
                  _expandedItems.remove(cardId);
                } else {
                  _expandedItems.add(cardId);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "محتويات الطلب (${ord.items.length} أصناف • ${ord.totalPiecesCount} قطع)",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                  Icon(
                    isItemsExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ],
              ),
            ),
          ),

          if (isItemsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: ord.items
                    .map(
                      (it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${it.productName} (× ${it.quantity})",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              it.unitPrice > 0 ? "${it.itemTotal.toStringAsFixed(0)} ج.م" : "سعر تقريبي",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

          // 5. Cash Collection Strip (High visibility, zero clutter)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryMint.withOpacity(0.12) : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "المطلوب تحصيله كاش:",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.primaryMint : AppColors.primary,
                      ),
                    ),
                    Text(
                      "${ord.totalCashToCollect.toStringAsFixed(0)} ج.م",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.primaryMint : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "+${ord.riderEarning.toStringAsFixed(0)} ج.م أرباحك",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.primaryMint : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 6. Primary Action Progression Button (52dp height)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isOut) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isActionLoading ? null : () => _handlePickup(ord.id),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                    label: const Text(
                      "استلمت وبدء التوجه للعميل 🚀",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _showUpdatePricingDialog(ord),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text("تعديل الفاتورة 📝", style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _showException(ord.id),
                          icon: const Icon(Icons.warning_amber_rounded, size: 18),
                          label: const Text("إبلاغ عن مشكلة ⚠️", style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isActionLoading ? null : () => _handleComplete(ord),
                    icon: const Icon(Icons.done_all_rounded, size: 22),
                    label: Text(
                      "تم التسليم والتحصيل (${ord.totalCashToCollect.toStringAsFixed(0)} ج.م) ✓",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onPressed: () => _showException(ord.id),
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: const Text("إبلاغ عن مشكلة في التوصيل", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Ultra-Clean Offer Card (Pre-acceptance)
  Widget _buildOfferCard(AvailableOrder offer, bool isDark) {
    final canClaim = _activeOrders.length < _maxActiveOrders;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Store Name + Earnings Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    offer.storeName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primaryMint.withOpacity(0.18) : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "+${offer.deliveryEarning.toStringAsFixed(0)} ج.م أرباحك",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.primaryMint : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Route: Pickup -> Delivery
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "من: ${offer.storeArea} ⬅️ إلى: ${offer.deliveryArea}",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ),
          ),

          if (offer.customerNotes != null && offer.customerNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "💡 ${offer.customerNotes}",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Summary Numbers (Items & Cash)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${offer.items.length} أصناف • ${offer.totalPiecesCount} قطع",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                Text(
                  "المطلوب كاش: ${offer.totalToCollect.toStringAsFixed(0)} ج.م",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.primaryMint : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons (52dp)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canClaim ? AppColors.primary : Colors.grey,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isActionLoading
                        ? null
                        : canClaim
                            ? () => _handleClaim(offer.id)
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("الحد الأقصى ممتلئ ($_maxActiveOrders)."),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              },
                    child: Text(
                      canClaim ? "قبول واستلام الطلب ⚡" : "الحد ممتلئ ($_maxActiveOrders)",
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : AppColors.textMutedLight,
                    side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isActionLoading ? null : () => _handleReject(offer.id),
                  child: const Text("تخطي"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuspendedScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, size: 64, color: AppColors.danger),
            ),
            const SizedBox(height: 18),
            const Text(
              "حساب الكابتن موقوف مؤقتاً 🔒",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _suspensionError ?? "تم إيقاف حسابك من قبل إدارة العمليات. تواصل مع المشرف للاستيضاح.",
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _dialPhone("01034293703"),
              icon: const Icon(Icons.phone_in_talk, size: 20),
              label: const Text("اتصال بغرفة العمليات (01034293703)"),
            ),
          ],
        ),
      ),
    );
  }
}
