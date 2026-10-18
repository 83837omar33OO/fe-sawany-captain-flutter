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

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("تسجيل الخروج"),
          content: const Text("هل تريد إنهاء الوردية وتسجيل الخروج من التطبيق؟"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("الملف الشخصي والإعدادات"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Profile Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryMint, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile["name"] ?? "كابتن في ثواني",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _profile["phone"] ?? "010xxxxxxxx",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF064E3B) : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _profile["zone"] ?? "الناصرية القديمة",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.primaryMint : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "🛵 دراجة نارية",
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Preferences
          const Text(
            "تفضيلات التطبيق",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("مظهر التطبيق الليلي (Dark Mode)", style: TextStyle(fontSize: 13)),
                  subtitle: const Text("توفير شحن البطارية وراحة العين أثناء القيادة الليلية", style: TextStyle(fontSize: 11)),
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: AppColors.primaryMint),
                  value: isDark,
                  onChanged: (val) {
                    ThemeController.instance.setTheme(val ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("نغمات تنبيه واهتزاز الأوردرات", style: TextStyle(fontSize: 13)),
                  subtitle: const Text("رنين قوي واهتزاز متقطع لتنبيهك أثناء سير الموتوسيكل", style: TextStyle(fontSize: 11)),
                  secondary: const Icon(Icons.volume_up_outlined, color: AppColors.primaryMint),
                  value: _soundEnabled,
                  onChanged: (val) => setState(() => _soundEnabled = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Operational Support
          const Text(
            "الدعم والتشغيل الميداني",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent, color: AppColors.primaryMint),
                  title: const Text("الاتصال بمشرف العمليات الميدانية", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text("01034293703 - لحل أي مشكلة في الاستلام أو التسليم", style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: _callSupervisor,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.policy_outlined, color: Color(0xFF64748B)),
                  title: const Text("إرشادات وقواعد السلامة والعهدة", style: TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Logout Action
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text("تسجيل الخروج وإنهاء الوردية", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            onPressed: _handleLogout,
          ),
          const SizedBox(height: 24),

          Center(
            child: Image.asset(
              'assets/images/tayyar-logo.png',
              width: 110,
              errorBuilder: (_, __, ___) => const Text(
                "الطيار في ثواني v1.0.9",
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
