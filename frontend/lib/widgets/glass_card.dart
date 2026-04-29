import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A genuine glassmorphism-style card using BackdropFilter and glowing shadows.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final bool isGlowing;
  final Color? glowColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
    this.borderColor,
    this.gradient,
    this.onTap,
    this.isGlowing = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(24);
    
    final innerContent = Container(
      decoration: BoxDecoration(
        gradient: gradient ?? HCColors.cardGradient,
        borderRadius: br,
        border: Border.all(
          color: borderColor ?? HCColors.glassBorder,
          width: 1.5,
        ),
      ),
      padding: padding,
      child: child,
    );

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: isGlowing
            ? [
                BoxShadow(
                  color: (glowColor ?? HCColors.primary).withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: innerContent,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: br,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          splashColor: HCColors.primary.withValues(alpha: 0.15),
          highlightColor: HCColors.primary.withValues(alpha: 0.05),
          child: card,
        ),
      );
    }
    return card;
  }
}
