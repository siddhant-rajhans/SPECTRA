import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_overlay.dart';
import '../widgets/screen_flash_overlay.dart';
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
                        Color(0x2A6C5CE7), // Enhanced background glow
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Main content
              SafeArea(
                bottom: false,
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
              
              // Floating Bottom Navigation Bar
              if (!_showImplantConnect)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          color: HCColors.bgCard.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: HCColors.glassBorder,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                ),

              // Screen flash burst — fires on every new alert, regardless of
              // whether the user has the notification dialog open.
              ScreenFlashOverlay(
                alertCounter: provider.alertCounter,
                alertSoundType: provider.lastAlertSoundType,
                alertColor: resolveFlashColor(provider.lastAlertSoundType),
              ),

              // Notification overlay
              if (provider.notification != null) const NotificationOverlay(),
            ],
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
        width: 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Container(
                padding: EdgeInsets.only(bottom: isActive ? 2 : 0),
                decoration: isActive ? BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: HCColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                ) : null,
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? HCColors.primaryLight : HCColors.textTertiary,
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
