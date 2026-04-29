import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Circular accuracy ring used in the SPECTRA (IML) screen.
/// Matches the React AccuracyRing component.
class AccuracyRing extends StatelessWidget {
  final double accuracy;
  final double size;
  final double strokeWidth;

  const AccuracyRing({
    super.key,
    required this.accuracy,
    this.size = 90,
    this.strokeWidth = 7,
  });

  @override
  Widget build(BuildContext context) {
    final pct = accuracy.round().clamp(0, 100);
    Color ringColor = HCColors.success;
    if (pct < 70) {
      ringColor = HCColors.danger;
    } else if (pct < 85) {
      ringColor = HCColors.warning;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background track
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: 1.0,
              color: Colors.white.withValues(alpha: 0.06),
              strokeWidth: strokeWidth,
            ),
          ),
          // Animated progress
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct / 100),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: value,
                  color: ringColor,
                  strokeWidth: strokeWidth,
                ),
              );
            },
          ),
          // Center label
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                'ACCURACY',
                style: TextStyle(
                  fontSize: size * 0.11,
                  fontWeight: FontWeight.w600,
                  color: HCColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
