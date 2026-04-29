import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// Settings screen for the backend host. Lets the user point the app at a
/// laptop on the LAN (or a hosted server) and verify connectivity. Reachable
/// from the auth screen (before login) and the profile screen.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _hostController;
  bool _saving = false;
  bool? _reachable;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: ApiClient.host);
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _saveAndPing() async {
    final raw = _hostController.text.trim();
    if (raw.isEmpty) {
      setState(() => _statusMessage = 'Enter a host like 192.168.1.42:3001');
      return;
    }
    setState(() {
      _saving = true;
      _reachable = null;
      _statusMessage = null;
    });
    try {
      await ApiClient.setHost(raw);
      final ok = await ApiClient.ping();
      if (!mounted) return;
      setState(() {
        _reachable = ok;
        _statusMessage = ok
            ? 'Server reachable at ${ApiClient.host}'
            : 'Saved, but ${ApiClient.host} did not respond. Check the host, port, and that both devices share a network.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reachable = false;
        _statusMessage = 'Failed to save: $e';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _useSuggested(String value) {
    _hostController.text = value;
    _hostController.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HCColors.bgDark,
      appBar: AppBar(
        title: const Text('Server', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backend host',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HCColors.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Point the app at the machine running the SPECTRA backend. Use a LAN address (host:port) when both devices share Wi-Fi.',
                  style: TextStyle(fontSize: 12, color: HCColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _hostController,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                  decoration: const InputDecoration(
                    hintText: '192.168.1.42:3001',
                    prefixIcon: Icon(Icons.dns_rounded, color: HCColors.textSecondary, size: 20),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _suggestionChip('Android emulator', '10.0.2.2:3001'),
                    _suggestionChip('iOS simulator', 'localhost:3001'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveAndPing,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.wifi_tethering_rounded, size: 18),
                    label: Text(_saving ? 'Testing…' : 'Save & test connection'),
                  ),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _reachable == true
                            ? Icons.check_circle_rounded
                            : (_reachable == false ? Icons.error_rounded : Icons.info_rounded),
                        size: 18,
                        color: _reachable == true
                            ? HCColors.success
                            : (_reachable == false ? HCColors.danger : HCColors.warning),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(fontSize: 12, color: HCColors.textSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Quick reference',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HCColors.textPrimary),
                ),
                SizedBox(height: 8),
                _RefRow(label: 'Same Wi-Fi', value: 'Use the laptop\'s LAN IP, e.g. 192.168.1.42:3001'),
                _RefRow(label: 'Find IP (macOS)', value: 'System Settings → Wi-Fi → Details, or `ipconfig getifaddr en0`'),
                _RefRow(label: 'Find IP (Windows)', value: 'Run `ipconfig` and use the IPv4 address of the active adapter'),
                _RefRow(label: 'Tunnel', value: 'For remote testing, run `cloudflared tunnel` and paste the hostname'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label, String value) {
    return ActionChip(
      label: Text('$label · $value'),
      labelStyle: const TextStyle(fontSize: 11, color: HCColors.textPrimary),
      backgroundColor: HCColors.bgCard.withValues(alpha: 0.6),
      side: const BorderSide(color: HCColors.border),
      onPressed: () => _useSuggested(value),
    );
  }
}

class _RefRow extends StatelessWidget {
  final String label;
  final String value;
  const _RefRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: HCColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: HCColors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
