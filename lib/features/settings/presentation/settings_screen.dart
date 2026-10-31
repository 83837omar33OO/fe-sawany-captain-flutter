import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authRepo = AuthRepository();
  Map<String, String?> _profile = {};
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await SecureStorageService.getRiderProfile();
    if (mounted) setState(() => _profile = p);
  }

  void _callSupervisor() async {
    final uri = Uri.parse("tel:01034293703");
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showGuidelinesModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "دليل وقواعد كابتن في ثواني",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildGuidelineCard(
                      icon: Icons.two_wheeler_rounded,
                      title: "1. قواعد السلامة على الطريق",
                      color: AppColors.primary,
                      isDark: isDark,
                      points: [
                        "الالتزام بارتداء الخوذة والجاكيت العاكس ليلاً.",
                        "الحفاظ على سرعة آمنة وممنوع القيادة عكس الاتجاه نهائياً.",
                        "ممنوع استخدام الهاتف يدوياً أثناء حركة الموتوسيكل.",
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildGuidelineCard(
                      icon: Icons.inventory_2_outlined,
                      title: "2. فحص واستلام الطلب من المحل",
                      color: AppColors.info,
                      isDark: isDark,
                      points: [
                        "مطابقة الأصناف المكتوبة مع كيس المحل قبل التحرك.",
                        "التأكد من إحكام غلق علب الطعام أو السوائل داخل الحقيبة.",
                        "الضغط على «استلمت» فور استلام الشحنة.",
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildGuidelineCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: "3. العهدة النقدية والتحصيل",
                      color: AppColors.warning,
                      isDark: isDark,
                      points: [
                        "المبالغ المحصلة كاش أمانة كاملة لصالح المحل والتطبيق.",
                        "أرباح توصيلتك الصافية تضاف إلى محفظتك فورياً.",
                        "يتم توريد العهدة بانتظام للمشرف الميداني.",
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                      label: const Text(
                        "اتصال مباشر بالمشرف (01034293703)",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _callSupervisor();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidelineCard({
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
    required List<String> points,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkHover : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("• ", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("تسجيل الخروج", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("هل تريد إنهاء الوردية وتسجيل الخروج؟"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("تسجيل الخروج"),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _authRepo.logout();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("حسابي والإعدادات", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Profile Hero Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryMint, width: 2),
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile["name"] ?? "كابتن في ثواني",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _profile["phone"] ?? "010xxxxxxxx",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.primaryMint.withOpacity(0.18) : AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _profile["zone"] ?? "الناصرية القديمة",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.primaryMint : AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "🛵 دراجة نارية",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Preferences
            Text(
              "التفضيلات",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text("المظهر الليلي (Dark Mode)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("توفير البطارية وراحة العين ليلاً", style: TextStyle(fontSize: 11)),
                    secondary: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.primary),
                    value: isDark,
                    onChanged: (val) {
                      ThemeController.instance.setTheme(val ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("نغمات تنبيه الأوردرات", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("تنبيه صوتي قوي عند ورود طلبات جديدة", style: TextStyle(fontSize: 11)),
                    secondary: const Icon(Icons.volume_up_rounded, color: AppColors.primary),
                    value: _soundEnabled,
                    onChanged: (val) => setState(() => _soundEnabled = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. Operational Support
            Text(
              "الدعم والتشغيل",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                    title: const Text("مشرف العمليات الميدانية", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("01034293703 • مساعدة فورية", style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                    onTap: _callSupervisor,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.policy_outlined, color: AppColors.primary),
                    title: const Text("إرشادات وقواعد السلامة", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("دليل السلامة وتوريد العهدة", style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                    onTap: () => _showGuidelinesModal(isDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Logout Action
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text("تسجيل الخروج وإنهاء الوردية", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              onPressed: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }
}
