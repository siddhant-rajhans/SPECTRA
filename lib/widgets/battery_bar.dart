import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Battery level indicator bar with color coding.
class BatteryBar extends StatelessWidget {
  final int level;
  final bool showLabel;

  const BatteryBar({
    super.key,
    required this.level,
    this.showLabel = true,
  });

  Color _getColor() {
    if (level > 50) return HCColors.success;
    if (level > 25) return HCColors.warning;
    return HCColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: HCColors.bgDark,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (level / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_getColor(), HCColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '$level%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: HCColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
