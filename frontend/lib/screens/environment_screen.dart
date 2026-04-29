import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_header.dart';

class EnvironmentScreen extends StatelessWidget {
  const EnvironmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      final programs = provider.programs;
      final active = provider.activeProgram;

      // Prefer live mic dB when the user has Listen on; otherwise fall back to
      // the backend's simulated noiseLevel (or "—" if neither is available).
      final liveDb = provider.ambientDbSpl;
      final fallbackDb = provider.environment.noiseLevel;
      final shownDb = liveDb ?? fallbackDb.toDouble();
      final isLive = liveDb != null;

      String envLabel = 'Moderate';
      Color envColor = HCColors.warning;
      if (shownDb < 40) {
        envLabel = 'Quiet';
        envColor = HCColors.success;
      } else if (shownDb > 70) {
        envLabel = 'Loud';
        envColor = HCColors.danger;
      }

      // Map dB SPL [20..110] to gauge progress [0..1]. 20dB = silent room,
      // 110dB = jet engine.
      final gaugeProgress = ((shownDb - 20) / 90).clamp(0.0, 1.0);

      return ListView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), children: [
        // Header
        const ScreenHeader(icon: '⚙️', title: 'Settings', subtitle: 'Environment & hearing programs'),
        const SizedBox(height: 20),
        // Noise Gauge
        Center(child: SizedBox(
          width: 160, height: 160,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(160, 160), painter: _GaugePainter(progress: gaugeProgress, isLive: isLive)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${shownDb.round()}dB', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              Text(envLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: envColor)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: isLive ? HCColors.success : HCColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isLive ? 'live' : 'tap Listen on Home',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: HCColors.textTertiary),
                  ),
                ],
              ),
            ]),
          ]),
        )),
        const SizedBox(height: 24),

        // Programs
        Text('HEARING PROGRAMS', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: HCColors.textSecondary)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.85),
          itemCount: programs.length,
          itemBuilder: (context, i) {
            final p = programs[i];
            return GlassCard(
              onTap: () => provider.selectProgram(p.id),
              borderColor: p.isActive ? HCColors.primary : HCColors.border,
              gradient: p.isActive ? LinearGradient(colors: [HCColors.primary.withValues(alpha: 0.15), HCColors.bgCard]) : null,
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.all(10),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(p.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 6),
                Text(p.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: HCColors.textSecondary), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            );
          },
        ),
        const SizedBox(height: 24),

        // Sliders
        Text('FINE TUNING', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: HCColors.textSecondary)),
        const SizedBox(height: 12),
        if (active != null) ...[
          _slider('Speech Enhancement', active.settings.speechEnhancement, (v) {
            active.settings.speechEnhancement = v;
            provider.updateProgramSettings(active.id, active.settings);
          }),
          _slider('Background Noise Reduction', active.settings.noiseReduction, (v) {
            active.settings.noiseReduction = v;
            provider.updateProgramSettings(active.id, active.settings);
          }),
          _slider('Forward Focus', active.settings.forwardFocus, (v) {
            active.settings.forwardFocus = v;
            provider.updateProgramSettings(active.id, active.settings);
          }),
        ],
        const SizedBox(height: 80),
      ]);
    });
  }

  Widget _slider(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text('$value%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HCColors.accent)),
        ]),
        const SizedBox(height: 8),
        SliderTheme(
          data: const SliderThemeData(trackHeight: 4),
          child: Slider(
            value: value.toDouble(), min: 0, max: 100,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ]),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final bool isLive;
  _GaugePainter({required this.progress, required this.isLive});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    final bgPaint = Paint()..color = HCColors.bgCard..strokeWidth = 10..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi * 0.75, math.pi * 1.5, false, bgPaint);

    // Color shifts with progress: green → amber → red.
    Color arcColor = HCColors.success;
    if (progress > 0.55) {
      arcColor = HCColors.danger;
    } else if (progress > 0.25) {
      arcColor = HCColors.warning;
    }
    if (!isLive) arcColor = arcColor.withValues(alpha: 0.5);

    final fgPaint = Paint()..color = arcColor..strokeWidth = 10..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi * 0.75, math.pi * 1.5 * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.isLive != isLive;
}
