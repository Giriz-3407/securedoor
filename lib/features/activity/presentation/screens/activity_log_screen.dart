import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/mock_banner.dart';
import '../controllers/activity_controller.dart';
import '../../domain/models/activity_log.dart';

class ActivityLogScreen extends ConsumerStatefulWidget {
  final String? targetDeviceId;

  const ActivityLogScreen({super.key, this.targetDeviceId});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(activityListProvider.notifier)
          .loadLogs(deviceId: widget.targetDeviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activityState = ref.watch(activityListProvider);
    final config = ref.watch(configProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.targetDeviceId != null
              ? 'Device Audit Trail'
              : 'Security Activity Log',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Log',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(activityListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (config.isMockMode) const MockBanner(),
            Expanded(
              child: switch (activityState) {
                ActivityListLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                ActivityListError(message: final msg) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: AppTheme.statusOffline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          msg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                ActivityListLoaded(logs: final logs) => RefreshIndicator(
                  onRefresh: () =>
                      ref.read(activityListProvider.notifier).refresh(),
                  child: logs.isEmpty
                      ? const Center(
                          child: Text(
                            'No activity recorded yet.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          itemCount: logs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return _ActivityLogCard(log: log);
                          },
                        ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityLogCard extends StatelessWidget {
  final ActivityLog log;

  const _ActivityLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm:ss a • MMM d').format(log.timestamp);

    final (statusColor, statusIcon, statusText) = switch (log.status) {
      OperationStatus.success => (
        AppTheme.statusOnline,
        Icons.check_circle_outline_rounded,
        '✓ Successful',
      ),
      OperationStatus.unauthorized => (
        AppTheme.statusOffline,
        Icons.lock_person_outlined,
        '✗ Unauthorized',
      ),
      OperationStatus.timedOut => (
        AppTheme.statusUnlocked,
        Icons.timer_off_outlined,
        '✗ Timed Out',
      ),
      OperationStatus.offline => (
        AppTheme.statusOffline,
        Icons.wifi_off_rounded,
        '✗ Node Offline',
      ),
      OperationStatus.failed => (
        AppTheme.statusOffline,
        Icons.cancel_outlined,
        '✗ Failed',
      ),
    };

    final opColor = switch (log.operation) {
      OperationType.open => AppTheme.statusUnlocked,
      OperationType.close => AppTheme.statusLocked,
      _ => AppTheme.textPrimary,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: opColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: opColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    log.operation.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: opColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              log.deviceName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.fingerprint_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    log.authMethod,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (log.failureReason != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.statusOffline.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Reason: ${log.failureReason!}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.statusOffline,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Req: ${log.requestId.length > 12 ? log.requestId.substring(0, 12) : log.requestId}...',
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
