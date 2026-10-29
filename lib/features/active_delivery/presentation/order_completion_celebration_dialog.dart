import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../models/active_order.dart';

class OrderCompletionCelebrationDialog extends StatefulWidget {
  final ActiveOrder order;
  final VoidCallback onDismiss;

  const OrderCompletionCelebrationDialog({
    super.key,
    required this.order,
    required this.onDismiss,
  });

  @override
  State<OrderCompletionCelebrationDialog> createState() =>
      _OrderCompletionCelebrationDialogState();
}

class _OrderCompletionCelebrationDialogState
    extends State<OrderCompletionCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _controller.forward();

    // Trigger high celebratory vibration
    try {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 150), () {
        HapticFeedback.heavyImpact();
      });
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Confetti Burst Background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _CelebrationParticlesPainter(_controller.value),
                  );
                },
              ),
            ),

            // Main Dialog Card
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 25,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing Trophy / Check Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        "عاش يا كابتن! 🚀",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.slateDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "تم تسليم الطلب #${widget.order.orderReference} بنجاح",
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Earning Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.stars_rounded, color: Color(0xFF10B981), size: 26),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "أرباح التوصيل المودعة:",
                                  style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "+${widget.order.riderEarning.toStringAsFixed(0)} ج.م لمحفظتك 💰",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Custody Info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "المبلغ المحصل كاش للعهدة:",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                            Text(
                              "${widget.order.totalCashToCollect.toStringAsFixed(0)} ج.م",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.slateDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Continue Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryMint,
                          foregroundColor: const Color(0xFF0F172A),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDismiss();
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "متابعة الطلبات التالية 🛵",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CelebrationParticlesPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles = [];

  _CelebrationParticlesPainter(this.progress) {
    final rand = Random(42);
    final colors = [
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF0284C7),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
      const Color(0xFFFBBF24),
    ];

    for (int i = 0; i < 40; i++) {
      final angle = rand.nextDouble() * 2 * pi;
      final distance = 60 + rand.nextDouble() * 140;
      final size = 4 + rand.nextDouble() * 6;
      final color = colors[rand.nextInt(colors.length)];
      particles.add(_Particle(angle, distance, size, color));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final curDistance = p.distance * progress;
      final curAlpha = (1.0 - progress).clamp(0.0, 1.0);
      final offset = Offset(
        center.dx + cos(p.angle) * curDistance,
        center.dy + sin(p.angle) * curDistance,
      );

      final paint = Paint()
        ..color = p.color.withOpacity(curAlpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(offset, p.size * (1 - progress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  _Particle(this.angle, this.distance, this.size, this.color);
}
