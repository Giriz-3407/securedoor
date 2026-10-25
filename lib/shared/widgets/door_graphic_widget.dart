import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/devices/domain/models/device.dart';

class DoorGraphicWidget extends StatelessWidget {
  final DoorState doorState;
  final LatchState latchState;
  final bool isOnline;

  const DoorGraphicWidget({
    super.key,
    required this.doorState,
    required this.latchState,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = latchState == LatchState.locked;
    final isTransitioning = latchState == LatchState.transitioning;

    Color primaryColor;
    if (!isOnline) {
      primaryColor = AppTheme.statusOffline;
    } else if (isTransitioning) {
      primaryColor = AppTheme.statusPending;
    } else if (isLocked) {
      primaryColor = AppTheme.statusLocked;
    } else {
      primaryColor = AppTheme.statusUnlocked;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      doorState == DoorState.open
                          ? Icons.meeting_room_outlined
                          : Icons.sensor_door_rounded,
                      size: 56,
                      color: isOnline ? primaryColor : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        doorState == DoorState.open ? 'OPEN' : 'CLOSED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Servo Latch Indicator Badge
              Positioned(
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOnline ? primaryColor : AppTheme.surfaceLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    isTransitioning
                        ? Icons.sync_rounded
                        : (isLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            !isOnline
                ? 'Device Offline'
                : (isTransitioning
                      ? 'Servo Actuating Latch...'
                      : (isLocked
                            ? 'Mechanical Latch Secured'
                            : 'Mechanical Latch Released')),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            !isOnline
                ? 'Heartbeat signal lost. Check Wi-Fi connection of ESP32.'
                : 'Physical state monitored via limit switches & optical encoder',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
