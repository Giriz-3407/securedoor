import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/mock_banner.dart';
import '../../../activity/presentation/screens/activity_log_screen.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../controllers/device_controllers.dart';
import '../../domain/models/device.dart';
import 'device_detail_screen.dart';

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(deviceListProvider);
    final authState = ref.watch(authStateProvider);
    final config = ref.watch(configProvider);

    final currentUser = (authState is Authenticated) ? authState.user : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registered Perimeters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (currentUser != null)
              Text(
                '${currentUser.fullName} (${currentUser.role})',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Activity Audit Log',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ActivityLogScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Secure Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surfaceColor,
                  title: const Text('Confirm Secure Logout'),
                  content: const Text(
                    'This will invalidate your session tokens and wipe local credentials.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.statusOffline,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                ref.read(authStateProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (config.isMockMode) const MockBanner(),
            Expanded(
              child: switch (deviceState) {
                DeviceListLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                DeviceListError(message: final msg) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: AppTheme.statusOffline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            msg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry Connection'),
                            onPressed: () => ref
                                .read(deviceListProvider.notifier)
                                .loadDevices(),
                          ),
                        ],
                      ),
                    ),
                  ),
                DeviceListLoaded(devices: final devices) => RefreshIndicator(
                    onRefresh: () =>
                        ref.read(deviceListProvider.notifier).refresh(),
                    child: devices.isEmpty
                        ? const Center(
                            child: Text('No devices registered to your account.'),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1.1,
                            ),
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              final device = devices[index];
                              return _DeviceGridTile(
                                device: device,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => DeviceDetailScreen(
                                        initialDevice: device,
                                      ),
                                    ),
                                  );
                                },
                              );
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

class _DeviceGridTile extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const _DeviceGridTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOnline = device.isOnline;
    final isLocked = device.isLocked;

    final Color statusColor = !isOnline
        ? AppTheme.statusOffline
        : (isLocked ? AppTheme.statusLocked : AppTheme.statusUnlocked);

    final String statusText = !isOnline
        ? 'Offline'
        : (isLocked ? 'Locked' : 'Unlocked');

    final IconData statusIcon = !isOnline
        ? Icons.wifi_off_rounded
        : (isLocked ? Icons.lock_rounded : Icons.lock_open_rounded);

    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withValues(alpha: isOnline ? 0.35 : 0.2),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: Icon & Status indicator dot
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? AppTheme.statusOnline
                          : AppTheme.statusOffline,
                      shape: BoxShape.circle,
                      boxShadow: isOnline
                          ? [
                              BoxShadow(
                                color: AppTheme.statusOnline
                                    .withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ]
                          : [],
                    ),
                  ),
                ],
              ),

              // Bottom details: Device Name & Simple Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
