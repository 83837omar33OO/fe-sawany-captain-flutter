import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../permissions/presentation/permissions_screen.dart';
import '../../auth/presentation/login_screen.dart';
import '../../shell/main_shell.dart';
import '../../fleet_manager/presentation/fleet_manager_dashboard.dart';
import 'package:geolocator/geolocator.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    _checkNextScreen();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    // Check location permission
    LocationPermission perm;
    try {
      perm = await Geolocator.checkPermission();
    } catch (_) {
      perm = LocationPermission.denied;
    }

    final hasLocationPermission =
        perm == LocationPermission.always || perm == LocationPermission.whileInUse;

    // Check session token & saved role
    final token = await SecureStorageService.getToken();
    final isAuthenticated = token != null && token.isNotEmpty;
    final role = await SecureStorageService.getRiderRole();

    if (!mounted) return;

    Widget nextScreen;
    if (!hasLocationPermission) {
      nextScreen = const PermissionsScreen();
    } else if (isAuthenticated) {
      nextScreen = role == "fleet_manager"
          ? const FleetManagerDashboard()
          : const MainShell();
    } else {
      nextScreen = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/tayyar-logo.png',
                width: 160,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryMint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delivery_dining,
                    size: 60,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "في ثواني كابتن",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "منظومة التوصيل السريع وإدارة الأسطول",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primaryMint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
