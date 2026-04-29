import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A glassmorphism-style card matching the web client's `.card` class.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.borderColor,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(16);
    final card = Container(
      decoration: BoxDecoration(
        gradient: gradient ?? HCColors.cardGradient,
        borderRadius: br,
        border: Border.all(color: borderColor ?? HCColors.border),
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: br,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          splashColor: HCColors.primary.withValues(alpha: 0.15),
          child: card,
        ),
      );
    }
    return card;
  }
}
