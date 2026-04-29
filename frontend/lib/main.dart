import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.initialize();

  // Restore the persisted session (if any) before the first frame so cold
  // starts go straight into MainShell instead of flashing the auth screen.
  final provider = AppProvider();
  await provider.restoreSession();

  runApp(SpectraApp(provider: provider));
}

class SpectraApp extends StatelessWidget {
  final AppProvider provider;
  const SpectraApp({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'SPECTRA',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: provider.isAuthenticated
                ? const MainShell()
                : const AuthScreen(),
          );
        },
      ),
    );
  }
}
