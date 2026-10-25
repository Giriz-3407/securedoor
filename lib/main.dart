import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/logging/app_logger.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/presentation/controllers/auth_controller.dart';
import 'features/authentication/presentation/screens/login_screen.dart';
import 'features/devices/presentation/screens/device_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load configuration
  final config = AppConfig.fromEnvironment();
  AppLogger.setEnabled(config.enableDetailedLogging);
  AppLogger.info(
    'Starting ${AppConstants.appName} in ${config.environment.name} mode (mock=${config.isMockMode})',
  );

  runApp(
    ProviderScope(
      overrides: [configProvider.overrideWithValue(config)],
      child: const SecureDoorAccessApp(),
    ),
  );
}

class SecureDoorAccessApp extends ConsumerWidget {
  const SecureDoorAccessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: switch (authState) {
        Authenticated() => const DeviceListScreen(),
        AuthLoading() => const _AppSplashScreen(),
        _ => const LoginScreen(),
      },
    );
  }
}

class _AppSplashScreen extends StatelessWidget {
  const _AppSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 56, color: AppTheme.accentBlue),
            SizedBox(height: 24),
            CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
            ),
            SizedBox(height: 16),
            Text(
              'Verifying Security Context...',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
