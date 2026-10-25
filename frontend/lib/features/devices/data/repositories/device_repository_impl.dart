import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/networking/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/access_request.dart';
import '../../domain/models/device.dart';
import '../../domain/repositories/device_repository.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  final ApiClient apiClient;

  DeviceRepositoryImpl({required this.apiClient});

  @override
  Future<Result<List<Device>>> getRegisteredDevices() async {
    try {
      final response = await apiClient.get('/devices');
      final items = response['devices'] as List<dynamic>? ?? [];
      final devices = items
          .map((e) => Device.fromJson(e as Map<String, dynamic>))
          .toList();
      return Result.success(devices);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e, st) {
      AppLogger.error('Error fetching registered devices', e, st);
      return Result.failure(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<Device>> getDeviceById(String deviceId) async {
    try {
      final response = await apiClient.get('/devices/$deviceId');
      final deviceData = response['device'] as Map<String, dynamic>?;
      if (deviceData == null) {
        return Result.failure(
          const UnexpectedFailure('Device not found on server.'),
        );
      }
      return Result.success(Device.fromJson(deviceData));
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e, st) {
      AppLogger.error('Error fetching device $deviceId', e, st);
      return Result.failure(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<Device>> refreshDeviceStatus(String deviceId) async {
    return getDeviceById(deviceId);
  }

  @override
  Future<Result<Map<String, dynamic>>> requestDeviceAccess(String deviceId) async {
    try {
      final response = await apiClient.post(
        '/devices/request-access',
        body: {'deviceId': deviceId},
      );
      return Result.success(response);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e, st) {
      AppLogger.error('Error requesting access for device $deviceId', e, st);
      return Result.failure(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<AccessRequest>>> getAccessRequests() async {
    try {
      final response = await apiClient.get('/access-requests');
      final items = response['requests'] as List<dynamic>? ?? [];
      final requests = items
          .map((e) => AccessRequest.fromJson(e as Map<String, dynamic>))
          .toList();
      return Result.success(requests);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e, st) {
      AppLogger.error('Error fetching access requests', e, st);
      return Result.failure(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> reviewAccessRequest(String requestId, String action) async {
    try {
      await apiClient.post(
        '/access-requests/$requestId/review',
        body: {'action': action},
      );
      return Result.success(null);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e, st) {
      AppLogger.error('Error reviewing access request $requestId', e, st);
      return Result.failure(UnexpectedFailure(e.toString()));
    }
  }
}
