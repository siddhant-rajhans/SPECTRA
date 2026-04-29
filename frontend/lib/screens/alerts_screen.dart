import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_header.dart';
import '../models/sound_alert.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return ListView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), children: [
          // Header
          const ScreenHeader(icon: '🔔', title: 'Smart Alerts', subtitle: 'Manage sounds & context rules'),
          const SizedBox(height: 24),

          // Monitored Sounds
          const SectionTitle(title: 'Monitored Sounds'),
          const SizedBox(height: 12),
          ...provider.monitoredSounds.map((s) => _soundToggle(provider, s)),
          const SizedBox(height: 24),

          // Context Rules
          const SectionTitle(title: 'Context Rules'),
          const SizedBox(height: 12),
          _buildRulesGrid(provider),
          const SizedBox(height: 24),

          // Alert History
          if (provider.alerts.isNotEmpty) ...[
            const SectionTitle(title: 'Alert History'),
            const SizedBox(height: 12),
            ...provider.alerts.map((a) => _alertHistoryItem(a)),
          ],
          const SizedBox(height: 80),
        ]);
      },
    );
  }

  Widget _soundToggle(AppProvider provider, s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        borderRadius: BorderRadius.circular(14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.isEnabled ? HCColors.primary.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
            ),
            child: Center(child: Text(s.icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                if (s.isLocked) const Text('Always on · Safety', style: TextStyle(fontSize: 10, color: HCColors.accent)),
              ],
            ),
          ),
          Switch(
            value: s.isEnabled,
            onChanged: s.isLocked ? null : (_) => provider.toggleMonitoredSound(s.type),
          ),
        ]),
      ),
    );
  }

  Widget _buildRulesGrid(AppProvider provider) {
    final rules = provider.contextRules;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: rules.length,
      itemBuilder: (context, i) {
        final rule = rules[i];
        return GlassCard(
          onTap: () => provider.toggleContextRule(rule.id),
          borderColor: rule.isActive ? HCColors.primary : HCColors.border,
          gradient: rule.isActive
              ? LinearGradient(colors: [HCColors.primary.withValues(alpha: 0.12), HCColors.bgCard])
              : null,
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rule.icon, style: const TextStyle(fontSize: 28)),
            const Spacer(),
            Text(rule.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              rule.description,
              style: const TextStyle(fontSize: 10, color: HCColors.textSecondary, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: rule.isActive ? HCColors.accent.withValues(alpha: 0.15) : HCColors.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                rule.isActive ? '● Active' : '○ Standby',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: rule.isActive ? HCColors.accent : HCColors.textSecondary,
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _alertHistoryItem(SoundAlert alert) {
    final info = SoundTypeInfo.fromType(alert.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: info.color.withValues(alpha: 0.1),
              ),
              child: Center(child: Text(info.icon, style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(info.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${(alert.confidence * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: HCColors.accent)),
                  ],
                ),
                if (alert.contextReasoning != null) ...[
                  const SizedBox(height: 4),
                  Text(alert.contextReasoning!, style: const TextStyle(fontSize: 11, color: HCColors.textSecondary, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ]),
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
      ),
    );
  }
}
