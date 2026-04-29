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
      final env = provider.environment;
      final programs = provider.programs;
      final active = provider.activeProgram;

      String envLabel = 'Moderate';
      Color envColor = HCColors.warning;
      if (env.noiseLevel < 40) {
        envLabel = 'Quiet';
        envColor = HCColors.success;
      } else if (env.noiseLevel > 70) {
        envLabel = 'Loud';
        envColor = HCColors.danger;
      }

      return ListView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), children: [
        // Header
        const ScreenHeader(icon: '⚙️', title: 'Settings', subtitle: 'Environment & hearing programs'),
        const SizedBox(height: 20),
        // Noise Gauge
        Center(child: SizedBox(
          width: 160, height: 160,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(160, 160), painter: _GaugePainter(level: env.noiseLevel)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${env.noiseLevel}dB', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              Text(envLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: envColor)),
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
  final int level;
  _GaugePainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background arc
    final bgPaint = Paint()..color = HCColors.bgCard..strokeWidth = 10..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi * 0.75, math.pi * 1.5, false, bgPaint);

    // Progress arc
    final progress = (level / 100).clamp(0.0, 1.0);
    Color arcColor = HCColors.success;
    if (level > 70) {
      arcColor = HCColors.danger;
    } else if (level > 40) {
      arcColor = HCColors.warning;
    }

    final fgPaint = Paint()..color = arcColor..strokeWidth = 10..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi * 0.75, math.pi * 1.5 * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.level != level;
}
