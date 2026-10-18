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
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              // Modal Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.policy_rounded, color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "دليل وقواعد كابتن في ثواني",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.slateDark,
                            ),
                          ),
                          const Text(
                            "إرشادات التشغيل والسلامة والعهدة الميدانية",
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Guidelines List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildGuidelineCard(
                      icon: Icons.two_wheeler_rounded,
                      title: "1. قواعد السلامة على الطريق والقيادة",
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                      points: [
                        "الالتزام الكامل بارتداء الخوذة والجاكيت الفسفوري العاكس ليلاً.",
                        "الحفاظ على سرعة آمنة وعدم المجازفة أو القيادة عكس الاتجاه نهائياً.",
                        "ممنوع استخدام الهاتف يدوياً أثناء حركة الموتوسيكل؛ اعتمد على التوجيه الصوتي.",
                        "فحص الفرامل وضغط الإطارات وأنوار الإشارات يومياً قبل بدء الوردية.",
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildGuidelineCard(
                      icon: Icons.inventory_2_outlined,
                      title: "2. فحص الطلب واستلامه من المحل",
                      color: const Color(0xFF0284C7),
                      isDark: isDark,
                      points: [
                        "مطابقة الأصناف المكتوبة في تفاصيل الطلب مع كيس المحل قبل التحرك.",
                        "التأكد من إحكام غلق علب الطعام أو السوائل ووضعها مستوية داخل الحقيبة.",
                        "الضغط على «تم الاستلام من المحل» فور استلام الشحنة لبدء احتساب وقت الرحلة.",
                        "في حال تأخر المحل عن التجهيز أكثر من 15 دقيقة، تواصل مع المشرف الميداني.",
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildGuidelineCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: "3. العهدة النقدية والتحصيل والمحفظة",
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                      points: [
                        "المبالغ المحصلة من العميل أمانة كاملة لصالح المحل وإدارة التطبيق.",
                        "أرباح توصيلتك الصافية تضاف إلى محفظتك فور الضغط على «تم التسليم».",
                        "يتم توريد وتصفية العهدة النقدية مع المشرف بانتظام وتأكيد الطرفين.",
                        "تجنب حمل مبالغ نقدية تتجاوز 1,500 ج.م دون تصفيتها لدى الإدارة.",
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildGuidelineCard(
                      icon: Icons.support_agent_rounded,
                      title: "4. التعامل مع المشكلات والعملاء",
                      color: const Color(0xFFEF4444),
                      isDark: isDark,
                      points: [
                        "الاتصال بالعميل قبل الوصول بدقيقة لتحضير المبلغ وضمان سرعة التسليم.",
                        "التعامل بكل احترام ولباقة؛ أنت تمثل الواجهة الرسمية للشركة في الشارع.",
                        "في حال عدم رد العميل: انتظر 5 دقائق وحاول الاتصال مرتين.",
                        "إذا تعذر التسليم، اضغط «إبلاغ عن مشكلة» فوراً لإشعار المشرف والتدخل.",
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Direct Supervisor Call Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00875A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                      label: const Text(
                        "اتصال مباشر بغرفة العمليات (01034293703)",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _callSupervisor();
                      },
                    ),
                    const SizedBox(height: 12),
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
        color: isDark ? const Color(0xFF162A3B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A52) : const Color(0xFFE2E8F0),
        ),
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.slateDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("• ", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: isDark ? const Color(0xFFCBD5E1) : AppColors.slateLight,
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
                  leading: const Icon(Icons.policy_outlined, color: AppColors.primaryMint),
                  title: const Text("إرشادات وقواعد السلامة والعهدة", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text("دليل قواعد السلامة والتسليم وتوريد العهدة النقدية", style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _showGuidelinesModal(isDark),
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
                "الطيار في ثواني",
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
