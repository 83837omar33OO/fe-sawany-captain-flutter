import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/duty_controller.dart';

class DutySwitchWidget extends StatelessWidget {
  final bool isOnline;
  final bool isToggling;
  final ValueChanged<bool> onToggle;

  const DutySwitchWidget({
    super.key,
    required this.isOnline,
    required this.isToggling,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final duty = DutyController();

    return ListenableBuilder(
      listenable: duty,
      builder: (context, _) {
        return Column(
          children: [
            GestureDetector(
              onTap: isToggling ? null : () => onToggle(!isOnline),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? AppColors.primaryMint : const Color(0xFF64748B),
                  boxShadow: [
                    BoxShadow(
                      color: isOnline
                          ? AppColors.primaryMint.withOpacity(0.4)
                          : Colors.black.withOpacity(0.15),
                      blurRadius: isOnline ? 20 : 8,
                      spreadRadius: isOnline ? 6 : 2,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                ),
                child: Center(
                  child: isToggling
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isOnline ? Icons.power_settings_new : Icons.bedtime,
                              color: Colors.white,
                              size: 34,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOnline ? "متاح 🟢" : "أوفلاين ⚪",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isOnline) ...[
                              const SizedBox(height: 1),
                              Text(
                                duty.formattedShiftDuration,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                isOnline
                    ? "🟢 الوردية جارية: ${duty.formattedShiftDuration} • 🔋 ${duty.formattedBattery}"
                    : "⚪ الوردية مغلقة (أنت غير متاح)",
                key: ValueKey("${isOnline}_${duty.formattedShiftDuration}"),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isOnline ? AppColors.primaryMint : AppColors.slateLight,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
