import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Horizontal confidence bar matching the React ConfidenceBar component.
class ConfidenceBar extends StatelessWidget {
  final double confidence; // 0.0 - 1.0
  final Color? color;

  const ConfidenceBar({
    super.key,
    required this.confidence,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    final barColor = color ?? HCColors.accent;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: confidence.clamp(0.0, 1.0),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) {
                  return FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 34,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: barColor,
            ),
          ),
        ),
      ],
    );
  }
}
