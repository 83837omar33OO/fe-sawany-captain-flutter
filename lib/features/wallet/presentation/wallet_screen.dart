import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/wallet_repository.dart';
import '../models/ledger_entry.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _walletRepo = WalletRepository();
  bool _isLoading = true;
  LedgerSummary? _summary;
  String _riderId = "";

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    final profile = await SecureStorageService.getRiderProfile();
    _riderId = profile["id"] ?? "";

    try {
      final summary = await _walletRepo.getLedgerSummary(_riderId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSettlementDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountController = TextEditingController(
      text: _summary?.remainingDue.toStringAsFixed(0) ?? "0",
    );
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "طلب تسوية وتوريد عهدة كاش",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.slateDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "أدخل المبلغ النقدي الذي ستقوم بتوريده للمكتب أو المشرف الميداني:",
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : AppColors.slateLight),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.slateDark),
                decoration: InputDecoration(
                  labelText: "المبلغ المورد (ج.م)",
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.slateDark),
                decoration: InputDecoration(
                  labelText: "ملاحظات التسوية (اختياري)",
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
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
                final amt = double.tryParse(amountController.text) ?? 0.0;
                try {
                  await _walletRepo.submitSettlement(_riderId, amt, noteController.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("تم تقديم طلب التسوية بنجاح وبانتظار تأكيد المشرف."),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                  _loadLedger();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              child: const Text("تأكيد التوريد", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text("محفظة الكابتن والحسابات"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadLedger();
              },
              tooltip: "تحديث الحسابات",
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryMint))
            : RefreshIndicator(
                onRefresh: _loadLedger,
                color: AppColors.primaryMint,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. Rider Earnings Wallet Card (Available for withdrawal)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF064E3B), Color(0xFF047857)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF064E3B).withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.account_balance_wallet, color: Color(0xFFA7F3D0), size: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "رصيد أرباحك في المحفظة",
                                    style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "متاح للسحب 💰",
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "${_summary?.walletBalance.toStringAsFixed(0) ?? '0'} ج.م",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "يُضاف أجر التوصيل لمحفظتك فورياً بمجرد تأكيد تسليم كل طلب بنجاح",
                            style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Cash In Hand (Custody due to office)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.payments_outlined, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "العهدة النقدية باليد (كاش العملاء)",
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppColors.slateDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "واجبة التوريد",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "${_summary?.cashInHand.toStringAsFixed(0) ?? '0'} ج.م",
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.slateDark,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryMint,
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.handshake_outlined, size: 18),
                            label: const Text("طلب تصفية وتوريد العهدة للمكتب", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: _showSettlementDialog,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Stats Grid (Today stats)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricBox(
                            title: "أرباح وردية اليوم",
                            value: "${_summary?.todayEarnings.toStringAsFixed(0) ?? '0'} ج.م",
                            color: const Color(0xFF10B981),
                            bgColor: isDark ? const Color(0xFF064E3B).withOpacity(0.35) : const Color(0xFFECFDF5),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricBox(
                            title: "طلبات سلمتها اليوم",
                            value: "${_summary?.todayDeliveredCount ?? 0} طلب",
                            color: const Color(0xFF0284C7),
                            bgColor: isDark ? const Color(0xFF0C4A6E).withOpacity(0.35) : const Color(0xFFE0F2FE),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricBox(
                            title: "إجمالي الرحلات",
                            value: "${_summary?.totalDeliveredCount ?? 0} رحلة",
                            color: const Color(0xFF8B5CF6),
                            bgColor: isDark ? const Color(0xFF4C1D95).withOpacity(0.35) : const Color(0xFFEDE9FE),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 4. Recent Delivered Orders
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "سجل الطلبات المسلمة اليوم (${_summary?.recentCompleted.length ?? 0}):",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slateDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_summary?.recentCompleted.isEmpty ?? true)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Center(
                          child: Text(
                            "لا توجد طلبات مسلمة حتى الآن في هذه الوردية.",
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      )
                    else
                      ...(_summary!.recentCompleted.map((ord) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "طلب #${ord.orderReference}",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppColors.slateDark),
                                      ),
                                      Text(
                                        ord.storeName,
                                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "+${ord.deliveryFee.toStringAsFixed(0)} ج.م ربحك",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981)),
                                  ),
                                  Text(
                                    "محصل: ${ord.totalCollected.toStringAsFixed(0)} ج.م",
                                    style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      })),

                    const SizedBox(height: 18),

                    // 5. Accounting Rules Guide Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 20, color: AppColors.primaryMint),
                              const SizedBox(width: 8),
                              Text(
                                "قواعد الحسابات والعهدة النقدية:",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.slateDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildRuleLine("1. الكاش المحصل من العميل يمثل عهدة لصالح المحل والإدارة.", isDark),
                          _buildRuleLine("2. أجر مشوار التوصيل يُضاف لمحفظتك فور الضغط على تم التسليم.", isDark),
                          _buildRuleLine("3. تسوية العهدة تتطلب تأكيد الكابتن والمشرف لضمان حقوق الطرفين.", isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMetricBox({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRuleLine(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? const Color(0xFF94A3B8) : AppColors.slateMedium,
        ),
      ),
    );
  }
}
