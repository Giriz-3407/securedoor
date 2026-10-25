import '../../../../core/utils/result.dart';
import '../models/access_request.dart';
import '../models/device.dart';

abstract class DeviceRepository {
  Future<Result<List<Device>>> getRegisteredDevices();
  Future<Result<Device>> getDeviceById(String deviceId);
  Future<Result<Device>> refreshDeviceStatus(String deviceId);
  Future<Result<Map<String, dynamic>>> requestDeviceAccess(String deviceId);
  Future<Result<List<AccessRequest>>> getAccessRequests();
  Future<Result<void>> reviewAccessRequest(String requestId, String action);
}
