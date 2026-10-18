import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/colors.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../shell/main_shell.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback? onPermissionsGranted;

  const PermissionsScreen({super.key, this.onPermissionsGranted});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _isRequesting = false;

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);
    try {
      // 1. Location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("يرجى تفعيل إذن الموقع من إعدادات الهاتف لتشغيل تطبيق الكابتن."),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
        _proceedNext();
      }
    }
  }

  Future<void> _proceedNext() async {
    if (widget.onPermissionsGranted != null) {
      widget.onPermissionsGranted!();
    }

    final token = await SecureStorageService.getToken();
    final isAuthenticated = token != null && token.isNotEmpty;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isAuthenticated ? const MainShell() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Image.asset(
                    'assets/images/tayyar-logo.png',
                    width: 140,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.security,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "تفعيل صلاحيات التشغيل الميداني",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slateDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "يحتاج تطبيق كابتن في ثواني إلى تفعيل الصلاحيات التالية لاستقبال وتوصيل الطلبات بدقة في الشارع:",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.slateLight, height: 1.5),
                ),
                const SizedBox(height: 24),

                // Card 1: GPS Location
                _buildPermissionItem(
                  icon: Icons.my_location_rounded,
                  title: "تحديد الموقع المباشر (GPS)",
                  desc: "لتوجيهك بدقة لأقرب المحلات وعناوين العملاء، واقتراح الأوردرات في نطاقك.",
                ),
                const SizedBox(height: 12),

                // Card 2: Notifications
                _buildPermissionItem(
                  icon: Icons.notifications_active_outlined,
                  title: "تنبيهات الأوردرات الجديدة",
                  desc: "لإصدار نغمة رنين واهتزاز فور وصول أي طلب جديد لتنبيهك أثناء القيادة.",
                ),
                const Spacer(),

                ElevatedButton(
                  onPressed: _isRequesting ? null : _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isRequesting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          "تفعيل الصلاحيات والمتابعة",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slateDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: AppColors.slateLight, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
