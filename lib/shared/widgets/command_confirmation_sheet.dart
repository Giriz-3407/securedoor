import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/access_control/domain/models/door_command.dart';
import '../../features/devices/domain/models/device.dart';

class CommandConfirmationSheet extends StatelessWidget {
  final Device device;
  final DoorAction action;
  final VoidCallback onConfirm;

  const CommandConfirmationSheet({
    super.key,
    required this.device,
    required this.action,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = action == DoorAction.open;
    final actionText = isOpen ? 'OPEN' : 'CLOSE';
    final actionColor = isOpen
        ? AppTheme.statusUnlocked
        : AppTheme.statusLocked;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isOpen
                        ? Icons.meeting_room_outlined
                        : Icons.lock_outline_rounded,
                    color: actionColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirm Door Operation',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    color: AppTheme.accentBlue,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'This physical actuation requires device biometric verification (Fingerprint or Face ID).',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFCBD5E1),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    child: Text('Authorize $actionText'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
