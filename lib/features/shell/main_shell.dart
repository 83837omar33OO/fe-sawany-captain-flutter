import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../radar/presentation/radar_map_screen.dart';
import '../active_delivery/presentation/active_deliveries_tab.dart';
import '../wallet/presentation/wallet_screen.dart';
import '../settings/presentation/settings_screen.dart';
import '../active_delivery/data/active_order_repository.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _activeCount = 0;
  final _activeRepo = ActiveOrderRepository();

  @override
  void initState() {
    super.initState();
    _refreshActiveCount();
  }

  Future<void> _refreshActiveCount() async {
    try {
      final list = await _activeRepo.getActiveOrders();
      if (mounted) setState(() => _activeCount = list.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            RadarMapScreen(
              onOpenActiveTab: () {
                setState(() => _currentIndex = 1);
                _refreshActiveCount();
              },
            ),
            const ActiveDeliveriesTab(),
            const WalletScreen(),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) {
            setState(() => _currentIndex = idx);
            if (idx == 1) _refreshActiveCount();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          selectedItemColor: isDark ? AppColors.primaryMint : AppColors.primary,
          unselectedItemColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: "الرئيسية والخريطة",
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _activeCount > 0,
                label: Text("$_activeCount"),
                backgroundColor: AppColors.primaryMint,
                textColor: const Color(0xFF064E3B),
                child: const Icon(Icons.delivery_dining_outlined),
              ),
              activeIcon: Badge(
                isLabelVisible: _activeCount > 0,
                label: Text("$_activeCount"),
                backgroundColor: AppColors.primaryMint,
                textColor: const Color(0xFF064E3B),
                child: const Icon(Icons.delivery_dining),
              ),
              label: "الطلبات الجارية",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: "المحفظة والعهد",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: "الإعدادات",
            ),
          ],
        ),
      ),
    );
  }
}
