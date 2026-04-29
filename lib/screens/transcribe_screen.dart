import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/waveform_visualizer.dart';
import '../widgets/screen_header.dart';

class TranscribeScreen extends StatelessWidget {
  const TranscribeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final isRecording = provider.isTranscribing;
        final lines = provider.transcriptLines;

        return ListView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), children: [
          // Header
          const ScreenHeader(icon: '📝', title: 'Transcribe', subtitle: 'Real-time speech to text'),
          const SizedBox(height: 20),

          // Waveform
          GlassCard(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: Column(children: [
              WaveformVisualizer(isActive: isRecording, barCount: 9, height: 72),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  isRecording ? '🎙️ Listening...' : '⏸️ Paused',
                  key: ValueKey(isRecording),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isRecording ? HCColors.accent : HCColors.textSecondary,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Transcript
          GlassCard(
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 180,
              child: lines.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isRecording ? '🎧' : '💬',
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isRecording ? 'Waiting for audio...' : 'Tap Start to begin transcribing',
                            style: const TextStyle(fontSize: 14, color: HCColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: lines.length,
                      itemBuilder: (context, i) {
                        final line = lines[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: HCColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  line.speaker,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: HCColors.primaryLight),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  line.text,
                                  style: const TextStyle(fontSize: 14, color: HCColors.textPrimary, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Info bar
          GlassCard(
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _infoItem('Language', 'English'),
              Container(width: 1, height: 24, color: HCColors.border),
              _infoItem('Speakers', '${lines.map((l) => l.speaker).toSet().length + (lines.isEmpty ? 1 : 0)}'),
              Container(width: 1, height: 24, color: HCColors.border),
              _infoItem('Lines', '${lines.length}'),
            ]),
          ),
          const SizedBox(height: 20),

          // Controls — Big start/stop button + icon buttons
          Row(children: [
            // Download icon button
            _iconButton(
              icon: Icons.download_rounded,
              onPressed: lines.isEmpty ? null : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download feature coming soon'), behavior: SnackBarBehavior.floating),
                );
              },
            ),
            const SizedBox(width: 12),

            // Start/Stop button
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isRecording) {
                      provider.stopTranscription();
                    } else {
                      provider.startTranscription();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording ? HCColors.danger : HCColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(isRecording ? Icons.stop_rounded : Icons.mic_rounded, size: 20),
                  label: Text(
                    isRecording ? 'Stop Recording' : 'Start Recording',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Copy icon button
            _iconButton(
              icon: Icons.copy_rounded,
              onPressed: lines.isEmpty ? null : () {
                final text = lines.map((l) => '${l.speaker}: ${l.text}').join('\n');
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard'), behavior: SnackBarBehavior.floating),
                );
              },
            ),
          ]),
          const SizedBox(height: 80),
        ]);
      },
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback? onPressed}) {
    return SizedBox(
      width: 52,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: onPressed != null ? HCColors.border : HCColors.border.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 20, color: onPressed != null ? HCColors.primaryLight : HCColors.textSecondary.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: HCColors.textSecondary, letterSpacing: 0.3)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    ]);
  }
}
