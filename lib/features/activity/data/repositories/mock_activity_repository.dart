import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/activity_log.dart';
import '../../domain/repositories/activity_repository.dart';

class MockActivityRepository implements ActivityRepository {
  final List<ActivityLog> _logs = [
    ActivityLog(
      id: 'log_001',
      deviceId: 'esp32_lab_door_01',
      deviceName: 'LAB DOOR 01',
      operation: OperationType.open,
      status: OperationStatus.success,
      authMethod: 'Biometric (Fingerprint)',
      timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
      requestId: 'f6b2e100-84a1-420a-814d-17e0b5711e21',
    ),
    ActivityLog(
      id: 'log_002',
      deviceId: 'esp32_lab_door_01',
      deviceName: 'LAB DOOR 01',
      operation: OperationType.close,
      status: OperationStatus.success,
      authMethod: 'Biometric (Fingerprint)',
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      requestId: 'a89c3132-70b1-412e-9d2a-89a3c10b1477',
    ),
    ActivityLog(
      id: 'log_003',
      deviceId: 'esp32_server_room_03',
      deviceName: 'SERVER ROOM ACCESS',
      operation: OperationType.open,
      status: OperationStatus.offline,
      authMethod: 'Biometric (Face ID)',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      requestId: '04bfa491-c1fe-45a7-96a2-e64e527cc5aa',
      failureReason: 'Device is offline and unreachable.',
    ),
    ActivityLog(
      id: 'log_004',
      deviceId: 'esp32_restricted_archive_04',
      deviceName: 'RESTRICTED ARCHIVE',
      operation: OperationType.open,
      status: OperationStatus.unauthorized,
      authMethod: 'Biometric (Fingerprint)',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      requestId: '62e106b2-65f2-4bd5-a134-8845ffab908e',
      failureReason: 'Insufficient privilege role for archival vault.',
    ),
  ];

  @override
  Future<Result<List<ActivityLog>>> getActivityLogs({String? deviceId}) async {
    AppLogger.info('MockActivityRepository: fetching activity logs');
    await Future.delayed(const Duration(milliseconds: 250));
    if (deviceId != null) {
      final filtered = _logs.where((l) => l.deviceId == deviceId).toList();
      return Result.success(List.unmodifiable(filtered));
    }
    return Result.success(List.unmodifiable(_logs));
  }

  @override
  Future<Result<void>> logActivity(ActivityLog log) async {
    _logs.insert(0, log);
    AppLogger.info(
      'MockActivityRepository: added log ${log.id} (${log.operation.name})',
    );
    return Result.success(null);
  }
}
