import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_header.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback? onNavigateToImplants;
  const ProfileScreen({super.key, this.onNavigateToImplants});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      final user = provider.currentUser;
      final device = provider.deviceStatus;
      final stats = provider.imlStats;

      return ListView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), children: [
        // Screen header
        ScreenHeader(
          icon: '👤',
          title: 'Profile',
          subtitle: user?.email ?? '',
          trailing: IconButton(
            onPressed: () => provider.logout(),
            icon: const Icon(Icons.logout_rounded, color: HCColors.textSecondary, size: 20),
            tooltip: 'Sign Out',
          ),
        ),
        const SizedBox(height: 20),

        // Profile card
        if (user != null) GlassCard(
          borderRadius: BorderRadius.circular(16),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: HCColors.primaryGradient),
              alignment: Alignment.center,
              child: Text(user.avatarInitial, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(device.name, style: const TextStyle(fontSize: 13, color: HCColors.textSecondary)),
              if (user.hearingLossLevel != null)
                Text('${user.hearingLossLevel} hearing loss', style: const TextStyle(fontSize: 11, color: HCColors.accent)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),

        _settingsGroup('Device Settings', [
          _item('Battery & Charging', '🔋 ${device.battery}%'),
          _item('Bluetooth Streaming', '✓ Enabled'),
          _item('Find My Hearing Aid', '✓ Enabled'),
          if (onNavigateToImplants != null)
            GlassCard(
              onTap: onNavigateToImplants, borderRadius: BorderRadius.circular(10), padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('🔗 Connect Implant Accounts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                SizedBox(height: 2),
                Text('Cochlear, Phonak, Oticon, and more', style: TextStyle(fontSize: 11, color: HCColors.textSecondary)),
              ]),
            ),
        ]),
        const SizedBox(height: 20),

        _settingsGroup('Smart Alerts', [
          _item('Smartwatch Alerts', '✓ Enabled'),
          _item('Flash Notifications', '✓ Enabled'),
          _item('Calendar Integration', '✓ Enabled'),
        ]),
        const SizedBox(height: 20),

        _settingsGroup('ML & Personalization', [
          _item('Classifier Model (SPECTRA)', '${stats.confirmed} samples'),
          _item('Hearing Health Score', '85/100'),
        ]),
        const SizedBox(height: 32),

        // Footer
        const Center(child: Column(children: [
          Text('HearClear v1.0.0', style: TextStyle(fontSize: 12, color: HCColors.textSecondary)),
          SizedBox(height: 2),
          Text('Companion App for SPECTRA', style: TextStyle(fontSize: 11, color: HCColors.textSecondary)),
          SizedBox(height: 2),
          Text('Stevens Institute of Technology', style: TextStyle(fontSize: 11, color: HCColors.textSecondary)),
        ])),
        const SizedBox(height: 80),
      ]);
    });
  }

  Widget _settingsGroup(String title, List<Widget> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: HCColors.textSecondary)),
      const SizedBox(height: 12),
      ...items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)),
    ]);
  }

  Widget _item(String label, String value) {
    return GlassCard(
      borderRadius: BorderRadius.circular(10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 13, color: HCColors.textSecondary)),
      ]),
    );
  }
}
