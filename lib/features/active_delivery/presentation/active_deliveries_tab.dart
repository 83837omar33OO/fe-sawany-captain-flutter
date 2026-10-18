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
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openMaps(String query) async {
    final encoded = Uri.encodeComponent("$query, مركز دمنهور, البحيرة");
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encoded");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handlePickup(String orderId) async {
    setState(() => _isActionLoading = true);
    try {
      await _activeRepo.pickupOrder(orderId);
      await _loadOrders();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("تأكيد التسليم والتحصيل"),
          content: Text("هل تم تسليم الطلب وتحصيل ${order.totalCashToCollect} ج.م نقداً بنجاح؟"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تم إتمام الطلب وإيداع عمولة التوصيل بمحفظتك."),
              backgroundColor: AppColors.primary,
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
        orderId: orderId,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("الطلبات الجارية والتوصيل"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text(
                        "لا توجد طلبات جارية حالياً",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.slateDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "توجه لتبويب الخريطة والرادار لاستلام طلب جديد.",
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
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) => _buildOrderCard(_orders[idx], isDark),
                  ),
                ),
    );
  }

  Widget _buildOrderCard(ActiveOrder ord, bool isDark) {
    final isOut = ord.status == "out_for_delivery";
    final textColor = isDark ? Colors.white : AppColors.slateDark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOut ? const Color(0xFFE0F2FE) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOut ? "🚀 في الطريق للعميل" : "⏳ توجه للمحل للاستلام",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOut ? const Color(0xFF0284C7) : AppColors.primary,
                  ),
                ),
              ),
              Text(
                "طلب #${ord.orderReference}",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const Divider(height: 16),

          // Pickup
          Row(
            children: [
              const Icon(Icons.storefront, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "المحل: ${ord.storeName} (${ord.storeAddress})",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              if (ord.storePhone != null && (ord.storePhone?.isNotEmpty ?? false))
                IconButton(
                  icon: const Icon(Icons.phone, size: 16, color: AppColors.primaryMint),
                  onPressed: () => _dialPhone(ord.storePhone ?? ""),
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                icon: const Icon(Icons.map, size: 16, color: Color(0xFF0284C7)),
                onPressed: () => _openMaps(ord.storeAddress),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Customer
          Row(
            children: [
              const Icon(Icons.person_pin_circle_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "العميل: ${ord.customerName} (${ord.customerAddress})",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone_in_talk, size: 16, color: AppColors.primaryMint),
                onPressed: () => _dialPhone(ord.customerPhone),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.navigation, size: 16, color: Color(0xFF0284C7)),
                onPressed: () => _openMaps(ord.customerAddress),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (ord.customerNotes != null && (ord.customerNotes?.isNotEmpty ?? false))
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "ملاحظات: ${ord.customerNotes}",
                style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B)),
              ),
            ),
          const Divider(height: 16),

          // Cash summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "أرباحك: +${ord.riderEarning.toStringAsFixed(0)} ج.م",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryMint),
              ),
              Text(
                "الكاش للتحصيل: ${ord.totalCashToCollect.toStringAsFixed(0)} ج.م",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFB923C)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (!isOut)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                minimumSize: const Size.fromHeight(38),
              ),
              onPressed: _isActionLoading ? null : () => _handlePickup(ord.id),
              child: const Text("🛍️ تم استلام الأوردر من المحل وبدء المشوار", style: TextStyle(fontSize: 12)),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(38),
              ),
              onPressed: _isActionLoading ? null : () => _handleComplete(ord),
              child: Text(
                "✅ تم التسليم للعميل وتحصيل ${ord.totalCashToCollect.toStringAsFixed(0)} ج.م",
                style: const TextStyle(fontSize: 12),
              ),
            ),

          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              icon: const Icon(Icons.flag_outlined, size: 14, color: Color(0xFFDC2626)),
              label: const Text(
                "إبلاغ عن تعثر أو مشكلة في الطلب",
                style: TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
              ),
              onPressed: () => _showException(ord.id),
            ),
          ),
        ],
      ),
    );
  }
}
