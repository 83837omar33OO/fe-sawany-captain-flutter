import 'dart:async';
import 'package:flutter/material.dart';
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

  // Track expanded state for cards (collapsible sections)
  final Set<String> _expandedItems = {};
  final Set<String> _expandedStores = {};
  final Set<String> _expandedCustomers = {};

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
      final encoded = Uri.encodeComponent("$addressQuery, دمنهور, البحيرة, مصر");
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
          content: Text(
            "عفواً، الحد الأقصى لحسابك هو ($_maxActiveOrders) طلب نشط في نفس الوقت. سلّم طلبك الحالي أولاً.",
          ),
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
            content: Text("تم قبول الطلب ونقله لعهدتك بنجاح! توجه للمحل الآن 🛵"),
            backgroundColor: AppColors.primaryMint,
          ),
        );
      }
      await _loadData();
      _tabController.animateTo(1); // Auto switch to active tab
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم تخطي العرض بنجاح.")),
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

  Future<void> _handlePickup(String orderId) async {
    setState(() => _isActionLoading = true);
    try {
      await _activeRepo.pickupOrder(orderId);
      AudioAlertService.triggerSuccessFeedback();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم تأكيد الاستلام من المحل، وفي الطريق للعميل 🚀"),
            backgroundColor: Color(0xFF0284C7),
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
              Icon(Icons.check_circle, color: AppColors.primaryMint, size: 28),
              SizedBox(width: 8),
              Text("تأكيد التسليم والتحصيل", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "طلب #${order.orderReference}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("المبلغ المطلوب تحصيله كاش:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(
                      "${order.totalCashToCollect.toStringAsFixed(0)} ج.م",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "هل قمت بتسليم الطلب للعميل واستلام كامل المبلغ بنجاح؟",
                style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("رجوع", style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMint,
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "مبروك! تم إتمام الطلب وإضافة +${order.riderEarning.toStringAsFixed(0)} ج.م لمحفظتك 💰",
              ),
              backgroundColor: AppColors.primaryMint,
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

    final notesCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.receipt_long, color: Color(0xFFD97706), size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "تسجيل أسعار الفاتورة الفعلية",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      "أدخل سعر كل صنف حسب فاتورة المحل. سيتم حفظ الحركة في سجل الرقابة وتحديث الإجمالي للعميل.",
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...order.items.map((item) {
                    final key = item.productId ?? item.productName;
                    final ctrl = controllers[key];
                    if (ctrl == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "الكمية: ${item.quantity} • السعر الحالي: ${item.unitPrice} ج.م",
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 85,
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: "ج.م",
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: "ملاحظة توضيحية لتعديل السعر (اختياري)",
                      labelStyle: const TextStyle(fontSize: 11),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
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
                backgroundColor: AppColors.primaryMint,
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

                    // Prompt rider to call customer about price change
                    if (mounted) {
                      _showPriceChangeCallDialog(order);
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
              child: const Text("حفظ الفاتورة وتحديث الحساب", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceChangeCallDialog(ActiveOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.phone_forwarded, color: Color(0xFF0284C7), size: 26),
              SizedBox(width: 8),
              Text("تم تحديث أسعار الفاتورة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "تم تسجيل تعديل الأسعار بالسيرفر وسجل الرقابة بنجاح.",
                style: TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Text(
                  "يُوصى بالاتصال بالعميل (${order.customerName}) فوراً لإبلاغه بالقيمة المعدلة لتفادي أي التباس عند التسليم.",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("لاحقاً"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _dialPhone(order.customerPhone);
              },
              icon: const Icon(Icons.phone, size: 18),
              label: Text("اتصال بالعميل (${order.customerPhone})"),
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
                  content: Text("تم تسجيل البلاغ وإشعار غرفة العمليات والمشرف."),
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
          title: const Text("إدارة واستلام الطلبات", style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh),
              onPressed: () => _loadData(),
              tooltip: "تحديث",
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryMint,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("عروض جديدة"),
                    if (_availableOrders.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
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
                          "${_activeOrders.length}/$_maxActiveOrders",
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
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
            // Offline Warning Banner
            if (_isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                color: const Color(0xFFEF4444),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      "أنت غير متصل بالإنترنت - يتم عرض البيانات المحفوظة محلياً",
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            // Main Body
            Expanded(
              child: _isSuspended
                  ? _buildSuspendedScreen(isDark)
                  : _isLoading && _activeOrders.isEmpty && _availableOrders.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryMint))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Available Offers
                            RefreshIndicator(
                              onRefresh: () => _loadData(),
                              child: _availableOrders.isEmpty
                                  ? _buildEmptyState("لا توجد عروض جديدة متاحة حالياً بالرادار", isDark)
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(14),
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
                                      padding: const EdgeInsets.all(14),
                                      itemCount: _activeOrders.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 14),
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
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.two_wheeler_outlined, size: 48, color: AppColors.primaryMint),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.slateDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                "أنت متصل وجاهز للاستقبال فور ورود طلب جديد.",
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Offer Card (Pre-acceptance with full details preview)
  Widget _buildOfferCard(AvailableOrder offer, bool isDark) {
    final canClaim = _activeOrders.length < _maxActiveOrders;
    final cardId = "offer-${offer.id}";
    final isItemsExpanded = _expandedItems.contains(cardId);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBEB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFFD97706), size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      "عرض طلب جديد متاح",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
                Text(
                  "طلب #${offer.orderReference}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF78350F)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Store & Area Info
                Row(
                  children: [
                    const Icon(Icons.storefront, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        offer.storeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        "+${offer.deliveryEarning.toStringAsFixed(0)} ج.م أجر الكابتن",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "من: ${offer.storeArea} ⬅️ إلى: ${offer.deliveryArea}",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),

                // Collapsible Items Breakdown
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
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.list_alt, size: 16, color: Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            Text(
                              "محتويات الطلب (${offer.items.length} أصناف • ${offer.totalPiecesCount} قطع)",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Icon(
                          isItemsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 18,
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),

                if (isItemsExpanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: offer.items.map((it) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "${it.productName} (× ${it.quantity})",
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Text(
                                it.unitPrice > 0 ? "${it.itemTotal.toStringAsFixed(0)} ج.م" : "سعر تقريبي",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "قيمة الطلب: ${offer.orderValue.toStringAsFixed(0)} ج.م",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canClaim ? AppColors.primaryMint : Colors.grey,
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isActionLoading
                            ? null
                            : canClaim
                                ? () => _handleClaim(offer.id)
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "وصلت للحد الأقصى للطلبات النشطة ($_maxActiveOrders). سلّم طلباتك الحالية أولاً.",
                                        ),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  },
                        icon: const Icon(Icons.two_wheeler, size: 18),
                        label: Text(
                          canClaim ? "قبول واستلام الطلب 🛵" : "الحد ممتلئ ($_maxActiveOrders)",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isActionLoading ? null : () => _handleReject(offer.id),
                      child: const Text("تخطي ✕", style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Active Order Card with Foldable Sections (Clean Arabic Design)
  Widget _buildActiveOrderCard(ActiveOrder ord, bool isDark) {
    final isOut = ord.status == "out_for_delivery";
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final cardId = "active-${ord.id}";
    final isItemsExpanded = _expandedItems.contains(cardId);
    final isStoreExpanded = _expandedStores.contains(cardId);
    final isCustomerExpanded = _expandedCustomers.contains(cardId);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Status + Order Ref
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOut
                  ? const Color(0xFF0284C7).withOpacity(0.12)
                  : const Color(0xFFD97706).withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isOut ? Icons.navigation_rounded : Icons.store_mall_directory_rounded,
                      size: 18,
                      color: isOut ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOut ? "في الطريق للعميل والتسليم 🚀" : "توجه للمحل لاستلام الطلب 🛵",
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Foldable Section 1: Store Info
                _buildCollapsibleHeader(
                  title: ord.storeName,
                  subtitle: ord.storeAddress,
                  icon: Icons.storefront,
                  iconColor: const Color(0xFFD97706),
                  isExpanded: isStoreExpanded,
                  onTap: () {
                    setState(() {
                      if (isStoreExpanded) {
                        _expandedStores.remove(cardId);
                      } else {
                        _expandedStores.add(cardId);
                      }
                    });
                  },
                ),
                if (isStoreExpanded) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            ord.storeAddress,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ),
                        if (ord.storePhone != null && ord.storePhone!.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.phone, color: Color(0xFF0284C7), size: 20),
                            onPressed: () => _dialPhone(ord.storePhone!),
                            tooltip: "اتصال بالمحل",
                          ),
                        IconButton(
                          icon: const Icon(Icons.directions, color: Color(0xFFD97706), size: 20),
                          onPressed: () => _openNavigation(addressQuery: "${ord.storeName} ${ord.storeAddress}"),
                          tooltip: "ملاحة للمحل",
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Foldable Section 2: Customer Info
                _buildCollapsibleHeader(
                  title: ord.customerName,
                  subtitle: ord.customerAddress,
                  icon: Icons.person_pin_circle,
                  iconColor: const Color(0xFF0284C7),
                  isExpanded: isCustomerExpanded,
                  onTap: () {
                    setState(() {
                      if (isCustomerExpanded) {
                        _expandedCustomers.remove(cardId);
                      } else {
                        _expandedCustomers.add(cardId);
                      }
                    });
                  },
                ),
                if (isCustomerExpanded) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "العنوان: ${ord.customerAddress}",
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                        if (ord.customerNotes != null && ord.customerNotes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            "ملاحظات: ${ord.customerNotes}",
                            style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _dialPhone(ord.customerPhone),
                              icon: const Icon(Icons.phone, size: 16),
                              label: const Text("اتصال", style: TextStyle(fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _openWhatsApp(ord.customerPhone, ord.orderReference ?? ord.id),
                              icon: const Icon(Icons.chat, size: 16),
                              label: const Text("واتساب", style: TextStyle(fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _openNavigation(
                                lat: ord.customerLat,
                                lng: ord.customerLng,
                                addressQuery: ord.customerAddress,
                              ),
                              icon: const Icon(Icons.navigation, size: 16),
                              label: const Text("ملاحة", style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Foldable Section 3: Detailed Invoice Items
                _buildCollapsibleHeader(
                  title: "تفاصيل الفاتورة والأصناف (${ord.items.length} أصناف • ${ord.totalPiecesCount} قطع)",
                  subtitle: "الإجمالي: ${ord.totalCashToCollect.toStringAsFixed(0)} ج.م",
                  icon: Icons.receipt_long,
                  iconColor: const Color(0xFF6366F1),
                  isExpanded: isItemsExpanded,
                  onTap: () {
                    setState(() {
                      if (isItemsExpanded) {
                        _expandedItems.remove(cardId);
                      } else {
                        _expandedItems.add(cardId);
                      }
                    });
                  },
                ),
                if (isItemsExpanded) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        ...ord.items.map((it) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "${it.productName} (× ${it.quantity})",
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  Text(
                                    it.unitPrice > 0 ? "${it.itemTotal.toStringAsFixed(0)} ج.م" : "سعر تقريبي",
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("المطلوب كاش من العميل:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            Text(
                              "${ord.totalCashToCollect.toStringAsFixed(0)} ج.م",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Cash Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("المطلوب تحصيله كاش:", style: TextStyle(fontSize: 11, color: Color(0xFF065F46))),
                          Text(
                            "${ord.totalCashToCollect.toStringAsFixed(0)} ج.م",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          "+${ord.riderEarning.toStringAsFixed(0)} ج.م أجر التوصيل لك",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Lifecycle Buttons
                if (!isOut) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isActionLoading ? null : () => _handlePickup(ord.id),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text("استلمت وبدء التوجه للعميل 🚀", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706),
                      side: const BorderSide(color: Color(0xFFD97706)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showUpdatePricingDialog(ord),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text("تسجيل / تعديل أسعار الفاتورة 📝", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMint,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isActionLoading ? null : () => _handleComplete(ord),
                    icon: const Icon(Icons.done_all, size: 20),
                    label: Text(
                      "تم التسليم وتحصيل (${ord.totalCashToCollect.toStringAsFixed(0)} ج.م) ✅",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],

                const SizedBox(height: 6),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                  onPressed: () => _showException(ord.id),
                  icon: const Icon(Icons.warning_amber_rounded, size: 16),
                  label: const Text("إبلاغ عن مشكلة في التوصيل ⚠️", style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9).withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
              color: const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuspendedScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, size: 72, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 20),
            const Text(
              "حساب الكابتن موقوف ومجمد 🔒",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _suspensionError ??
                  "تم تجميد حسابك ومنعك من استقبال أو توصيل الطلبات من قبل إدارة العمليات والأسطول في ثواني. يرجى مراجعة الإدارة.",
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _dialPhone("01034293703"),
              icon: const Icon(Icons.phone_in_talk, size: 20),
              label: const Text("اتصال بإدارة العمليات (01034293703)"),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _loadData(),
              icon: const Icon(Icons.refresh),
              label: const Text("إعادة فحص حالة الحساب"),
            ),
          ],
        ),
      ),
    );
  }
}
