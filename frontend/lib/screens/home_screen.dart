import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/sound_alert.dart';
import '../widgets/waveform_visualizer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final device = provider.deviceStatus;
        
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Premium Header
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => HCColors.primaryGradient.createShader(bounds),
                    child: const Text('🦻', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'HearClear',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: HCColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Connected Devices
            const _SectionTitle(title: 'Connected Devices', actionText: 'Manage'),
            const SizedBox(height: 12),
            GlassCard(
              isGlowing: true,
              glowColor: HCColors.primary,
              child: Row(
                children: [
                  Expanded(
                    child: _DeviceItem(
                      icon: '🦻',
                      name: device.name,
                      status: device.connected ? 'Connected' : 'Disconnected',
                      battery: device.battery,
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
                              )
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
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: HCColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: HCColors.primaryLight.withValues(alpha: 0.3)),
                        ),
                        child: const Text('ON', style: TextStyle(color: HCColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const _ModeIcon('🎯', 'Focus', true),
                      const _ModeIcon('🗣️', 'Conversation', false),
                      const _ModeIcon('🏃‍♂️', 'Outdoor', false),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Real-time Transcription
            const _SectionTitle(title: 'Real-time Transcription'),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  // Background Waveform
                  const Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: WaveformVisualizer(isActive: true),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Transcribing Live... [6:15 PM]', style: TextStyle(color: HCColors.textTertiary, fontSize: 11)),
                        SizedBox(height: 12),
                        Text(
                          '...great conversation today. Yes, I can\nhear you clearly now.',
                          style: TextStyle(fontSize: 14, height: 1.5, color: HCColors.textPrimary),
                        ),
                        Text(
                          '(User: "It\'s amazing!")',
                          style: TextStyle(fontSize: 14, height: 1.5, color: HCColors.accent),
                        ),
                        Text(
                          'The noise is significantly reduced. This\napp makes it easier to engage.',
                          style: TextStyle(fontSize: 14, height: 1.5, color: HCColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                            Text('Quick Scene', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Icon(Icons.arrow_forward_ios, size: 12, color: HCColors.textSecondary),
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
                            Text('Volume', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('75%', style: TextStyle(fontSize: 12, color: HCColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(colors: [HCColors.danger, HCColors.warning]),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: 10,
                                top: 2,
                                bottom: 2,
                                child: Container(
                                  width: 20,
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                ),
                              )
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
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HCColors.textPrimary)),
        if (actionText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: HCColors.glassBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(actionText!, style: const TextStyle(fontSize: 11, color: HCColors.textSecondary)),
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

  const _DeviceItem({required this.icon, required this.name, required this.status, required this.battery, required this.gradient});

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
                BoxShadow(color: gradient.colors.first.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))
              ]
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(status, style: const TextStyle(color: HCColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 16, height: 8,
                      decoration: BoxDecoration(
                        color: HCColors.success,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [BoxShadow(color: HCColors.success.withValues(alpha: 0.4), blurRadius: 4)]
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('$battery%', style: const TextStyle(color: HCColors.success, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _ModeIcon extends StatelessWidget {
  final String icon;
  final String label;
  final bool isActive;

  const _ModeIcon(this.icon, this.label, this.isActive);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? HCColors.primary.withValues(alpha: 0.2) : HCColors.glassBg,
            shape: BoxShape.circle,
            border: isActive ? Border.all(color: HCColors.primary) : null,
          ),
          child: Text(icon, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 11, color: isActive ? HCColors.primaryLight : HCColors.textSecondary, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
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
        border: isActive ? Border.all(color: HCColors.textPrimary.withValues(alpha: 0.5)) : null,
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: isActive ? HCColors.textPrimary : HCColors.textSecondary, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
    );
  }
}
