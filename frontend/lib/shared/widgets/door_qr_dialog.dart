import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../features/devices/domain/models/device.dart';

class DoorQrDialog extends StatefulWidget {
  final Device device;

  const DoorQrDialog({super.key, required this.device});

  @override
  State<DoorQrDialog> createState() => _DoorQrDialogState();
}

class _DoorQrDialogState extends State<DoorQrDialog> {
  // Toggle between Web Redirect URL (compatible with stock cameras) and Direct Scheme
  bool _useCustomScheme = false;

  String get _webLink =>
      'https://securedoor-api.onrender.com/door?id=${widget.device.id}';
  String get _appScheme => 'securedoor://door?id=${widget.device.id}';

  String get activeLink => _useCustomScheme ? _appScheme : _webLink;

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
              widget.device.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${widget.device.id}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),

            // Format toggle
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _useCustomScheme = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_useCustomScheme
                              ? AppTheme.accentBlue.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: !_useCustomScheme
                              ? Border.all(color: AppTheme.accentBlue, width: 1.2)
                              : null,
                        ),
                        child: Text(
                          'Web Auto-Redirect',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: !_useCustomScheme
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: !_useCustomScheme
                                ? AppTheme.accentBlue
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _useCustomScheme = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _useCustomScheme
                              ? AppTheme.accentBlue.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: _useCustomScheme
                              ? Border.all(color: AppTheme.accentBlue, width: 1.2)
                              : null,
                        ),
                        child: Text(
                          'Direct App Scheme',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _useCustomScheme
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _useCustomScheme
                                ? AppTheme.accentBlue
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // QR Code Container
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
                data: activeLink,
                version: QrVersions.auto,
                size: 200.0,
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
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    size: 20,
                    color: AppTheme.accentBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _useCustomScheme
                          ? 'Encodes "securedoor://door?id=...". Opens immediately in supported QR scanners.'
                          : 'Encodes live Render redirect. Opens in browser, then immediately redirects to app.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
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
            Clipboard.setData(ClipboardData(text: activeLink));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Copied "$activeLink" to clipboard')),
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
