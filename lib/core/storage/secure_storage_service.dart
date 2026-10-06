import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';

abstract class SecureStorageService {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> clearAll();
}

class FlutterSecureStorageServiceImpl implements SecureStorageService {
  final FlutterSecureStorage _storage;

  FlutterSecureStorageServiceImpl([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e, st) {
      AppLogger.error('SecureStorage write failed for key $key', e, st);
      rethrow;
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e, st) {
      AppLogger.error('SecureStorage read failed for key $key', e, st);
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e, st) {
      AppLogger.error('SecureStorage delete failed for key $key', e, st);
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      AppLogger.info('SecureStorage cleared all keys');
    } catch (e, st) {
      AppLogger.error('SecureStorage clearAll failed', e, st);
    }
  }
}

/// In-memory implementation of SecureStorageService for unit testing
class InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return _data[key];
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _data.clear();
  }
}
