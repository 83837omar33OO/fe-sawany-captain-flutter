import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../data/active_order_repository.dart';
import '../models/active_order.dart';
import 'delivery_exception_dialog.dart';

class ActiveDeliveriesTab extends StatefulWidget {
  const ActiveDeliveriesTab({super.key});

  @override
  State<ActiveDeliveriesTab> createState() => _ActiveDeliveriesTabState();
}

class _ActiveDeliveriesTabState extends State<ActiveDeliveriesTab> {
  final _activeRepo = ActiveOrderRepository();
  bool _isLoading = true;
  bool _isActionLoading = false;
  List<ActiveOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final list = await _activeRepo.getActiveOrders();
      if (mounted) setState(() => _orders = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '2$cleanPhone';
    }
    final message = Uri.encodeComponent("مساء الخير يا فندم، أنا كابتن في ثواني بخصوص طلبك رقم #$orderRef");
    final uri = Uri.parse("https://wa.me/$cleanPhone?text=$message");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.price_change, color: Color(0xFFD97706), size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "تسجيل أسعار الأصناف من المحل",
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
                  const Text(
                    "أدخل السعر الفعلي لكل صنف من فاتورة الصيدلية/المحل لحساب الإجمالي بدقة للعميل:",
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                                if (item.customizationNote != null)
                                  Text(
                                    item.customizationNote!,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFFD97706)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 90,
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
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("تم تحديث أسعار الفاتورة بنجاح وتحديث حساب العميل!"),
                          backgroundColor: AppColors.primaryMint,
                        ),
                      );
                    }
                    await _loadOrders();
                  } catch (e) {
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

  void _openNavigation({double? lat, double? lng, required String addressQuery}) async {
    Uri uri;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      // Direct high-accuracy turn-by-turn navigation link
      uri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
    } else {
      final encoded = Uri.encodeComponent("$addressQuery, البحيرة, مصر");
      uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encoded");
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handlePickup(String orderId) async {
    setState(() => _isActionLoading = true);
    try {
      await _activeRepo.pickupOrder(orderId);
      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم استلام الطلب من المحل وجاري التوجه للعميل 🚀"),
            backgroundColor: Color(0xFF0284C7),
          ),
        );
      }
    } catch (_) {
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
              const SizedBox(height: 8),
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
                    const Text("المبلغ المطلوب تحصيله كاش:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      "${order.totalCashToCollect.toStringAsFixed(0)} ج.م",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text("هل قمت بتسليم الطلب للعميل واستلام المبلغ بنجاح؟", style: TextStyle(fontSize: 12)),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("مبروك! تم إتمام الطلب بنجاح وإضافة +${order.riderEarning.toStringAsFixed(0)} ج.م لمحفظتك."),
              backgroundColor: AppColors.primaryMint,
            ),
          );
        }
        await _loadOrders();
      } catch (_) {
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
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
            await _loadOrders();
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
          title: const Text("الطلبات الجارية بعهدتك", style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadOrders,
              tooltip: "تحديث",
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryMint))
            : _orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.two_wheeler_outlined, size: 54, color: AppColors.primaryMint),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "لا توجد طلبات جارية بعهدتك حالياً",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slateDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "افتح تبويب الرادار لاستلام وقبول طلبات جديدة.",
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadOrders,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (ctx, idx) => _buildDriverOrderCard(_orders[idx], isDark),
                    ),
                  ),
      ),
    );
  }

  Widget _buildDriverOrderCard(ActiveOrder ord, bool isDark) {
    final isOut = ord.status == "out_for_delivery";
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textDark = isDark ? Colors.white : AppColors.slateDark;

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
          // Header: Status + Order Ref + Time
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
                      size: 16,
                      color: isOut ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOut ? "المرحلة: في الطريق للعميل" : "المرحلة: توجه للمحل للاستلام",
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Customer Section (Large & Clear)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0xFFE2E8F0),
                                child: Icon(Icons.person, size: 16, color: Color(0xFF475569)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                ord.customerName,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
                              ),
                            ],
                          ),
                          // Phone & WhatsApp quick actions
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.phone, size: 20, color: Color(0xFF0284C7)),
                                tooltip: "اتصال هاتفي بالعميل",
                                onPressed: () => _dialPhone(ord.customerPhone),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chat_bubble, size: 20, color: Color(0xFF22C55E)),
                                tooltip: "شات واتساب مع العميل",
                                onPressed: () => _openWhatsApp(ord.customerPhone, ord.orderReference ?? ""),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ord.customerAddress,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Turn-by-Turn GPS Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.directions, size: 18),
                          label: Text(
                            ord.customerLat != null && ord.customerLng != null
                                ? "📍 فتح الملاحة لموقع العميل (GPS دقيق)"
                                : "🗺️ فتح خريطة عنوان العميل",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _openNavigation(
                            lat: ord.customerLat,
                            lng: ord.customerLng,
                            addressQuery: ord.customerAddress,
                          ),
                        ),
                      ),
                      if (ord.customerNotes != null && ord.customerNotes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            "ملاحظة العميل: ${ord.customerNotes}",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 2. Store Info Card
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront, size: 18, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "المحل: ${ord.storeName}",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                            ),
                            Text(
                              ord.storeAddress,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      if (ord.storePhone != null && ord.storePhone!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.phone, size: 18, color: Color(0xFF0284C7)),
                          onPressed: () => _dialPhone(ord.storePhone!),
                          tooltip: "اتصال بالمحل",
                          visualDensity: VisualDensity.compact,
                        ),
                      IconButton(
                        icon: const Icon(Icons.map, size: 18, color: Color(0xFF64748B)),
                        onPressed: () => _openNavigation(addressQuery: "${ord.storeName} ${ord.storeAddress}"),
                        tooltip: "خريطة المحل",
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3. Detailed Items & Pieces Breakdown
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "📦 محتويات الأوردر (${ord.totalPiecesCount} قطعة)",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "${ord.items.length} أصناف",
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      if (ord.items.isEmpty)
                        const Text("أصناف منوعة من المتجر الشريك", style: TextStyle(fontSize: 11, color: Color(0xFF64748B)))
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: ord.items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (ctx, i) {
                            final item = ord.items[i];
                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryMint.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${item.quantity}×",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryMint,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDark),
                                      ),
                                      if (item.storeName.isNotEmpty && item.storeName != ord.storeName)
                                        Text(
                                          "من: ${item.storeName}",
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "${item.itemTotal > 0 ? item.itemTotal.toStringAsFixed(0) : (item.quantity * item.unitPrice).toStringAsFixed(0)} ج.م",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),

                // 3b. Prescription Details Card (Pharmacy Orders)
                if (ord.prescriptionImageUrl != null || ord.prescriptionAudioUrl != null || ord.prescriptionNotes != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.medication, size: 20, color: Color(0xFF059669)),
                            SizedBox(width: 8),
                            Text(
                              "💊 روشتة علاج ومستلزمات صيدلية مرفقة",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            ),
                          ],
                        ),
                        if (ord.prescriptionNotes != null && ord.prescriptionNotes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            "ملاحظات الأدوية: ${ord.prescriptionNotes}",
                            style: const TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (ord.prescriptionImageUrl != null)
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF065F46),
                                    side: const BorderSide(color: Color(0xFF059669)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  icon: const Icon(Icons.image, size: 16),
                                  label: const Text("عرض صورة الروشتة", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _openUrl(ord.prescriptionImageUrl!),
                                ),
                              ),
                            if (ord.prescriptionImageUrl != null && ord.prescriptionAudioUrl != null)
                              const SizedBox(width: 8),
                            if (ord.prescriptionAudioUrl != null)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  icon: const Icon(Icons.mic, size: 16),
                                  label: const Text("استماع للريكورد", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _openUrl(ord.prescriptionAudioUrl!),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // 3c. Variable / Market Price Entry Card
                if (ord.hasUnpricedItems || ord.items.any((it) => it.isMarketPrice || it.unitPrice == 0.0)) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "⚠️ أوردر به أصناف متغيرة السعر أو بالوزن / روشتة",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "يجب تسجيل السعر الفعلي من المحل لتحديث الفاتورة للعميل:",
                          style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD97706),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: const Icon(Icons.edit_note, size: 18),
                                label: const Text("تسجيل وتعديل الأسعار من المحل", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _showUpdatePricingDialog(ord),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.phone_in_talk, color: Color(0xFFD97706)),
                              tooltip: "الاتصال بالعميل لإبلاغه بالتكلفة",
                              onPressed: () => _dialPhone(ord.customerPhone),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // 4. Financial Clarity Box (High Visibility)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("صافي عمولتك:", style: TextStyle(fontSize: 11, color: Color(0xFF9A3412))),
                          Text(
                            "+${ord.riderEarning.toStringAsFixed(0)} ج.م",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("المطلوب تحصيله كاش:", style: TextStyle(fontSize: 11, color: Color(0xFF9A3412))),
                          Text(
                            "${ord.totalCashToCollect.toStringAsFixed(0)} ج.م",
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFEA580C)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 5. Main Action Button (Ergonomic, Big Touch Target)
                if (!isOut)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isActionLoading ? null : () => _handlePickup(ord.id),
                    child: const Text(
                      "🛍️ تم استلام الأوردر من المحل والبدء للعميل",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isActionLoading ? null : () => _handleComplete(ord),
                    child: Text(
                      "✅ تم التسليم للعميل وتحصيل ${ord.totalCashToCollect.toStringAsFixed(0)} ج.م",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),

                const SizedBox(height: 6),

                // Exception reporting button
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.report_problem_outlined, size: 14, color: Color(0xFFDC2626)),
                    label: const Text(
                      "إبلاغ عن تعثر أو مشكلة ميدانية",
                      style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showException(ord.id),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
