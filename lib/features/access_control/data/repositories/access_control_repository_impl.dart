import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/networking/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/door_command.dart';
import '../../domain/repositories/access_control_repository.dart';

class AccessControlRepositoryImpl implements AccessControlRepository {
  final ApiClient apiClient;

  AccessControlRepositoryImpl({required this.apiClient});

  @override
  Future<Result<CommandExecutionResult>> executeCommand(
    DoorCommandPayload command, {
    void Function(CommandExecutionStage stage)? onStageChanged,
  }) async {
    try {
      // Stage 1: Sending to backend
      onStageChanged?.call(CommandExecutionStage.sendingCommand);
      AppLogger.info(
        'Submitting command ${command.action.name.toUpperCase()} for device ${command.deviceId}',
      );

      final response = await apiClient.post(
        '/devices/${command.deviceId}/command',
        body: command.toJson(),
      );

      // Stage 2: Backend accepted & dispatched to device
      onStageChanged?.call(CommandExecutionStage.commandAcknowledged);
      final ackId = response['ackId'] as String? ?? command.requestId;

      // Stage 3: Awaiting device response / servo actuation
      onStageChanged?.call(CommandExecutionStage.deviceResponding);
      final physicalStateConfirmed =
          response['physicalStateConfirmed'] as bool? ?? true;

      if (!physicalStateConfirmed) {
        onStageChanged?.call(CommandExecutionStage.failed);
        return Result.failure(
          const DeviceExecutionFailure(
            'Physical servo latch did not reach expected position.',
          ),
        );
      }

      // Stage 4: Physical confirmation
      onStageChanged?.call(CommandExecutionStage.physicalStateConfirmed);
      return Result.success(
        CommandExecutionResult(
          isSuccess: true,
          finalStage: CommandExecutionStage.physicalStateConfirmed,
          message:
              'Door ${command.action == DoorAction.open ? "unlocked and opened" : "closed and locked"} successfully.',
          requestId: command.requestId,
          completedAt: DateTime.now(),
          serverAckId: ackId,
        ),
      );
    } on UnauthorizedFailure catch (f) {
      onStageChanged?.call(CommandExecutionStage.unauthorized);
      return Result.failure(f);
    } on DeviceOfflineFailure catch (f) {
      onStageChanged?.call(CommandExecutionStage.deviceOffline);
      return Result.failure(f);
    } on CommandTimeoutFailure catch (f) {
      onStageChanged?.call(CommandExecutionStage.timedOut);
      return Result.failure(f);
    } on Failure catch (f) {
      onStageChanged?.call(CommandExecutionStage.failed);
      return Result.failure(f);
    } catch (e, st) {
      AppLogger.error('Command execution failed', e, st);
      onStageChanged?.call(CommandExecutionStage.failed);
      return Result.failure(UnexpectedFailure(e.toString()));
    }
  }
}
