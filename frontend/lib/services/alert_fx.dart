import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Multi-modal alert feedback for hearing-impaired users.
///
/// The phone's audio cue is useless to the target user, so we lean hard on
/// haptics and visual flashes. Priority maps to vibration intensity + length:
///
///   critical (fire / smoke / siren)  — long, repeated, max amplitude
///   high     (name / doorbell / cry) — medium pulse train
///   medium   (other)                 — single short buzz
class AlertFx {
  AlertFx._();
  static final AlertFx instance = AlertFx._();

  bool? _hasAmplitudeControl;
  bool? _hasCustomVibrator;

  Future<void> _ensureProbed() async {
    _hasCustomVibrator ??= (await Vibration.hasVibrator());
    _hasAmplitudeControl ??= (await Vibration.hasAmplitudeControl());
  }

  Future<void> trigger(AlertPriority priority) async {
    try {
      await _ensureProbed();
    } catch (e) {
      debugPrint('Vibration probe failed: $e');
    }

    HapticFeedback.heavyImpact();

    if (_hasCustomVibrator != true) {
      // Fall back to OS haptics.
      _scaffoldHaptics(priority);
      return;
    }

    final spec = _patternFor(priority);
    try {
      if (_hasAmplitudeControl == true) {
        await Vibration.vibrate(
          pattern: spec.pattern,
          intensities: spec.intensities,
        );
      } else {
        await Vibration.vibrate(pattern: spec.pattern);
      }
    } catch (e) {
      debugPrint('Vibration failed: $e');
      _scaffoldHaptics(priority);
    }
  }

  Future<void> _scaffoldHaptics(AlertPriority priority) async {
    final shots = switch (priority) {
      AlertPriority.critical => 5,
      AlertPriority.high => 3,
      AlertPriority.medium => 1,
    };
    for (var i = 0; i < shots; i++) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  _PatternSpec _patternFor(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.critical:
        // 0ms wait, 600ms buzz, 200ms pause, 600ms buzz, 200ms pause, 800ms buzz.
        return const _PatternSpec(
          pattern: [0, 600, 200, 600, 200, 800],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      case AlertPriority.high:
        return const _PatternSpec(
          pattern: [0, 350, 180, 350],
          intensities: [0, 220, 0, 220],
        );
      case AlertPriority.medium:
        return const _PatternSpec(
          pattern: [0, 220],
          intensities: [0, 180],
        );
    }
  }
}

class _PatternSpec {
  final List<int> pattern;
  final List<int> intensities;
  const _PatternSpec({required this.pattern, required this.intensities});
}

enum AlertPriority { critical, high, medium }

AlertPriority priorityForSoundType(String soundType) {
  switch (soundType) {
    case 'fire_alarm':
    case 'smoke_detector':
    case 'siren':
      return AlertPriority.critical;
    case 'name_called':
    case 'phone_ring':
    case 'doorbell':
    case 'knock':
    case 'baby_crying':
      return AlertPriority.high;
    default:
      return AlertPriority.medium;
  }
}
