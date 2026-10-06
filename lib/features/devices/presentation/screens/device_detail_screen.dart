import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/command_confirmation_sheet.dart';
import '../../../../shared/widgets/command_progress_dialog.dart';
import '../../../../shared/widgets/mock_banner.dart';
import '../../../access_control/domain/models/door_command.dart';
import '../../../access_control/presentation/controllers/command_controller.dart';
import '../../../activity/presentation/screens/activity_log_screen.dart';
import '../controllers/device_controllers.dart';
import '../../domain/models/device.dart';

class DeviceDetailScreen extends ConsumerStatefulWidget {
  final Device initialDevice;

  const DeviceDetailScreen({super.key, required this.initialDevice});

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen> {
  late String _deviceId;

  @override
  void initState() {
    super.initState();
    _deviceId = widget.initialDevice.id;
  }

  void _initiateCommand(Device device, DoorAction action) {
    if (!device.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.statusOffline,
          content: Text(
            '${device.name} is offline. Operation aborted for safety.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommandConfirmationSheet(
        device: device,
        action: action,
        onConfirm: () async {
          _executeWithProgress(device, action);
        },
      ),
    );
  }

  Future<void> _executeWithProgress(Device device, DoorAction action) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Consumer(
        builder: (context, ref, _) {
          final cmdState = ref.watch(commandControllerProvider);
          return CommandProgressDialog(
            state: cmdState,
            onDismiss: () {
              Navigator.of(dialogCtx).pop();
              ref.read(commandControllerProvider.notifier).reset();
            },
          );
        },
      ),
    );

    await ref
        .read(commandControllerProvider.notifier)
        .triggerDoorAction(device: device, action: action);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    final devicesState = ref.watch(deviceListProvider);

    // Resolve latest live device from state if available
    Device device = widget.initialDevice;
    if (devicesState is DeviceListLoaded) {
      final found = devicesState.devices
          .where((d) => d.id == _deviceId)
          .firstOrNull;
      if (found != null) {
        device = found;
      }
    }

    final isOnline = device.isOnline;
    final isLocked = device.isLocked;
    final isTransitioning = device.latchState == LatchState.transitioning;
    final lastSeenStr = DateFormat('h:mm:ss a').format(device.lastSeen);

    // Action toggle:
    // If locked or closed -> Next action is OPEN
    // If unlocked or open -> Next action is CLOSE
    final bool isClosedOrLocked =
        isLocked || device.doorState != DoorState.open;
    final DoorAction targetAction = isClosedOrLocked
        ? DoorAction.open
        : DoorAction.close;

    // Theme & State Styling for the Centerpiece Controller
    final Color stateColor = !isOnline
        ? AppTheme.statusOffline
        : (isTransitioning
              ? AppTheme.statusPending
              : (isClosedOrLocked
                    ? AppTheme.statusLocked
                    : AppTheme.statusUnlocked));

    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: [
          IconButton(
            tooltip: 'View Device History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActivityLogScreen(targetDeviceId: device.id),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh Status',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(deviceListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (config.isMockMode) const MockBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Subtitle & Online Indicator Header
                    Column(
                      children: [
                        Text(
                          device.description.isNotEmpty
                              ? device.description
                              : 'Physical Access Perimeter',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isOnline
                                        ? AppTheme.statusOnline
                                        : AppTheme.statusOffline)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  (isOnline
                                          ? AppTheme.statusOnline
                                          : AppTheme.statusOffline)
                                      .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? AppTheme.statusOnline
                                      : AppTheme.statusOffline,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOnline ? 'Device Online' : 'Device Offline',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOnline
                                      ? AppTheme.statusOnline
                                      : AppTheme.statusOffline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Central Hero Circular Lock Controller
                    GestureDetector(
                      onTap: (isOnline && !isTransitioning)
                          ? () => _initiateCommand(device, targetAction)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E293B),
                          border: Border.all(
                            color: stateColor.withValues(alpha: 0.6),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: stateColor.withValues(
                                alpha: isOnline ? 0.25 : 0.05,
                              ),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isTransitioning)
                                SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      stateColor,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  !isOnline
                                      ? Icons.wifi_off_rounded
                                      : (isClosedOrLocked
                                            ? Icons.lock_rounded
                                            : Icons.lock_open_rounded),
                                  size: 54,
                                  color: stateColor,
                                ),
                              const SizedBox(height: 12),
                              Text(
                                isTransitioning
                                    ? 'ACTUATING'
                                    : (!isOnline
                                          ? 'OFFLINE'
                                          : (isClosedOrLocked
                                                ? 'LOCKED'
                                                : 'UNLOCKED')),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: stateColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: stateColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isTransitioning
                                      ? 'Please wait...'
                                      : (!isOnline
                                            ? 'Unavailable'
                                            : (targetAction == DoorAction.open
                                                  ? 'TAP TO OPEN'
                                                  : 'TAP TO CLOSE')),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: stateColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Biometric Reminder Notice
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 15,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Requires phone biometric authentication',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Bottom Hardware Status Matrix (Clean 4-Cell Grid)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF334155),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoItem(
                                  icon: Icons.meeting_room_outlined,
                                  label: 'Door Strike',
                                  value: device.doorState == DoorState.open
                                      ? 'Open'
                                      : 'Closed',
                                  valueColor: device.doorState == DoorState.open
                                      ? AppTheme.statusUnlocked
                                      : AppTheme.statusOnline,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: const Color(0xFF334155),
                              ),
                              Expanded(
                                child: _buildInfoItem(
                                  icon: Icons.vpn_key_outlined,
                                  label: 'Latch Bolt',
                                  value: isLocked ? 'Secured' : 'Released',
                                  valueColor: isLocked
                                      ? AppTheme.statusLocked
                                      : AppTheme.statusUnlocked,
                                ),
                              ),
                            ],
                          ),
                          const Divider(
                            color: Color(0xFF334155),
                            height: 20,
                            thickness: 1,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoItem(
                                  icon: Icons.timer_outlined,
                                  label: 'Heartbeat',
                                  value: lastSeenStr,
                                  valueColor: Colors.white,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: const Color(0xFF334155),
                              ),
                              Expanded(
                                child: _buildInfoItem(
                                  icon: Icons.router_outlined,
                                  label: 'Node IP',
                                  value: device.ipAddress ?? '192.168.1.105',
                                  valueColor: const Color(0xFFCBD5E1),
                                  isMonospace: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    bool isMonospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: isMonospace ? 'monospace' : null,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
