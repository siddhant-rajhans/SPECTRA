import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/sound_classifier.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/waveform_visualizer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final device = provider.deviceStatus;

        // Provide safe defaults if device is null or incomplete
        final deviceName = device?.name ?? 'Hearing Device';
        final deviceConnected = device?.connected ?? true;
        final deviceBattery = device?.battery ?? 85;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Premium Header
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback:
                        (bounds) =>
                            HCColors.primaryGradient.createShader(bounds),
                    child: const Text('🦻', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SPECTRA',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: HCColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Connected Devices
            const _SectionTitle(
              title: 'Connected Devices',
              actionText: 'Manage',
            ),
            const SizedBox(height: 12),
            GlassCard(
              isGlowing: true,
              glowColor: HCColors.primary,
              child: Row(
                children: [
                  Expanded(
                    child: _DeviceItem(
                      icon: '🦻',
                      name: deviceName,
                      status: deviceConnected ? 'Connected' : 'Disconnected',
                      battery: deviceBattery,
                      gradient: HCColors.primaryGradient,
                    ),
                  ),
                  Container(width: 1, height: 60, color: HCColors.glassBorder),
                  Expanded(
                    child: _DeviceItem(
                      icon: '🦻',
                      name: 'Left Aid',
                      status: '75%',
                      battery: 75,
                      gradient: HCColors.accentGradient,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sound Awareness — start/stop ambient classifier.
            const _SectionTitle(title: 'Sound Awareness'),
            const SizedBox(height: 12),
            _SoundAwarenessCard(provider: provider),
            const SizedBox(height: 24),

            // Active Noise Cancellation
            const _SectionTitle(title: 'Active Noise Cancellation'),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: HCColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: HCColors.primary.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: 4,
                                top: 4,
                                bottom: 4,
                                child: Container(
                                  width: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: HCColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: HCColors.primaryLight.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'ON',
                          style: TextStyle(
                            color: HCColors.primaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ModeIcon(
                        icon: '🎯',
                        label: 'Focus',
                        isActive: provider.ancMode == 'focus',
                        onTap: () => provider.setAncMode('focus'),
                      ),
                      _ModeIcon(
                        icon: '🗣️',
                        label: 'Conversation',
                        isActive: provider.ancMode == 'conversation',
                        onTap: () => provider.setAncMode('conversation'),
                      ),
                      _ModeIcon(
                        icon: '🏃‍♂️',
                        label: 'Outdoor',
                        isActive: provider.ancMode == 'outdoor',
                        onTap: () => provider.setAncMode('outdoor'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Real-time Transcription preview — pulls from the active session.
            const _SectionTitle(title: 'Real-time Transcription'),
            const SizedBox(height: 12),
            _LiveTranscriptionCard(provider: provider),
            const SizedBox(height: 24),

            // Quick Scene & Volume
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Quick Scene',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: HCColors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            _SceneChip('Focus', true),
                            _SceneChip('Speech', false),
                            _SceneChip('Music', false),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Volume',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '75%',
                              style: TextStyle(
                                fontSize: 12,
                                color: HCColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [HCColors.danger, HCColors.warning],
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: 10,
                                top: 2,
                                bottom: 2,
                                child: Container(
                                  width: 20,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 120), // padding for floating bottom bar
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionText;

  const _SectionTitle({required this.title, this.actionText});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: HCColors.textPrimary,
          ),
        ),
        if (actionText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: HCColors.glassBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              actionText!,
              style: const TextStyle(
                fontSize: 11,
                color: HCColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _DeviceItem extends StatelessWidget {
  final String icon;
  final String name;
  final String status;
  final int battery;
  final Gradient gradient;

  const _DeviceItem({
    required this.icon,
    required this.name,
    required this.status,
    required this.battery,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(12),
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: const TextStyle(
                    color: HCColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 8,
                      decoration: BoxDecoration(
                        color: HCColors.success,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: HCColors.success.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$battery%',
                      style: const TextStyle(
                        color: HCColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeIcon extends StatelessWidget {
  final String icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _ModeIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        splashColor: HCColors.primary.withValues(alpha: 0.2),
        highlightColor: HCColors.primary.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? HCColors.primary.withValues(alpha: 0.25)
                          : HCColors.glassBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? HCColors.primary : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow:
                      isActive
                          ? [
                            BoxShadow(
                              color: HCColors.primary.withValues(alpha: 0.4),
                              blurRadius: 14,
                              spreadRadius: -2,
                            ),
                          ]
                          : null,
                ),
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color:
                      isActive ? HCColors.primaryLight : HCColors.textSecondary,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveTranscriptionCard extends StatelessWidget {
  final AppProvider provider;
  const _LiveTranscriptionCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final lines = provider.transcriptLines;
    final partial = provider.partialTranscript;
    final isTranscribing = provider.isTranscribing;
    final hasContent = lines.isNotEmpty || partial.isNotEmpty;

    final lastLines =
        lines.length > 3 ? lines.sublist(lines.length - 3) : lines;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: isTranscribing ? 0.18 : 0.05,
              child: WaveformVisualizer(isActive: isTranscribing),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isTranscribing
                                ? HCColors.accent
                                : HCColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isTranscribing ? 'Live captions' : 'Idle',
                      style: const TextStyle(
                        color: HCColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!hasContent && !isTranscribing)
                  GestureDetector(
                    onTap: () => provider.setActiveTab(2),
                    child: const Text(
                      'Tap the Transcribe tab to caption a conversation in real time.',
                      style: TextStyle(
                        fontSize: 13,
                        color: HCColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  )
                else if (!hasContent && isTranscribing)
                  const Text(
                    'Listening — start speaking…',
                    style: TextStyle(
                      fontSize: 14,
                      color: HCColors.textSecondary,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else ...[
                  for (final line in lastLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line.text,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: HCColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (partial.isNotEmpty)
                    Text(
                      partial,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: HCColors.accent.withValues(alpha: 0.85),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundAwarenessCard extends StatelessWidget {
  final AppProvider provider;
  const _SoundAwarenessCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final listening = provider.isListening;
    final error = provider.listenerError;

    return GlassCard(
      isGlowing: listening,
      glowColor: listening ? HCColors.accent : HCColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient:
                      listening
                          ? HCColors.accentGradient
                          : HCColors.primaryGradient,
                ),
                alignment: Alignment.center,
                child: Text(
                  listening ? '👂' : '🔈',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listening
                          ? 'Listening for sounds'
                          : 'Tap Listen to start',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listening
                          ? 'Detecting alarms, doorbells, sirens, baby cries, and more'
                          : 'Phone uses your mic + on-device AI to flag important sounds',
                      style: const TextStyle(
                        fontSize: 11,
                        color: HCColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                if (listening) {
                  provider.stopListening();
                } else {
                  provider.startListening();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: listening ? HCColors.danger : HCColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: Icon(
                listening ? Icons.stop_rounded : Icons.hearing_rounded,
                size: 18,
              ),
              label: Text(
                listening ? 'Stop listening' : 'Listen',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HCColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: HCColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: HCColors.danger,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(
                        fontSize: 11,
                        color: HCColors.danger,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (listening) _ListenerDiagnostic(provider: provider),
        ],
      ),
    );
  }
}

/// Live diagnostic panel: shows ambient amplitude, the top YAMNet predictions
/// for the most recent inference window, and which classes map to one of our
/// 12 internal alert types. Lets the user (and the dev) see immediately
/// whether the classifier is hearing anything at all.
class _ListenerDiagnostic extends StatelessWidget {
  final AppProvider provider;
  const _ListenerDiagnostic({required this.provider});

  @override
  Widget build(BuildContext context) {
    final snap = provider.lastSnapshot;
    final amp = provider.ambientAmplitude;
    final ampPct = (amp * 12).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'WHAT IT HEARS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: HCColors.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: HCColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'mic live',
                style: TextStyle(
                  fontSize: 10,
                  color: HCColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Amplitude bar
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: HCColors.bgCard,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ampPct,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: HCColors.accentGradient,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (snap == null)
            const Text(
              'Waiting for first inference...',
              style: TextStyle(fontSize: 11, color: HCColors.textSecondary),
            )
          else
            ...snap.topPredictions.take(4).map((r) => _PredictionRow(rank: r)),
        ],
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  final RankedClass rank;
  const _PredictionRow({required this.rank});

  @override
  Widget build(BuildContext context) {
    final isMapped = rank.mappedType != null;
    final pct = (rank.confidence * 100).clamp(0.0, 100.0);
    final barColor = isMapped ? HCColors.accent : HCColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              rank.yamnetClassName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isMapped ? HCColors.textPrimary : HCColors.textSecondary,
                fontWeight: isMapped ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: HCColors.bgCard,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: rank.confidence.clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${pct.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isMapped ? HCColors.accent : HCColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneChip extends StatelessWidget {
  final String label;
  final bool isActive;

  const _SceneChip(this.label, this.isActive);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? HCColors.glassHighlight : HCColors.glassBg,
        borderRadius: BorderRadius.circular(12),
        border:
            isActive
                ? Border.all(color: HCColors.textPrimary.withValues(alpha: 0.5))
                : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isActive ? HCColors.textPrimary : HCColors.textSecondary,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
