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
    final amountController = TextEditingController(
      text: _summary?.remainingDue.toStringAsFixed(0) ?? "0",
    );
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("طلب تسوية وتوريد عهدة"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "أدخل المبلغ النقدي الذي ستقوم بتوريده للمكتب أو المشرف الميداني:",
                style: TextStyle(fontSize: 12, color: AppColors.slateLight),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "المبلغ المورد (ج.م)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: "ملاحظات التسوية (اختياري)"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
                    color: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                              foregroundColor: AppColors.primaryDark,
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
                          color: AppColors.primary,
                          bgColor: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricBox(
                          title: "طلبات تم تسليمها",
                          value: "${_summary?.todayDeliveredCount ?? 0} طلب",
                          color: AppColors.info,
                          bgColor: AppColors.infoLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ledger Rules Guide Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text(
                                "قواعد الحسابات والعهدة النقدية:",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildRuleLine("1. الكاش المحصل من العميل يمثل عهدة لصالح المحل والإدارة."),
                          _buildRuleLine("2. أجر مشوار التوصيل يُضاف لمحفظتك فور الضغط على تم التسليم."),
                          _buildRuleLine("3. تسوية العهدة تتطلب تأكيد الكابتن والمشرف لضمان حقوق الطرفين."),
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

  Widget _buildRuleLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.slateMedium)),
    );
  }
}
