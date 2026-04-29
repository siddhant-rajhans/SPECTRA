import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/battery_bar.dart';
import '../widgets/screen_header.dart';
import '../models/sound_alert.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final device = provider.deviceStatus;
        final env = provider.environment;
        final alerts = provider.alerts.take(3).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header
            ScreenHeader(
              icon: '👂',
              title: 'HearClear',
              subtitle: 'Welcome back, ${provider.currentUser?.name ?? 'User'}',
            ),
            const SizedBox(height: 20),

            // Device Status Card
            GlassCard(
              borderRadius: BorderRadius.circular(16),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(
                    child: Text(device.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: device.connected ? HCColors.success.withValues(alpha: 0.12) : HCColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: device.connected ? HCColors.success : HCColors.danger,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          device.connected ? 'Connected' : 'Disconnected',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: device.connected ? HCColors.success : HCColors.danger),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                BatteryBar(level: device.battery),
              ]),
            ),
            const SizedBox(height: 14),

            // Context Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: HCColors.contextBannerGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HCColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _contextChip('📍', env.location),
                  Container(width: 1, height: 20, color: HCColors.border),
                  _contextChip('🕐', TimeOfDay.now().format(context)),
                  Container(width: 1, height: 20, color: HCColors.border),
                  _contextChip('📅', env.calendarStatus ?? 'Free'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            const SectionTitle(title: 'Quick Actions'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _actionCard('🔔', 'Smart Alerts', 'View & manage', () => provider.setActiveTab(1)),
                _actionCard('📝', 'Transcribe', 'Speech to text', () => provider.setActiveTab(2)),
                _actionCard('🤖', 'Train AI', 'Improve SPECTRA', () => provider.setActiveTab(3)),
                _actionCard('⚡', 'Test Alert', 'Simulate sound', () {
                  provider.showNotification(type: 'doorbell', title: '🔔 Doorbell Detected', description: 'Someone is at your door', contextReasoning: 'Context-aware delivery based on your location and schedule.');
                  provider.addAlert(SoundAlert(id: 'test-${DateTime.now().millisecondsSinceEpoch}', type: 'doorbell', confidence: 0.92, delivered: true, contextReasoning: 'Test alert delivered.', location: env.location, timeOfDay: env.timeOfDay, timestamp: DateTime.now()));
                }),
              ],
            ),
            const SizedBox(height: 24),

            // How It Works
            const SectionTitle(title: 'How It Works'),
            const SizedBox(height: 12),
            GlassCard(
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int i = 0; i < _pipelineSteps.length; i++) ...[
                    _pipelineStep(_pipelineSteps[i].$1, _pipelineSteps[i].$2),
                    if (i < _pipelineSteps.length - 1)
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: HCColors.textSecondary),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Alerts
            if (alerts.isNotEmpty) ...[
              const SectionTitle(title: 'Recent Alerts'),
              const SizedBox(height: 12),
              ...alerts.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _alertItem(a),
                  )),
            ],
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  static const _pipelineSteps = [('🎤', 'Listen'), ('🧠', 'Classify'), ('📍', 'Context'), ('🔍', 'Filter'), ('🔔', 'Alert')];

  Widget _contextChip(String icon, String label) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: HCColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _actionCard(String icon, String label, String sub, VoidCallback onTap) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const Spacer(),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(sub, style: const TextStyle(fontSize: 11, color: HCColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _pipelineStep(String icon, String label) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: HCColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _alertItem(SoundAlert alert) {
    final info = SoundTypeInfo.fromType(alert.type);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: info.color.withValues(alpha: 0.1),
            ),
            child: Center(child: Text(info.icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(info.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      '${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: HCColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.contextReasoning ?? '',
                  style: const TextStyle(fontSize: 11, color: HCColors.textSecondary, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: alert.delivered ? HCColors.success.withValues(alpha: 0.12) : HCColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              alert.delivered ? '✓' : '✗',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: alert.delivered ? HCColors.success : HCColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
