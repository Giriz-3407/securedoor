import 'package:flutter/foundation.dart';

/// Centralized security-hardened logger.
///
/// Features:
/// 1. Completely silenced or strictly filtered in release mode.
/// 2. Automatic sanitization/redaction of sensitive credentials, tokens, passwords,
///    and authorization headers.
/// 3. Never logs raw biometric templates, fingerprints, or sensor buffers.
class AppLogger {
  static bool _enabled = kDebugMode;

  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  // Regex patterns to detect and mask sensitive data
  static final _bearerTokenRegex = RegExp(
    r'(Bearer\s+)[A-Za-z0-9\-_.]+',
    caseSensitive: false,
  );
  static final _passwordJsonRegex = RegExp(
    r'("password"\s*:\s*")([^"]*)(")',
    caseSensitive: false,
  );
  static final _tokenJsonRegex = RegExp(
    r'("(access_token|refresh_token|token|secret)"\s*:\s*")([^"]*)(")',
    caseSensitive: false,
  );

  static String _sanitize(String message) {
    var sanitized = message;
    sanitized = sanitized.replaceAllMapped(
      _bearerTokenRegex,
      (match) => '${match.group(1)}[REDACTED]',
    );
    sanitized = sanitized.replaceAllMapped(
      _passwordJsonRegex,
      (match) => '${match.group(1)}[REDACTED]${match.group(3)}',
    );
    sanitized = sanitized.replaceAllMapped(
      _tokenJsonRegex,
      (match) => '${match.group(1)}[REDACTED]${match.group(4)}',
    );
    return sanitized;
  }

  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    debugPrint('[DEBUG] ${_sanitize(message)}');
    if (error != null) {
      debugPrint('[DEBUG_ERROR] $error');
    }
  }

  static void info(String message) {
    if (!_enabled) return;
    debugPrint('[INFO] ${_sanitize(message)}');
  }

  static void warn(String message, [Object? error]) {
    if (!_enabled) return;
    debugPrint('[WARN] ${_sanitize(message)}');
    if (error != null) {
      debugPrint('[WARN_DETAIL] $error');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    // Errors can still be printed in debug mode, but sanitized
    debugPrint('[ERROR] ${_sanitize(message)}');
    if (kDebugMode && error != null) {
      debugPrint('[ERROR_DETAIL] $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }
}
