import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../features/devices/domain/models/device.dart';

class DoorQrDialog extends StatelessWidget {
  final Device device;

  const DoorQrDialog({super.key, required this.device});

  String get deepLink => 'https://securedoor.app/door?id=${device.id}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.accentBlue),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Official Door QR Code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              device.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${device.id}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: deepLink,
                version: QrVersions.auto,
                size: 210.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppTheme.primaryBlue,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.camera_alt_outlined, size: 20, color: AppTheme.accentBlue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Scan with any phone camera, Google Lens, or QR scanner to open directly in the app.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy Link'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: deepLink));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Deep link copied to clipboard')),
            );
          },
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
