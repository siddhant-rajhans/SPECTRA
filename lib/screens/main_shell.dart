import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_overlay.dart';
import 'home_screen.dart';
import 'alerts_screen.dart';
import 'transcribe_screen.dart';
import 'iml_screen.dart';
import 'environment_screen.dart';
import 'profile_screen.dart';
import 'implant_connect_screen.dart';

/// Main app shell with tab bar navigation and notification overlay.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _showImplantConnect = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: HCColors.bgDark,
          body: Stack(
            children: [
              // Background gradient
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.8, -0.6),
                      radius: 1.5,
                      colors: [
                        Color(0x1A6C5CE7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Main content
              SafeArea(
                child: _showImplantConnect
                    ? ImplantConnectScreen(
                        onBack: () => setState(() => _showImplantConnect = false),
                      )
                    : IndexedStack(
                        index: provider.activeTab,
                        children: [
                          const HomeScreen(),
                          const AlertsScreen(),
                          const TranscribeScreen(),
                          const IMLScreen(),
                          const EnvironmentScreen(),
                          ProfileScreen(
                            onNavigateToImplants: () =>
                                setState(() => _showImplantConnect = true),
                          ),
                        ],
                      ),
              ),
              // Notification overlay
              if (provider.notification != null) const NotificationOverlay(),
            ],
          ),
          bottomNavigationBar: _showImplantConnect
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    color: Color(0xF20F0F1A),
                    border: Border(top: BorderSide(color: HCColors.border, width: 0.5)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 60,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _TabItem(icon: '🏠', label: 'Home', index: 0, active: provider.activeTab),
                          _TabItem(icon: '🔔', label: 'Alerts', index: 1, active: provider.activeTab),
                          _TabItem(icon: '📝', label: 'Transcribe', index: 2, active: provider.activeTab),
                          _TabItem(icon: '🤖', label: 'Train AI', index: 3, active: provider.activeTab),
                          _TabItem(icon: '⚙️', label: 'Settings', index: 4, active: provider.activeTab),
                          _TabItem(icon: '👤', label: 'Profile', index: 5, active: provider.activeTab),
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

class _TabItem extends StatelessWidget {
  final String icon;
  final String label;
  final int index;
  final int active;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == active;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.read<AppProvider>().setActiveTab(index),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Active indicator dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: isActive ? 4 : 0,
              height: isActive ? 4 : 0,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: HCColors.primary,
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [BoxShadow(color: HCColors.primary.withValues(alpha: 0.5), blurRadius: 6)]
                    : [],
              ),
            ),
            AnimatedScale(
              scale: isActive ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? HCColors.primary : HCColors.textSecondary,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
