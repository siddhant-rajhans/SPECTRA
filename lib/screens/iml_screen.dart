import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/accuracy_ring.dart';
import '../widgets/confidence_bar.dart';
import '../widgets/screen_header.dart';
import '../models/sound_alert.dart';

class IMLScreen extends StatefulWidget {
  const IMLScreen({super.key});
  @override
  State<IMLScreen> createState() => _IMLScreenState();
}

class _IMLScreenState extends State<IMLScreen> {
  String _tab = 'review';
  bool _showCorrection = false;
  bool _trainingActive = false;
  double _trainingProgress = 0;

  void _trainModel() {
    setState(() { _trainingActive = true; _trainingProgress = 0; });
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _trainingProgress += Random().nextDouble() * 15 + 5;
        if (_trainingProgress >= 100) {
          _trainingProgress = 100;
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) setState(() { _trainingActive = false; _trainingProgress = 0; });
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      final stats = provider.imlStats;
      final pending = provider.pendingReviews;
      final reviewed = provider.reviewedItems;
      final accuracy = (stats.accuracy * 100).round();
      final current = pending.isNotEmpty ? pending.first : null;

      return ListView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), children: [
        // Header
        const ScreenHeader(icon: '🤖', title: 'Train AI', subtitle: 'SPECTRA interactive learning'),
        const SizedBox(height: 20),

        // Hero
        GlassCard(
          borderRadius: BorderRadius.circular(16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SPECTRA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: HCColors.textPrimary)),
              const Text('Your personal sound model', style: TextStyle(fontSize: 12, color: HCColors.textSecondary)),
              const SizedBox(height: 12),
              Row(children: [
                _miniStat('${stats.total}', 'Samples'),
                const SizedBox(width: 16),
                _miniStat('${stats.confirmed}', 'Confirmed'),
                const SizedBox(width: 16),
                _miniStat('${stats.corrected}', 'Corrected'),
              ]),
            ])),
            AccuracyRing(accuracy: accuracy.toDouble(), size: 90, strokeWidth: 7),
          ]),
        ),
        const SizedBox(height: 16),

        // Tabs
        Container(
          decoration: BoxDecoration(color: HCColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: HCColors.border)),
          child: Row(children: [
            _tabButton('Review', 'review', pending.length),
            _tabButton('Insights', 'insights', 0),
          ]),
        ),
        const SizedBox(height: 16),

        if (_tab == 'review') ..._buildReviewTab(provider, current, pending, reviewed, stats),
        if (_tab == 'insights') ..._buildInsightsTab(reviewed, pending),
        const SizedBox(height: 80),
      ]);
    });
  }

  List<Widget> _buildReviewTab(AppProvider provider, current, List pending, List reviewed, stats) {
    return [
      if (current != null) _buildReviewCard(provider, current)
      else GlassCard(
        borderRadius: BorderRadius.circular(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          const Text('All caught up!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('No pending reviews.', style: TextStyle(fontSize: 13, color: HCColors.textSecondary), textAlign: TextAlign.center),
        ]),
      ),
      const SizedBox(height: 16),

      // Train button
      GestureDetector(
        onTap: _trainingActive || stats.total == 0 ? null : _trainModel,
        child: Container(
          height: 48, width: double.infinity,
          decoration: BoxDecoration(
            gradient: _trainingActive ? null : HCColors.primaryGradient,
            color: _trainingActive ? HCColors.bgCard : null,
            borderRadius: BorderRadius.circular(12),
            border: _trainingActive ? Border.all(color: HCColors.primary) : null,
          ),
          child: Stack(children: [
            if (_trainingActive) Positioned(left: 0, top: 0, bottom: 0, child: Container(width: MediaQuery.of(context).size.width * _trainingProgress / 100, decoration: BoxDecoration(gradient: HCColors.primaryGradient, borderRadius: BorderRadius.circular(12)))),
            Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_trainingActive ? '' : '🧠 ', style: const TextStyle(fontSize: 18)),
              Text(_trainingActive ? 'Training SPECTRA... ${_trainingProgress.round()}%' : 'Train Model (${stats.total} samples)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ])),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      if (reviewed.isNotEmpty) ...[
        Text('RECENT REVIEWS', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: HCColors.textSecondary)),
        const SizedBox(height: 12),
        ...reviewed.take(5).map((item) {
          final info = SoundTypeInfo.fromType(item.type);
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: GlassCard(
            borderRadius: BorderRadius.circular(10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Text(info.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(info.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              Container(
                width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: item.isCorrect == true ? HCColors.success.withValues(alpha: 0.2) : HCColors.danger.withValues(alpha: 0.2)),
                child: Center(child: Text(item.isCorrect == true ? '✓' : '✗', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: item.isCorrect == true ? HCColors.success : HCColors.danger))),
              ),
            ]),
          ));
        }),
      ],
    ];
  }

  Widget _buildReviewCard(AppProvider provider, current) {
    final info = SoundTypeInfo.fromType(current.type);
    return GlassCard(
      borderRadius: BorderRadius.circular(16),
      child: _showCorrection ? _correctionPanel(provider, current) : Column(children: [
        // Sound viz
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: info.color.withValues(alpha: 0.25), width: 2), color: info.color.withValues(alpha: 0.08)),
          child: Center(child: Text(info.icon, style: const TextStyle(fontSize: 36))),
        ),
        const SizedBox(height: 12),
        RichText(text: TextSpan(children: [
          const TextSpan(text: 'Detected: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HCColors.textPrimary)),
          TextSpan(text: info.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: info.color)),
        ])),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (current.location != null) Text('📍 ${current.location}  ', style: const TextStyle(fontSize: 12, color: HCColors.textSecondary)),
          if (current.timeOfDay != null) Text('🕐 ${current.timeOfDay}', style: const TextStyle(fontSize: 12, color: HCColors.textSecondary)),
        ]),
        const SizedBox(height: 12),
        ConfidenceBar(confidence: current.confidence, color: info.color),
        const SizedBox(height: 16),
        const Text('Is this classification correct?', style: TextStyle(fontSize: 13, color: HCColors.textSecondary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: () => provider.submitFeedback(current.id, true),
            style: ElevatedButton.styleFrom(backgroundColor: HCColors.success),
            child: const Text('✓ Correct'),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(
            onPressed: () => setState(() => _showCorrection = true),
            style: ElevatedButton.styleFrom(backgroundColor: HCColors.danger),
            child: const Text('✗ Wrong'),
          )),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => provider.skipReview(current.id),
            child: const Text('⊘'),
          ),
        ]),
        if (provider.pendingReviews.length > 1) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${provider.pendingReviews.length - 1} more to review', style: const TextStyle(fontSize: 11, color: HCColors.textSecondary))),
      ]),
    );
  }

  Widget _correctionPanel(AppProvider provider, current) {
    final entries = SoundTypeInfo.allEntries;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('What was the actual sound?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text('Select the correct classification below', style: TextStyle(fontSize: 11, color: HCColors.textSecondary)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: entries.map((e) {
        return ActionChip(
          avatar: Text(e.value.icon),
          label: Text(e.value.label, style: const TextStyle(fontSize: 12)),
          backgroundColor: HCColors.bgDark,
          side: const BorderSide(color: HCColors.border),
          onPressed: () {
            provider.submitFeedback(current.id, false, correctedType: e.key);
            setState(() => _showCorrection = false);
          },
        );
      }).toList()),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => setState(() => _showCorrection = false), child: const Text('Cancel'))),
    ]);
  }

  List<Widget> _buildInsightsTab(List reviewed, List pending) {
    final all = [...reviewed, ...pending];
    final counts = <String, int>{};
    for (final item in all) { counts[item.type] = (counts[item.type] ?? 0) + 1; }
    final total = all.isEmpty ? 1 : all.length;
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return [
      Text('SOUND TYPES DETECTED', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: HCColors.textSecondary)),
      const SizedBox(height: 12),
      if (sorted.isEmpty) const Text('No sound data yet.', style: TextStyle(color: HCColors.textSecondary))
      else ...sorted.map((e) {
        final info = SoundTypeInfo.fromType(e.key);
        final pct = (e.value / total * 100).round();
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          Text(info.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(info.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('${e.value}x · $pct%', style: const TextStyle(fontSize: 11, color: HCColors.textSecondary)),
            ]),
            const SizedBox(height: 3),
            Container(height: 5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(3)),
              child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: pct / 100, child: Container(decoration: BoxDecoration(color: info.color, borderRadius: BorderRadius.circular(3))))),
          ])),
        ]));
      }),
      const SizedBox(height: 20),

      Text('HOW SPECTRA LEARNS', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: HCColors.textSecondary)),
      const SizedBox(height: 12),
      ...[('1', 'Detect', 'Microphone picks up ambient sounds and the classifier identifies them.'),
          ('2', 'Review', 'You confirm or correct the classification to provide ground truth.'),
          ('3', 'Learn', 'SPECTRA updates model weights based on your feedback.'),
          ('4', 'Personalize', 'Your model adapts to your specific environment and needs.')].map((s) =>
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 28, height: 28, decoration: const BoxDecoration(gradient: HCColors.accentGradient, shape: BoxShape.circle), alignment: Alignment.center, child: Text(s.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(s.$3, style: const TextStyle(fontSize: 12, color: HCColors.textSecondary, height: 1.3)),
          ])),
        ]))),
      const SizedBox(height: 12),
      GlassCard(
        borderRadius: BorderRadius.circular(12), padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('SPECTRA — Sound Processing Engine for Context-aware, Trainable, Real-time Alerts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Based on Goodman et al. (2025) Interactive Machine Learning framework. Your feedback loop continuously improves classification accuracy.', style: TextStyle(fontSize: 11, color: HCColors.textSecondary, height: 1.3)),
        ]),
      ),
    ];
  }

  Widget _miniStat(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(fontSize: 10, color: HCColors.textSecondary)),
    ]);
  }

  Widget _tabButton(String label, String tabId, int badge) {
    final active = _tab == tabId;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tab = tabId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: active ? HCColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : HCColors.textSecondary)),
          if (badge > 0) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: HCColors.danger, borderRadius: BorderRadius.circular(8)), child: Text('$badge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)))],
        ]),
      ),
    ));
  }
}
