import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../logging/app_logger.dart';

enum BiometricStatus {
  success,
  failure,
  userCancelled,
  notAvailable,
  notEnrolled,
  lockedOut,
  otherError,
}

class BiometricCheckCapability {
  final bool canCheckBiometrics;
  final bool isDeviceSupported;
  final List<BiometricType> availableBiometrics;

  const BiometricCheckCapability({
    required this.canCheckBiometrics,
    required this.isDeviceSupported,
    required this.availableBiometrics,
  });

  bool get isReady =>
      canCheckBiometrics && isDeviceSupported && availableBiometrics.isNotEmpty;
}

abstract class BiometricService {
  Future<BiometricCheckCapability> checkBiometrics();
  Future<BiometricStatus> authenticate({
    required String reason,
    String? cancelTitle,
    bool biometricOnly = true,
  });
}

class LocalAuthBiometricService implements BiometricService {
  final LocalAuthentication _auth;

  LocalAuthBiometricService([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  @override
  Future<BiometricCheckCapability> checkBiometrics() async {
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final available = await _auth.getAvailableBiometrics();

      AppLogger.info(
        'Biometric check: supported=$isDeviceSupported, canCheck=$canCheck, availableCount=${available.length}',
      );

      return BiometricCheckCapability(
        canCheckBiometrics: canCheck,
        isDeviceSupported: isDeviceSupported,
        availableBiometrics: available,
      );
    } catch (e, st) {
      AppLogger.error('Failed to check biometric capabilities', e, st);
      return const BiometricCheckCapability(
        canCheckBiometrics: false,
        isDeviceSupported: false,
        availableBiometrics: [],
      );
    }
  }

  @override
  Future<BiometricStatus> authenticate({
    required String reason,
    String? cancelTitle,
    bool biometricOnly = true,
  }) async {
    try {
      AppLogger.info('Triggering OS biometric prompt with reason: "$reason"');

      // The OS handles all biometric dialogs, sensors, and matching.
      // Flutter ONLY receives a boolean success indicator or platform exception.
      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        AppLogger.info('OS Biometric authentication succeeded.');
        return BiometricStatus.success;
      } else {
        AppLogger.warn(
          'OS Biometric authentication was not completed by user.',
        );
        return BiometricStatus.userCancelled;
      }
    } on PlatformException catch (e) {
      AppLogger.warn('OS Biometric PlatformException code: ${e.code}');
      return switch (e.code) {
        'PasscodeNotSet' || 'NotEnrolled' => BiometricStatus.notEnrolled,
        'NotAvailable' => BiometricStatus.notAvailable,
        'LockedOut' || 'PermanentlyLockedOut' => BiometricStatus.lockedOut,
        'UserCancel' => BiometricStatus.userCancelled,
        _ => BiometricStatus.failure,
      };
    } catch (e, st) {
      AppLogger.error(
        'Unexpected error during biometric authentication',
        e,
        st,
      );
      return BiometricStatus.otherError;
    }
  }
}

/// Simulated biometric service for automated testing and demo environments.
class MockBiometricService implements BiometricService {
  bool shouldSucceed;
  BiometricStatus mockResult;

  MockBiometricService({
    this.shouldSucceed = true,
    this.mockResult = BiometricStatus.success,
  });

  @override
  Future<BiometricCheckCapability> checkBiometrics() async {
    return const BiometricCheckCapability(
      canCheckBiometrics: true,
      isDeviceSupported: true,
      availableBiometrics: [BiometricType.fingerprint],
    );
  }

  @override
  Future<BiometricStatus> authenticate({
    required String reason,
    String? cancelTitle,
    bool biometricOnly = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return shouldSucceed ? BiometricStatus.success : mockResult;
  }
}
