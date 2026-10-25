enum OperationType { open, close, refresh, login, logout }

enum OperationStatus { success, failed, unauthorized, timedOut, offline }

class ActivityLog {
  final String id;
  final String deviceId;
  final String deviceName;
  final OperationType operation;
  final OperationStatus status;
  final String authMethod; // 'Biometric (Fingerprint/Face)', 'Password fallback', etc.
  final DateTime timestamp;
  final String requestId;
  final String? failureReason;
  final String? triggeredBy;

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
    this.triggeredBy,
  });

  bool get isSuccess => status == OperationStatus.success;

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? 'failed').toString().toUpperCase();
    final rawOp = (json['operation'] ?? json['action'] ?? 'refresh').toString().toUpperCase();

    final status = switch (rawStatus) {
      'SUCCESS' || 'OK' || 'TRUE' => OperationStatus.success,
      'UNAUTHORIZED' || 'FORBIDDEN' => OperationStatus.unauthorized,
      'TIMED_OUT' || 'TIMEOUT' => OperationStatus.timedOut,
      'OFFLINE' => OperationStatus.offline,
      _ => OperationStatus.failed,
    };

    final operation = switch (rawOp) {
      'OPEN' || 'UNLOCK' || 'UNLOCKED' => OperationType.open,
      'CLOSE' || 'LOCK' || 'LOCKED' => OperationType.close,
      'LOGIN' => OperationType.login,
      'LOGOUT' => OperationType.logout,
      _ => OperationType.refresh,
    };

    final authMethod = json['authMethod'] ??
        (json['authenticationMethod'] == 'biometric_os'
            ? 'Biometric Authentication'
            : json['authenticationMethod']) ??
        'Biometric Authentication';

    return ActivityLog(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      deviceId: json['deviceId'] as String? ?? 'esp32_front_door_01',
      deviceName: json['deviceName'] as String? ?? 'Main Entrance Door',
      operation: operation,
      status: status,
      authMethod: authMethod.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      requestId: json['requestId'] as String? ?? '',
      failureReason: json['failureReason'] as String?,
      triggeredBy: json['triggeredBy'] as String?,
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
    'triggeredBy': triggeredBy,
  };
}
