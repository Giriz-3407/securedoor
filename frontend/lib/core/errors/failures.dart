/// Domain-level failure representation.
/// Hides low-level technical stack traces and translates them into user-friendly messages.
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message =
        'Unable to contact server. Please check your network connection.',
    super.code,
  ]);
}

class AuthFailure extends Failure {
  const AuthFailure([
    super.message = 'Invalid credentials or session expired.',
    super.code,
  ]);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'You are not authorized to perform this operation.',
    super.code,
  ]);
}

class DeviceOfflineFailure extends Failure {
  const DeviceOfflineFailure([
    super.message = 'Device is currently offline and cannot process commands.',
    super.code,
  ]);
}

class BiometricFailure extends Failure {
  final BiometricErrorReason reason;

  const BiometricFailure({
    required this.reason,
    String message = 'Biometric authentication was not completed.',
    String? code,
  }) : super(message, code);
}

enum BiometricErrorReason {
  notAvailable,
  notEnrolled,
  userCancelled,
  failed,
  lockedOut,
  permissionDenied,
}

class CommandTimeoutFailure extends Failure {
  const CommandTimeoutFailure([
    super.message = 'Command timed out. Device did not acknowledge in time.',
    super.code,
  ]);
}

class DeviceExecutionFailure extends Failure {
  const DeviceExecutionFailure([
    super.message = 'Physical latch failed to reach target state.',
    super.code,
  ]);
}

class DuplicateCommandFailure extends Failure {
  const DuplicateCommandFailure([
    super.message =
        'A command is already being processed for this device. Please wait.',
    super.code,
  ]);
}

class StorageFailure extends Failure {
  const StorageFailure([
    super.message = 'Secure key storage operation failed.',
    super.code,
  ]);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'An unexpected error occurred. Please try again.',
    super.code,
  ]);
}
