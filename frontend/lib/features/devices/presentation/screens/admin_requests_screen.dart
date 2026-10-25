import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/access_request.dart';
import '../controllers/device_controllers.dart';

class AdminRequestsScreen extends ConsumerStatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  ConsumerState<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends ConsumerState<AdminRequestsScreen> {
  bool _isLoading = true;
  List<AccessRequest> _requests = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = ref.read(deviceRepositoryProvider);
    final result = await repo.getAccessRequests();

    result.when(
      onSuccess: (data) {
        setState(() {
          _requests = data;
          _isLoading = false;
        });
      },
      onFailure: (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _handleReview(AccessRequest request, String action) async {
    final repo = ref.read(deviceRepositoryProvider);
    final result = await repo.reviewAccessRequest(request.id, action);

    result.when(
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: action == 'accept' ? AppTheme.statusUnlocked : AppTheme.statusOffline,
            content: Text(
              action == 'accept'
                  ? 'Access granted to ${request.userName} for ${request.deviceName}.'
                  : 'Access rejected for ${request.userEmail}.',
            ),
          ),
        );
        _fetchRequests();
        // Also refresh devices list in background
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Approval Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Requests',
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.statusOffline, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchRequests, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, color: AppTheme.statusOnline, size: 56),
            SizedBox(height: 16),
            Text(
              'No Access Requests Pending',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            SizedBox(height: 6),
            Text(
              'When other users request access to doors,\nthey will appear here for your approval.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = _requests[index];
        return _buildRequestCard(req);
      },
    );
  }

  Widget _buildRequestCard(AccessRequest req) {
    final isPending = req.isPending;

    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPending ? AppTheme.accentBlue.withValues(alpha: 0.4) : AppTheme.borderColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isPending
                      ? AppTheme.accentBlue.withValues(alpha: 0.2)
                      : (req.isAccepted ? AppTheme.statusOnline.withValues(alpha: 0.2) : AppTheme.statusOffline.withValues(alpha: 0.2)),
                  child: Icon(
                    isPending ? Icons.person_add_rounded : (req.isAccepted ? Icons.check : Icons.close),
                    color: isPending
                        ? AppTheme.accentBlue
                        : (req.isAccepted ? AppTheme.statusOnline : AppTheme.statusOffline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.userName.isNotEmpty ? req.userName : req.userEmail,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                      ),
                      Text(
                        req.userEmail,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                _buildStatusPill(req.status),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.meeting_room_outlined, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Door: ${req.deviceName} (${req.deviceId})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.statusOffline,
                        side: const BorderSide(color: AppTheme.statusOffline),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                      onPressed: () => _handleReview(req, 'reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.statusOnline,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Accept & Grant'),
                      onPressed: () => _handleReview(req, 'accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'accepted':
        bg = AppTheme.statusOnline.withValues(alpha: 0.15);
        fg = AppTheme.statusOnline;
        label = 'APPROVED';
        break;
      case 'rejected':
        bg = AppTheme.statusOffline.withValues(alpha: 0.15);
        fg = AppTheme.statusOffline;
        label = 'REJECTED';
        break;
      default:
        bg = AppTheme.accentBlue.withValues(alpha: 0.15);
        fg = AppTheme.accentBlue;
        label = 'PENDING';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
