import '../../../../core/utils/result.dart';
import '../models/door_command.dart';

abstract class AccessControlRepository {
  Future<Result<CommandExecutionResult>> executeCommand(
    DoorCommandPayload command, {
    void Function(CommandExecutionStage stage)? onStageChanged,
  });
}
