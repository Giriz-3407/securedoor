import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../networking/api_client.dart';
import '../security/biometric_service.dart';
import '../storage/secure_storage_service.dart';

import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../../features/authentication/data/repositories/mock_auth_repository.dart';

import '../../features/devices/domain/repositories/device_repository.dart';
import '../../features/devices/data/repositories/device_repository_impl.dart';
import '../../features/devices/data/repositories/mock_device_repository.dart';

import '../../features/access_control/domain/repositories/access_control_repository.dart';
import '../../features/access_control/data/repositories/access_control_repository_impl.dart';
import '../../features/access_control/data/repositories/mock_access_control_repository.dart';

import '../../features/activity/domain/repositories/activity_repository.dart';
import '../../features/activity/data/repositories/activity_repository_impl.dart';
import '../../features/activity/data/repositories/mock_activity_repository.dart';

/// Application configuration provider
final configProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

/// Platform secure storage provider
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return FlutterSecureStorageServiceImpl();
});

/// Biometric service provider
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return LocalAuthBiometricService();
});

/// Core API client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final config = ref.watch(configProvider);
  return HttpApiClient(secureStorage: storage, config: config);
});

/// Shared mock instances to keep state consistent across providers during mock sessions
final _mockDeviceRepoInstance = MockDeviceRepository();
final _mockActivityRepoInstance = MockActivityRepository();

/// Authentication repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(configProvider);
  final storage = ref.watch(secureStorageProvider);
  final apiClient = ref.watch(apiClientProvider);

  if (config.isMockMode) {
    return MockAuthRepository(storage: storage);
  } else {
    return AuthRepositoryImpl(apiClient: apiClient, storage: storage);
  }
});

/// Device repository provider
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final config = ref.watch(configProvider);
  final apiClient = ref.watch(apiClientProvider);

  if (config.isMockMode) {
    return _mockDeviceRepoInstance;
  } else {
    return DeviceRepositoryImpl(apiClient: apiClient);
  }
});

/// Activity repository provider
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final config = ref.watch(configProvider);
  final apiClient = ref.watch(apiClientProvider);

  if (config.isMockMode) {
    return _mockActivityRepoInstance;
  } else {
    return ActivityRepositoryImpl(apiClient: apiClient);
  }
});

/// Access control repository provider
final accessControlRepositoryProvider = Provider<AccessControlRepository>((
  ref,
) {
  final config = ref.watch(configProvider);
  final apiClient = ref.watch(apiClientProvider);

  if (config.isMockMode) {
    return MockAccessControlRepository(
      deviceRepository: _mockDeviceRepoInstance,
      activityRepository: _mockActivityRepoInstance,
    );
  } else {
    return AccessControlRepositoryImpl(apiClient: apiClient);
  }
});
