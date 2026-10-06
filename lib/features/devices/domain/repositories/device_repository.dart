import '../../../../core/utils/result.dart';
import '../models/device.dart';

abstract class DeviceRepository {
  Future<Result<List<Device>>> getRegisteredDevices();
  Future<Result<Device>> getDeviceById(String deviceId);
  Future<Result<Device>> refreshDeviceStatus(String deviceId);
}
