import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/networking/api_client.dart';
import '../../../../core/utils/result.dart';
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
}
