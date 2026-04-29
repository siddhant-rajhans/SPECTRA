import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/battery_bar.dart';
import '../models/device_status.dart';
import '../services/mock_data.dart';

class ImplantConnectScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ImplantConnectScreen({super.key, required this.onBack});

  @override
  State<ImplantConnectScreen> createState() => _ImplantConnectScreenState();
}

class _ImplantConnectScreenState extends State<ImplantConnectScreen> {
  String _displayName = '';
  String? _selectedModel;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      final connected = provider.connectedImplants;
      final available = provider.availableProviders;

      return ListView(padding: const EdgeInsets.all(16), children: [
        // Back button
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_ios, size: 16, color: HCColors.primaryLight),
          label: const Text('Back', style: TextStyle(color: HCColors.primaryLight)),
        )),
        const Text('Connect Implants', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Link your hearing device accounts to access battery, settings, and features', style: TextStyle(fontSize: 13, color: HCColors.textSecondary)),
        const SizedBox(height: 20),

        // Connected
        if (connected.isNotEmpty) ...[
          Text('CONNECTED DEVICES', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: HCColors.textSecondary)),
          const SizedBox(height: 12),
          ...connected.map((d) => _connectedCard(provider, d)),
          const SizedBox(height: 20),
        ],

        // Available
        if (available.isNotEmpty) ...[
          Text('AVAILABLE PROVIDERS', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: HCColors.textSecondary)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
            itemCount: available.length,
            itemBuilder: (context, i) => _providerCard(context, provider, available[i]),
          ),
        ],

        if (connected.isEmpty && available.isEmpty)
          const Center(child: Text('No providers available', style: TextStyle(color: HCColors.textSecondary))),
        const SizedBox(height: 80),
      ]);
    });
  }

  Widget _connectedCard(AppProvider provider, ConnectedImplant d) {
    final logo = MockData.providerLogos[d.providerName] ?? '🔌';
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: GlassCard(
      borderRadius: BorderRadius.circular(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: HCColors.accent.withValues(alpha: 0.1)), child: Center(child: Text(logo, style: const TextStyle(fontSize: 20)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text('${d.providerName} • ${d.deviceModel ?? 'Device'}', style: const TextStyle(fontSize: 12, color: HCColors.textSecondary)),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Battery', style: TextStyle(fontSize: 11, color: HCColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(child: BatteryBar(level: d.battery)),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Firmware v${d.firmwareVersion ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: HCColors.textSecondary)),
          Text('Last synced ${d.lastSynced != null ? _timeAgo(d.lastSynced!) : 'Never'}', style: const TextStyle(fontSize: 11, color: HCColors.textSecondary)),
        ]),
        if (d.features.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: d.features.map((f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: HCColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(f, style: const TextStyle(fontSize: 10, color: HCColors.primaryLight)),
          )).toList()),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('⟳ Sync', style: TextStyle(fontSize: 12)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            onPressed: () => provider.disconnectImplant(d.id),
            style: OutlinedButton.styleFrom(foregroundColor: HCColors.danger, side: const BorderSide(color: HCColors.danger)),
            child: const Text('✕ Disconnect', style: TextStyle(fontSize: 12)),
          )),
        ]),
      ]),
    ));
  }

  Widget _providerCard(BuildContext context, AppProvider provider, ImplantProvider p) {
    final logo = MockData.providerLogos[p.name] ?? '🔌';
    return GlassCard(
      borderRadius: BorderRadius.circular(12), padding: const EdgeInsets.all(14),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(logo, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 6),
        Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text('${p.features.length} features', style: const TextStyle(fontSize: 11, color: HCColors.textSecondary)),
        const Spacer(),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => _showConnectSheet(context, provider, p),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8), textStyle: const TextStyle(fontSize: 12)),
          child: const Text('Connect'),
        )),
      ]),
    );
  }

  void _showConnectSheet(BuildContext context, AppProvider provider, ImplantProvider p) {
    _displayName = p.name;
    _selectedModel = null;

    showModalBottomSheet(
      context: context, backgroundColor: HCColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Connect ${p.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Enter your device information', style: TextStyle(fontSize: 13, color: HCColors.textSecondary)),
          const SizedBox(height: 20),
          const Text('Display Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HCColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            onChanged: (v) => setSheetState(() => _displayName = v),
            controller: TextEditingController(text: _displayName),
            style: const TextStyle(color: HCColors.textPrimary),
            decoration: const InputDecoration(hintText: 'e.g., My Device'),
          ),
          if (p.models.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Device Model', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HCColors.textSecondary)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: HCColors.bgDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: HCColors.border)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: _selectedModel, isExpanded: true, dropdownColor: HCColors.bgCard,
                hint: const Text('Select a model...', style: TextStyle(color: HCColors.textSecondary)),
                style: const TextStyle(color: HCColors.textPrimary, fontSize: 14),
                items: p.models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setSheetState(() => _selectedModel = v),
              )),
            ),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () {
                provider.connectImplant(ConnectedImplant(
                  id: 'conn-${DateTime.now().millisecondsSinceEpoch}',
                  providerId: p.id, providerName: p.name,
                  displayName: _displayName.isEmpty ? p.name : _displayName,
                  deviceModel: _selectedModel, battery: 85, firmwareVersion: '1.0.0',
                  lastSynced: DateTime.now(), features: p.features,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Connect'),
            )),
          ]),
          SizedBox(height: MediaQuery.of(ctx).viewInsets.bottom),
        ]));
      }),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
