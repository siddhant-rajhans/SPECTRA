import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Alert notification overlay dialog.
/// Matches the React NotificationOverlay component.
class NotificationOverlay extends StatelessWidget {
  const NotificationOverlay({super.key});

  static const _iconMap = {
    'doorbell': '🔔',
    'fire_alarm': '🚨',
    'car_horn': '🚗',
    'name_called': '👤',
    'alarm_timer': '⏱️',
    'baby_crying': '👶',
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final notification = provider.notification;
        if (notification == null) return const SizedBox.shrink();

        final icon = _iconMap[notification['type']] ?? '📢';

        return Material(
          color: Colors.black54,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  gradient: HCColors.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: HCColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 32,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsing icon
                    _PulsingIcon(icon: icon),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      notification['title'] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: HCColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Description
                    Text(
                      notification['description'] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: HCColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    // Context reasoning
                    if (notification['contextReasoning'] != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: HCColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 12,
                              color: HCColors.primaryLight,
                              height: 1.3,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Why: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: notification['contextReasoning']),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Buttons
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => provider.hideNotification(),
                            child: const Text('Dismiss'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              provider.setActiveTab(3); // Train AI
                              provider.hideNotification();
                            },
                            child: const Text('Was this right?'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final String icon;
  const _PulsingIcon({required this.icon});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Text(widget.icon, style: const TextStyle(fontSize: 48)),
    );
  }
}
