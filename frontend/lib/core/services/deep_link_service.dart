import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../logging/app_logger.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Stream controller to notify UI of scanned door IDs
  final _doorScannedController = StreamController<String>.broadcast();
  Stream<String> get onDoorScanned => _doorScannedController.stream;

  String? pendingDoorId;

  void initialize(GlobalKey<NavigatorState> navigatorKey) async {
    // 1. Check if app was launched directly from a cold link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      AppLogger.warn('Failed to retrieve initial deep link: $e');
    }

    // 2. Listen for incoming links while the app is in background or foreground
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri),
      onError: (err) {
        AppLogger.warn('Deep link stream error: $err');
      },
    );
  }

  void _handleUri(Uri uri) {
    AppLogger.info('Deep link received: $uri');
    String? doorId;

    // Check query parameter: ?id=esp32_front_door_01
    if (uri.queryParameters.containsKey('id')) {
      doorId = uri.queryParameters['id'];
    } else if (uri.pathSegments.isNotEmpty) {
      // Check path: /door/esp32_front_door_01
      final lastSegment = uri.pathSegments.last;
      if (lastSegment != 'door') {
        doorId = lastSegment;
      }
    }

    if (doorId != null && doorId.isNotEmpty) {
      AppLogger.info('Extracted Door ID from QR / Deep Link: $doorId');
      pendingDoorId = doorId;
      _doorScannedController.add(doorId);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _doorScannedController.close();
  }
}
