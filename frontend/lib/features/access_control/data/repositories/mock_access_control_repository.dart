import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../../activity/domain/models/activity_log.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../devices/data/repositories/mock_device_repository.dart';
import '../../../devices/domain/models/device.dart';
import '../../domain/models/door_command.dart';
import '../../domain/repositories/access_control_repository.dart';

class MockAccessControlRepository implements AccessControlRepository {
  final MockDeviceRepository deviceRepository;
  final ActivityRepository activityRepository;

  MockAccessControlRepository({
    required this.deviceRepository,
    required this.activityRepository,
  });

  @override
  Future<Result<CommandExecutionResult>> executeCommand(
    DoorCommandPayload command, {
    void Function(CommandExecutionStage stage)? onStageChanged,
  }) async {
    AppLogger.info(
      'MockAccessControlRepository: executing ${command.action.name.toUpperCase()} for ${command.deviceId}',
    );

    // Stage 1: Sending command
    onStageChanged?.call(CommandExecutionStage.sendingCommand);
    await Future.delayed(const Duration(milliseconds: 350));

    // Fetch device to inspect online status and permissions
    final deviceResult = await deviceRepository.getDeviceById(command.deviceId);
    if (deviceResult.isFailure || deviceResult.dataOrNull == null) {
      onStageChanged?.call(CommandExecutionStage.failed);
      return Result.failure(
        const UnexpectedFailure('Target device could not be resolved.'),
      );
    }

    final device = deviceResult.dataOrNull!;

    // Check device connectivity
    if (!device.isOnline) {
      onStageChanged?.call(CommandExecutionStage.deviceOffline);
      await activityRepository.logActivity(
        ActivityLog(
          id: const Uuid().v4(),
          deviceId: device.id,
          deviceName: device.name,
          operation: command.action == DoorAction.open
              ? OperationType.open
              : OperationType.close,
          status: OperationStatus.offline,
          authMethod: 'Biometric (OS Verified)',
          timestamp: DateTime.now(),
          requestId: command.requestId,
          failureReason: 'Physical node is offline (heartbeat absent).',
        ),
      );
      return Result.failure(
        const DeviceOfflineFailure(
          'Device is currently offline. Cannot send command to physical latch.',
        ),
      );
    }

    // Check authorization permissions
    final hasPermission = command.action == DoorAction.open
        ? device.permissions.canOpen
        : device.permissions.canClose;

    if (!hasPermission) {
      onStageChanged?.call(CommandExecutionStage.unauthorized);
      await activityRepository.logActivity(
        ActivityLog(
          id: const Uuid().v4(),
          deviceId: device.id,
          deviceName: device.name,
          operation: command.action == DoorAction.open
              ? OperationType.open
              : OperationType.close,
          status: OperationStatus.unauthorized,
          authMethod: 'Biometric (OS Verified)',
          timestamp: DateTime.now(),
          requestId: command.requestId,
          failureReason:
              'Operator account lacks authorization for this door perimeter.',
        ),
      );
      return Result.failure(
        const UnauthorizedFailure(
          'You are not authorized to control this device.',
        ),
      );
    }

    // Stage 2: Backend accepted
    onStageChanged?.call(CommandExecutionStage.commandAcknowledged);
    await Future.delayed(const Duration(milliseconds: 400));

    // Stage 3: ESP32 servo responding
    onStageChanged?.call(CommandExecutionStage.deviceResponding);
    // Simulate servo transit time
    deviceRepository.updateDeviceState(
      device.id,
      latchState: LatchState.transitioning,
    );
    await Future.delayed(const Duration(milliseconds: 650));

    // Stage 4: Physical confirmation
    final newDoorState = command.action == DoorAction.open
        ? DoorState.open
        : DoorState.closed;
    final newLatchState = command.action == DoorAction.open
        ? LatchState.unlocked
        : LatchState.locked;
    deviceRepository.updateDeviceState(
      device.id,
      doorState: newDoorState,
      latchState: newLatchState,
    );

    onStageChanged?.call(CommandExecutionStage.physicalStateConfirmed);

    // Audit log
    await activityRepository.logActivity(
      ActivityLog(
        id: const Uuid().v4(),
        deviceId: device.id,
        deviceName: device.name,
        operation: command.action == DoorAction.open
            ? OperationType.open
            : OperationType.close,
        status: OperationStatus.success,
        authMethod: 'Biometric (OS Verified)',
        timestamp: DateTime.now(),
        requestId: command.requestId,
      ),
    );

    return Result.success(
      CommandExecutionResult(
        isSuccess: true,
        finalStage: CommandExecutionStage.physicalStateConfirmed,
        message:
            'Physical latch successfully ${command.action == DoorAction.open ? "unlocked" : "locked"}.',
        requestId: command.requestId,
        completedAt: DateTime.now(),
        serverAckId: 'ack_${const Uuid().v4().substring(0, 8)}',
      ),
    );
  }
}
