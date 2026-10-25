class AppConstants {
  static const String appName = 'Secure IoE Door Access';
  static const String appVersion = '1.0.0 (Engineering Demo)';

  // Secure Storage Keys
  static const String keyAccessToken = 'sec_access_token';
  static const String keyRefreshToken = 'sec_refresh_token';
  static const String keyUserId = 'sec_user_id';
  static const String keyUserEmail = 'sec_user_email';
  static const String keyUserName = 'sec_user_name';
  static const String keyUserRole = 'sec_user_role';
  static const String keyBiometricEnrolled = 'sec_biometric_enrolled';

  // Command Settings
  static const Duration defaultDebounceDuration = Duration(milliseconds: 1500);
  static const Duration pollingInterval = Duration(seconds: 4);

  // Security
  static const int minPasswordLength = 8;
}
