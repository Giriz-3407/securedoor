import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/access_control/domain/models/door_command.dart';
import '../../features/access_control/presentation/controllers/command_controller.dart';

class CommandProgressDialog extends StatelessWidget {
  final CommandState state;
  final VoidCallback onDismiss;

  const CommandProgressDialog({
    super.key,
    required this.state,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final stage = state.stage;
    final isDone =
        stage == CommandExecutionStage.physicalStateConfirmed ||
        stage == CommandExecutionStage.failed ||
        stage == CommandExecutionStage.unauthorized ||
        stage == CommandExecutionStage.timedOut ||
        stage == CommandExecutionStage.deviceOffline;

    final isSuccess = stage == CommandExecutionStage.physicalStateConfirmed;

    Color stageColor;
    IconData stageIcon;

    switch (stage) {
      case CommandExecutionStage.authenticatingBiometrics:
        stageColor = AppTheme.statusPending;
        stageIcon = Icons.fingerprint_rounded;
        break;
      case CommandExecutionStage.sendingCommand:
        stageColor = AppTheme.accentBlue;
        stageIcon = Icons.cloud_upload_outlined;
        break;
      case CommandExecutionStage.commandAcknowledged:
        stageColor = AppTheme.statusLocked;
        stageIcon = Icons.check_circle_outline_rounded;
        break;
      case CommandExecutionStage.deviceResponding:
        stageColor = AppTheme.statusUnlocked;
        stageIcon = Icons.settings_remote_rounded;
        break;
      case CommandExecutionStage.physicalStateConfirmed:
        stageColor = AppTheme.statusOnline;
        stageIcon = Icons.verified_rounded;
        break;
      case CommandExecutionStage.deviceOffline:
      case CommandExecutionStage.unauthorized:
      case CommandExecutionStage.timedOut:
      case CommandExecutionStage.failed:
        stageColor = AppTheme.statusOffline;
        stageIcon = Icons.error_outline_rounded;
        break;
      default:
        stageColor = AppTheme.accentBlue;
        stageIcon = Icons.hourglass_top_rounded;
    }

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: stageColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: isDone
                  ? Icon(stageIcon, color: stageColor, size: 40)
                  : SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(stageColor),
                        strokeWidth: 3,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Text(
              isDone
                  ? (isSuccess ? 'Command Completed' : 'Operation Failed')
                  : 'Executing Remote Command',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              state.feedbackMessage ?? 'Processing...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            // Stage progression indicators
            _buildStageSteps(stage),
            const SizedBox(height: 20),
            if (isDone)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess
                        ? AppTheme.accentBlue
                        : AppTheme.surfaceLight,
                    foregroundColor: isSuccess
                        ? Colors.white
                        : AppTheme.textPrimary,
                  ),
                  onPressed: onDismiss,
                  child: const Text('Close'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageSteps(CommandExecutionStage stage) {
    final stages = [
      (CommandExecutionStage.authenticatingBiometrics, 'Biometric Auth'),
      (CommandExecutionStage.sendingCommand, 'Send Command'),
      (CommandExecutionStage.commandAcknowledged, 'Server Ack'),
      (CommandExecutionStage.deviceResponding, 'ESP32 Actuation'),
      (CommandExecutionStage.physicalStateConfirmed, 'Physical Confirmed'),
    ];

    final currentIndex = switch (stage) {
      CommandExecutionStage.authenticatingBiometrics => 0,
      CommandExecutionStage.sendingCommand => 1,
      CommandExecutionStage.commandAcknowledged => 2,
      CommandExecutionStage.deviceResponding => 3,
      CommandExecutionStage.physicalStateConfirmed => 4,
      _ => -1,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(stages.length, (index) {
        final isPassed = currentIndex >= index;
        final isCurrent = currentIndex == index;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 28,
          height: 6,
          decoration: BoxDecoration(
            color: isCurrent
                ? AppTheme.accentBlue
                : (isPassed ? AppTheme.statusOnline : AppTheme.borderColor),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
