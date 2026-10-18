import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../permissions/presentation/permissions_screen.dart';
import '../../auth/presentation/login_screen.dart';
import '../../shell/main_shell.dart';
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
    final perm = await Geolocator.checkPermission();
    final hasLocationPermission =
        perm == LocationPermission.always || perm == LocationPermission.whileInUse;

    // Check session token
    final token = await SecureStorageService.getToken();
    final isAuthenticated = token != null && token.isNotEmpty;

    Widget nextScreen;
    if (!hasLocationPermission) {
      nextScreen = PermissionsScreen(
        onPermissionsGranted: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => isAuthenticated
                  ? const MainShell()
                  : LoginScreen(
                      onLoginSuccess: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MainShell()),
                        );
                      },
                    ),
            ),
          );
        },
      );
    } else if (isAuthenticated) {
      nextScreen = const MainShell();
    } else {
      nextScreen = LoginScreen(
        onLoginSuccess: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainShell()),
          );
        },
      );
    }

    Navigator.pushReplacement(
      context,
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
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/tayyar-logo.png',
                width: 170,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryMint, width: 2),
                  ),
                  child: const Center(
                    child: Text("🛵", style: TextStyle(fontSize: 44)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.primaryMint,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "الطيار في ثواني",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "نظام تشغيل الكباتن والأسطول الميداني",
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFA7F3D0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
