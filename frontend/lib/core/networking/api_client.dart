import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../errors/failures.dart';
import '../logging/app_logger.dart';
import '../storage/secure_storage_service.dart';

abstract class ApiClient {
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    bool requiresAuth = true,
  });

  Future<Map<String, dynamic>> post(
    String path, {
    dynamic body,
    bool requiresAuth = true,
  });
}

class HttpApiClient implements ApiClient {
  final http.Client _client;
  final SecureStorageService secureStorage;
  final AppConfig config;
  final _uuid = const Uuid();

  HttpApiClient({
    required this.secureStorage,
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final base = config.apiBaseUrl.endsWith('/')
        ? config.apiBaseUrl
        : '${config.apiBaseUrl}/';
    final fullUrl = '$base$cleanPath';
    final uri = Uri.parse(fullUrl);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(queryParameters: queryParameters);
    }
    return uri;
  }

  Future<Map<String, String>> _buildHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Request-Id': _uuid.v4(),
      'X-Client-Platform': 'Flutter-Mobile',
    };

    if (requiresAuth) {
      final token = await secureStorage.read(AppConstants.keyAccessToken);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final userId = await secureStorage.read(AppConstants.keyUserId);
      if (userId != null && userId.isNotEmpty) {
        headers['X-User-Id'] = userId;
      }
      final userEmail = await secureStorage.read(AppConstants.keyUserEmail);
      if (userEmail != null && userEmail.isNotEmpty) {
        headers['X-User-Email'] = userEmail;
      }
    }

    return headers;
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final headers = await _buildHeaders(requiresAuth: requiresAuth);

      AppLogger.info('HTTP GET ${uri.path}');

      final response = await _client
          .get(uri, headers: headers)
          .timeout(config.requestTimeout);

      return _processResponse(response);
    } on SocketException catch (e, st) {
      AppLogger.error('Network unreachable for GET $path', e, st);
      throw const NetworkFailure(
        'Unable to reach server. Check your Wi-Fi or Internet.',
      );
    } on TimeoutException catch (e, st) {
      AppLogger.error('Request timed out for GET $path', e, st);
      throw const NetworkFailure('Request timed out while contacting server.');
    } on Failure {
      rethrow;
    } catch (e, st) {
      AppLogger.error('Unexpected error in GET $path', e, st);
      throw UnexpectedFailure(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = _buildUri(path);
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final encodedBody = body != null ? jsonEncode(body) : null;

      AppLogger.info('HTTP POST ${uri.path}');

      final response = await _client
          .post(uri, headers: headers, body: encodedBody)
          .timeout(config.requestTimeout);

      return _processResponse(response);
    } on SocketException catch (e, st) {
      AppLogger.error('Network unreachable for POST $path', e, st);
      throw const NetworkFailure(
        'Unable to reach server. Check your Wi-Fi or Internet.',
      );
    } on TimeoutException catch (e, st) {
      AppLogger.error('Request timed out for POST $path', e, st);
      throw const CommandTimeoutFailure(
        'Request timed out before server response.',
      );
    } on Failure {
      rethrow;
    } catch (e, st) {
      AppLogger.error('Unexpected error in POST $path', e, st);
      throw UnexpectedFailure(e.toString());
    }
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    AppLogger.info('HTTP Response status: ${response.statusCode}');

    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        // If not JSON, leave as empty map
      }
    }

    final message = body['message'] as String?;

    switch (response.statusCode) {
      case 200:
      case 201:
      case 202:
        return body;
      case 401:
        throw AuthFailure(
          message ?? 'Authentication required or session expired.',
        );
      case 403:
        throw UnauthorizedFailure(
          message ?? 'You are not authorized to control this device.',
        );
      case 409:
        throw DuplicateCommandFailure(
          message ?? 'A command is already active for this device.',
        );
      case 503:
      case 504:
        throw DeviceOfflineFailure(
          message ?? 'Device is currently offline or unreachable.',
        );
      default:
        throw UnexpectedFailure(
          message ?? 'Server error (${response.statusCode}).',
        );
    }
  }
}
