/// Application configuration for Secure IoE Remote Door Access.
/// Supports compile-time environment flags (--dart-define) or runtime injection.
enum AppEnvironment { development, testing, production }

class AppConfig {
  final AppEnvironment environment;
  final String apiBaseUrl;
  final Duration requestTimeout;
  final Duration commandAckTimeout;
  final bool isMockMode;
  final bool enableDetailedLogging;

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.requestTimeout = const Duration(seconds: 10),
    this.commandAckTimeout = const Duration(seconds: 15),
    this.isMockMode = true,
    this.enableDetailedLogging = true,
  });

  /// Factory constructor that resolves configuration from compile-time flags
  /// or falls back to secure defaults for the engineering demo.
  factory AppConfig.fromEnvironment() {
    const envString = String.fromEnvironment('ENV', defaultValue: 'dev');
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.secure-access.internal/v1',
    );
    // By default in demo/college lab environment, mock mode is enabled so it runs
    // seamlessly without requiring a running backend on day 1.
    const mockFlag = bool.fromEnvironment('MOCK_MODE', defaultValue: true);

    final environment = switch (envString.toLowerCase()) {
      'prod' || 'production' => AppEnvironment.production,
      'test' || 'testing' => AppEnvironment.testing,
      _ => AppEnvironment.development,
    };

    return AppConfig(
      environment: environment,
      apiBaseUrl: baseUrl,
      isMockMode: mockFlag,
      enableDetailedLogging: environment != AppEnvironment.production,
    );
  }

  /// Helper to create a custom config (e.g. for unit and integration testing)
  AppConfig copyWith({
    AppEnvironment? environment,
    String? apiBaseUrl,
    Duration? requestTimeout,
    Duration? commandAckTimeout,
    bool? isMockMode,
    bool? enableDetailedLogging,
  }) {
    return AppConfig(
      environment: environment ?? this.environment,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      commandAckTimeout: commandAckTimeout ?? this.commandAckTimeout,
      isMockMode: isMockMode ?? this.isMockMode,
      enableDetailedLogging:
          enableDetailedLogging ?? this.enableDetailedLogging,
    );
  }
}
