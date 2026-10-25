import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/security/biometric_service.dart';
import '../../../activity/presentation/controllers/activity_controller.dart';
import '../../../devices/domain/models/device.dart';
import '../../../devices/presentation/controllers/device_controllers.dart';
import '../../domain/models/door_command.dart';
import '../../domain/repositories/access_control_repository.dart';

class CommandState {
  final CommandExecutionStage stage;
  final String? activeDeviceId;
  final DoorAction? activeAction;
  final String? feedbackMessage;
  final bool isExecuting;

  const CommandState({
    this.stage = CommandExecutionStage.idle,
    this.activeDeviceId,
    this.activeAction,
    this.feedbackMessage,
    this.isExecuting = false,
  });

  CommandState copyWith({
    CommandExecutionStage? stage,
    String? activeDeviceId,
    DoorAction? activeAction,
    String? feedbackMessage,
    bool? isExecuting,
  }) {
    return CommandState(
      stage: stage ?? this.stage,
      activeDeviceId: activeDeviceId ?? this.activeDeviceId,
      activeAction: activeAction ?? this.activeAction,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      isExecuting: isExecuting ?? this.isExecuting,
    );
  }
}

class CommandController extends Notifier<CommandState> {
  AccessControlRepository get _repository =>
      ref.read(accessControlRepositoryProvider);
  BiometricService get _biometricService => ref.read(biometricServiceProvider);

  DateTime? _lastExecutionTime;

  @override
  CommandState build() {
    ref.watch(accessControlRepositoryProvider);
    ref.watch(biometricServiceProvider);
    return const CommandState();
  }

  /// Primary command dispatcher with safety checks & biometric gate
  Future<bool> triggerDoorAction({
    required Device device,
    required DoorAction action,
  }) async {
    // 1. Debounce protection against rapid double-taps
    final now = DateTime.now();
    if (_lastExecutionTime != null &&
        now.difference(_lastExecutionTime!) <
            AppConstants.defaultDebounceDuration) {
      AppLogger.warn('Command rejected: debouncing rapid double-tap');
      return false;
    }
    if (state.isExecuting) {
      AppLogger.warn(
        'Command rejected: another command is currently executing',
      );
      return false;
    }
    _lastExecutionTime = now;

    // 2. Offline guard: Never attempt remote command if device is offline
    if (!device.isOnline) {
      state = state.copyWith(
        stage: CommandExecutionStage.deviceOffline,
        isExecuting: false,
        activeDeviceId: device.id,
        activeAction: action,
        feedbackMessage:
            '${device.name} is offline. Remote command cannot be delivered.',
      );
      return false;
    }

    // 3. Biometric Authentication Gate via Mobile OS
    state = state.copyWith(
      stage: CommandExecutionStage.authenticatingBiometrics,
      activeDeviceId: device.id,
      activeAction: action,
      isExecuting: true,
      feedbackMessage: 'Awaiting biometric authorization on device...',
    );

    final actionWord = action == DoorAction.open ? 'open' : 'close';
    final biometricResult = await _biometricService.authenticate(
      reason: 'Authenticate to $actionWord ${device.name}',
    );

    if (biometricResult != BiometricStatus.success) {
      final failMsg = switch (biometricResult) {
        BiometricStatus.userCancelled => 'Authentication was cancelled.',
        BiometricStatus.notEnrolled => 'No device biometrics enrolled.',
        BiometricStatus.notAvailable => 'Biometric hardware unavailable.',
        BiometricStatus.lockedOut => 'Biometrics locked out. Try later.',
        _ => 'Biometric verification failed.',
      };

      state = state.copyWith(
        stage: CommandExecutionStage.failed,
        isExecuting: false,
        feedbackMessage: failMsg,
      );
      return false;
    }

    // 4. Dispatch Command to AccessControlRepository
    final payload = DoorCommandPayload(
      deviceId: device.id,
      action: action,
      authenticationContext: 'biometric_os_verified',
    );

    final result = await _repository.executeCommand(
      payload,
      onStageChanged: (stage) {
        final stageMessage = switch (stage) {
          CommandExecutionStage.sendingCommand =>
            'Sending command to secure server...',
          CommandExecutionStage.commandAcknowledged =>
            'Server verified authorization. Forwarding to ESP32...',
          CommandExecutionStage.deviceResponding =>
            'ESP32 pulse active. Physical servo latch actuating...',
          CommandExecutionStage.physicalStateConfirmed =>
            'Physical latch state verified!',
          CommandExecutionStage.unauthorized =>
            'Unauthorized: Operator privilege denied.',
          CommandExecutionStage.deviceOffline =>
            'Device went offline during dispatch.',
          CommandExecutionStage.timedOut => 'ESP32 response timed out.',
          _ => null,
        };

        state = state.copyWith(stage: stage, feedbackMessage: stageMessage);
      },
    );

    // Refresh devices list and activity logs after command
    ref.read(deviceListProvider.notifier).refresh();
    ref.read(activityListProvider.notifier).refresh();

    return result.when(
      onSuccess: (cmdResult) {
        state = state.copyWith(
          stage: CommandExecutionStage.physicalStateConfirmed,
          isExecuting: false,
          feedbackMessage: cmdResult.message,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          stage: CommandExecutionStage.failed,
          isExecuting: false,
          feedbackMessage: failure.message,
        );
        return false;
      },
    );
  }

  void reset() {
    state = const CommandState();
  }
}

final commandControllerProvider =
    NotifierProvider<CommandController, CommandState>(CommandController.new);
