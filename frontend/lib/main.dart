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
  runApp(const HearClearApp());
}

class HearClearApp extends StatelessWidget {
  const HearClearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'HearClear',
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
