import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/devices/domain/models/device.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  factory StatusPill.connectivity(DeviceConnectivity connectivity) {
    final isOnline = connectivity == DeviceConnectivity.online;
    return StatusPill(
      label: isOnline ? 'Online' : 'Offline',
      color: isOnline ? AppTheme.statusOnline : AppTheme.statusOffline,
      icon: isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
    );
  }

  factory StatusPill.latch(LatchState latchState) {
    return switch (latchState) {
      LatchState.locked => const StatusPill(
        label: 'Locked',
        color: AppTheme.statusLocked,
        icon: Icons.lock_rounded,
      ),
      LatchState.unlocked => const StatusPill(
        label: 'Unlocked',
        color: AppTheme.statusUnlocked,
        icon: Icons.lock_open_rounded,
      ),
      LatchState.transitioning => const StatusPill(
        label: 'Actuating...',
        color: AppTheme.statusPending,
        icon: Icons.sync_rounded,
      ),
      LatchState.unknown => const StatusPill(
        label: 'Unknown',
        color: Colors.grey,
        icon: Icons.help_outline_rounded,
      ),
    };
  }

  factory StatusPill.door(DoorState doorState) {
    return switch (doorState) {
      DoorState.open => const StatusPill(
        label: 'Door Ajar',
        color: AppTheme.statusUnlocked,
        icon: Icons.meeting_room_outlined,
      ),
      DoorState.closed => const StatusPill(
        label: 'Door Closed',
        color: AppTheme.statusOnline,
        icon: Icons.sensor_door_rounded,
      ),
      DoorState.unknown => const StatusPill(
        label: 'Position Unknown',
        color: Colors.grey,
        icon: Icons.help_outline_rounded,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
