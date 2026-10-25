import 'package:uuid/uuid.dart';

enum DoorAction { open, close }

enum CommandExecutionStage {
  idle,
  confirming,
  authenticatingBiometrics,
  sendingCommand,
  commandAcknowledged,
  deviceResponding,
  physicalStateConfirmed,
  failed,
  unauthorized,
  timedOut,
  deviceOffline,
}

class DoorCommandPayload {
  final String deviceId;
  final DoorAction action;
  final String requestId;
  final DateTime timestamp;
  final String authenticationContext; // e.g., 'biometric_os'

  DoorCommandPayload({
    required this.deviceId,
    required this.action,
    String? requestId,
    DateTime? timestamp,
    this.authenticationContext = 'biometric_os',
  }) : requestId = requestId ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'command': action.name.toUpperCase(),
    'requestId': requestId,
    'timestamp': timestamp.toIso8601String(),
    'authenticationContext': authenticationContext,
  };

  factory DoorCommandPayload.fromJson(Map<String, dynamic> json) {
    return DoorCommandPayload(
      deviceId: json['deviceId'] as String,
      action: (json['command'] == 'OPEN') ? DoorAction.open : DoorAction.close,
      requestId: json['requestId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      authenticationContext:
          json['authenticationContext'] as String? ?? 'biometric_os',
    );
  }
}

class CommandExecutionResult {
  final bool isSuccess;
  final CommandExecutionStage finalStage;
  final String message;
  final String requestId;
  final DateTime completedAt;
  final String? serverAckId;

  const CommandExecutionResult({
    required this.isSuccess,
    required this.finalStage,
    required this.message,
    required this.requestId,
    required this.completedAt,
    this.serverAckId,
  });
}
