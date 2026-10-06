enum OperationType { open, close, refresh, login, logout }

enum OperationStatus { success, failed, unauthorized, timedOut, offline }

class ActivityLog {
  final String id;
  final String deviceId;
  final String deviceName;
  final OperationType operation;
  final OperationStatus status;
  final String
  authMethod; // 'Biometric (Fingerprint/Face)', 'Password fallback', etc.
  final DateTime timestamp;
  final String requestId;
  final String? failureReason;

  const ActivityLog({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.operation,
    required this.status,
    required this.authMethod,
    required this.timestamp,
    required this.requestId,
    this.failureReason,
  });

  bool get isSuccess => status == OperationStatus.success;

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String? ?? 'unknown',
      deviceName: json['deviceName'] as String? ?? 'Door Access Device',
      operation: switch (json['operation']) {
        'OPEN' => OperationType.open,
        'CLOSE' => OperationType.close,
        'LOGIN' => OperationType.login,
        'LOGOUT' => OperationType.logout,
        _ => OperationType.refresh,
      },
      status: switch (json['status']) {
        'SUCCESS' => OperationStatus.success,
        'UNAUTHORIZED' => OperationStatus.unauthorized,
        'TIMED_OUT' => OperationStatus.timedOut,
        'OFFLINE' => OperationStatus.offline,
        _ => OperationStatus.failed,
      },
      authMethod: json['authMethod'] as String? ?? 'Biometric authentication',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      requestId: json['requestId'] as String? ?? '',
      failureReason: json['failureReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'operation': operation.name.toUpperCase(),
    'status': status.name.toUpperCase(),
    'authMethod': authMethod,
    'timestamp': timestamp.toIso8601String(),
    'requestId': requestId,
    'failureReason': failureReason,
  };
}
