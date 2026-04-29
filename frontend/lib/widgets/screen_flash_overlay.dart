import 'package:flutter/material.dart';

import '../models/sound_alert.dart';
import '../services/alert_fx.dart';

/// Briefly washes the screen with the alert's color so the user can't miss
/// the notification even if they aren't looking at the foreground content.
/// The flash repeats for higher-priority alerts.
class ScreenFlashOverlay extends StatefulWidget {
  /// Increments each time the provider fires a new alert; we use it as a
  /// trigger key.
  final int alertCounter;
  final String? alertSoundType;
  final Color? alertColor;

  const ScreenFlashOverlay({
    super.key,
    required this.alertCounter,
    required this.alertSoundType,
    required this.alertColor,
  });

  @override
  State<ScreenFlashOverlay> createState() => _ScreenFlashOverlayState();
}

class _ScreenFlashOverlayState extends State<ScreenFlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void didUpdateWidget(covariant ScreenFlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alertCounter != oldWidget.alertCounter && widget.alertCounter > 0) {
      _flashBurst();
    }
  }

  Future<void> _flashBurst() async {
    final priority = priorityForSoundType(widget.alertSoundType ?? '');
    final reps = switch (priority) {
      AlertPriority.critical => 4,
      AlertPriority.high => 2,
      AlertPriority.medium => 1,
    };
    for (var i = 0; i < reps; i++) {
      if (!mounted) return;
      _controller.forward(from: 0).then((_) => _controller.reverse());
      await Future.delayed(const Duration(milliseconds: 480));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.value == 0) return const SizedBox.shrink();
          final color = widget.alertColor ?? const Color(0xFFFF6B6B);
          return Positioned.fill(
            child: ColoredBox(
              color: color.withValues(alpha: 0.55 * _controller.value),
            ),
          );
        },
      ),
    );
  }
}

/// Resolves the flash color from the sound type's metadata so the colour
/// matches the alert chip in [SoundTypeInfo].
Color resolveFlashColor(String? soundType) {
  if (soundType == null) return const Color(0xFFFF6B6B);
  return SoundTypeInfo.fromType(soundType).color;
}
