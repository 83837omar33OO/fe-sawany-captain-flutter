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
            "طلب تسوية وتوريد عهدة",
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
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
              child: const Text("تأكيد الطلب"),
            ),
          ],
        ),
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
          title: const Text("محفظة الكابتن والحسابات"),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Main Cash Custody Card
                  Card(
                    color: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "العهدة النقدية باليد (واجبة التوريد)",
                            style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${_summary?.cashInHand.toStringAsFixed(0) ?? '0'} ج.م",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryMint,
                              foregroundColor: const Color(0xFF0F172A),
                            ),
                            icon: const Icon(Icons.handshake_outlined),
                            label: const Text("طلب تصفية وتوريد العهدة للمكتب"),
                            onPressed: _showSettlementDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricBox(
                          title: "أرباحك المستحقة اليوم",
                          value: "${_summary?.todayEarnings.toStringAsFixed(0) ?? '0'} ج.م",
                          color: isDark ? AppColors.primaryMint : AppColors.primary,
                          bgColor: isDark ? const Color(0xFF064E3B).withOpacity(0.4) : AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricBox(
                          title: "طلبات تم تسليمها",
                          value: "${_summary?.todayDeliveredCount ?? 0} طلب",
                          color: isDark ? const Color(0xFF38BDF8) : AppColors.info,
                          bgColor: isDark ? const Color(0xFF0C4A6E).withOpacity(0.4) : AppColors.infoLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ledger Rules Guide Card
                  Card(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                                  fontSize: 14,
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
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMetricBox({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
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
          fontSize: 12,
          color: isDark ? const Color(0xFF94A3B8) : AppColors.slateMedium,
        ),
      ),
    );
  }
}
