import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _onTabSelected(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    if (index == 1) _refreshActiveCount();
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
                _onTabSelected(1);
              },
            ),
            const ActiveDeliveriesTab(),
            const WalletScreen(),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B132B) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map_rounded,
                  label: "الرادار والخريطة",
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.delivery_dining_outlined,
                  activeIcon: Icons.delivery_dining_rounded,
                  label: "الطلبات الجارية",
                  isDark: isDark,
                  badgeCount: _activeCount,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet_rounded,
                  label: "المحفظة",
                  isDark: isDark,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: "الإعدادات",
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = isDark ? AppColors.primaryMint : AppColors.primary;
    final inactiveColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF162A3B) : const Color(0xFFECFDF5))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 22,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    left: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF0B132B) : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        "$badgeCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
