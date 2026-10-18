import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/radar/presentation/radar_screen.dart';
import 'features/wallet/presentation/wallet_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FeSawanyCaptainApp());
}

class FeSawanyCaptainApp extends StatefulWidget {
  const FeSawanyCaptainApp({super.key});

  @override
  State<FeSawanyCaptainApp> createState() => _FeSawanyCaptainAppState();
}

class _FeSawanyCaptainAppState extends State<FeSawanyCaptainApp> {
  final _authRepo = AuthRepository();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authed = await _authRepo.isAuthenticated();
    setState(() {
      _isAuthenticated = authed;
      _isLoading = false;
    });
  }

  void _onLoginSuccess() {
    setState(() => _isAuthenticated = true);
  }

  void _onLogout() async {
    await _authRepo.logout();
    setState(() => _isAuthenticated = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _isLoading
          ? const Scaffold(
              backgroundColor: Color(0xFF064E3B),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)),
              ),
            )
          : _isAuthenticated
              ? Navigator(
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute(
                      builder: (ctx) => RadarScreen(
                        onOpenWallet: () {
                          Navigator.push(
                            ctx,
                            MaterialPageRoute(builder: (_) => const WalletScreen()),
                          );
                        },
                        onLogout: _onLogout,
                      ),
                    );
                  },
                )
              : LoginScreen(onLoginSuccess: _onLoginSuccess),
    );
  }
}
