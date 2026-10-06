import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_door_access/core/config/app_config.dart';
import 'package:secure_door_access/core/providers/app_providers.dart';
import 'package:secure_door_access/core/storage/secure_storage_service.dart';
import 'package:secure_door_access/main.dart';

void main() {
  testWidgets('SecureDoorAccessApp launches into LoginScreen by default', (
    WidgetTester tester,
  ) async {
    final mockStorage = InMemorySecureStorageService();
    const testConfig = AppConfig(
      environment: AppEnvironment.testing,
      apiBaseUrl: 'https://test-api.internal',
      isMockMode: true,
      enableDetailedLogging: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(testConfig),
          secureStorageProvider.overrideWithValue(mockStorage),
        ],
        child: const SecureDoorAccessApp(),
      ),
    );

    // Initial frame may show loading/splash
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify Login Screen appears
    expect(find.text('IoE Remote Access'), findsOneWidget);
    expect(find.text('Academic Email / Username'), findsOneWidget);
    expect(find.text('Authenticate Session'), findsOneWidget);
  });
}
