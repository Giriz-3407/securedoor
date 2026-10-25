import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/mock_banner.dart';
import '../../../activity/presentation/screens/activity_log_screen.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../controllers/device_controllers.dart';
import '../../domain/models/device.dart';
import 'admin_requests_screen.dart';
import 'device_detail_screen.dart';

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  void _showRequestAccessDialog(BuildContext context, WidgetRef ref) {
    final doorIdController = TextEditingController(text: 'esp32_front_door_01');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_moderator_rounded, color: AppTheme.accentBlue),
            SizedBox(width: 10),
            Text('Request Door Access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the physical Door / Device ID you want permission to access. The Admin will review and approve your request.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: doorIdController,
              decoration: const InputDecoration(
                labelText: 'Target Door Device ID',
                hintText: 'e.g. esp32_front_door_01',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final deviceId = doorIdController.text.trim();
              if (deviceId.isEmpty) return;
              Navigator.of(ctx).pop();

              final repo = ref.read(deviceRepositoryProvider);
              final result = await repo.requestDeviceAccess(deviceId);

              result.when(
                onSuccess: (data) {
                  final msg = data['message'] as String? ?? 'Request submitted for Admin approval';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.accentBlue,
                      duration: const Duration(seconds: 4),
                      content: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(child: Text(msg)),
                        ],
                      ),
                    ),
                  );
                  ref.read(deviceListProvider.notifier).refresh();
                },
                onFailure: (failure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.statusOffline,
                      content: Text(failure.message),
                    ),
                  );
                },
              );
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(deviceListProvider);
    final authState = ref.watch(authStateProvider);
    final config = ref.watch(configProvider);

    final currentUser = (authState is Authenticated) ? authState.user : null;
    final isAdmin = currentUser?.role.toLowerCase() == 'admin';

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
                '${currentUser.fullName} (${currentUser.role.toUpperCase()})',
                style: TextStyle(
                  fontSize: 11,
                  color: isAdmin ? AppTheme.accentBlue : AppTheme.textSecondary,
                  fontWeight: isAdmin ? FontWeight.bold : FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Review Access Requests',
              icon: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.accentBlue),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminRequestsScreen()),
                );
              },
            ),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentBlue,
        icon: const Icon(Icons.add_moderator_rounded, color: Colors.white),
        label: const Text('Request Door Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showRequestAccessDialog(context, ref),
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
                            style: const TextStyle(color: AppTheme.textSecondary),
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
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock_person_outlined, size: 64, color: AppTheme.textSecondary),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Doors Assigned Yet',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'You must request access from the Admin to unlock perimeters.\nTap the button below to submit a request for a door.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add_moderator_rounded),
                                    label: const Text('Request Door Access'),
                                    onPressed: () => _showRequestAccessDialog(context, ref),
                                  ),
                                ],
                              ),
                            ),
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? AppTheme.statusOnline.withValues(alpha: 0.15)
                          : AppTheme.statusOffline.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isOnline
                            ? AppTheme.statusOnline
                            : AppTheme.statusOffline,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
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
