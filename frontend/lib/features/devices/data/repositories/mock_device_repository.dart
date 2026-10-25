import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/access_request.dart';
import '../../domain/models/device.dart';
import '../../domain/repositories/device_repository.dart';

class MockDeviceRepository implements DeviceRepository {
  // In-memory state for demonstration
  final List<Device> _devices = [
    Device(
      id: 'esp32_lab_door_01',
      name: 'LAB DOOR 01',
      description: 'IoE Embedded Systems Laboratory Entrance',
      connectivity: DeviceConnectivity.online,
      doorState: DoorState.closed,
      latchState: LatchState.locked,
      lastSeen: DateTime.now().subtract(const Duration(seconds: 12)),
      permissions: const UserDevicePermission(
        canOpen: true,
        canClose: true,
        isOwner: true,
      ),
      ipAddress: '192.168.1.105',
      hardwareFirmwareVersion: 'ESP32-IoE-v2.4.1',
    ),
    Device(
      id: 'esp32_research_lab_02',
      name: 'RESEARCH LAB 02',
      description: 'Robotics & Automation Research Lab',
      connectivity: DeviceConnectivity.online,
      doorState: DoorState.open,
      latchState: LatchState.unlocked,
      lastSeen: DateTime.now().subtract(const Duration(seconds: 45)),
      permissions: const UserDevicePermission(
        canOpen: true,
        canClose: true,
        isOwner: false,
      ),
      ipAddress: '192.168.1.108',
      hardwareFirmwareVersion: 'ESP32-IoE-v2.4.1',
    ),
    Device(
      id: 'esp32_server_room_03',
      name: 'SERVER ROOM ACCESS',
      description: 'Departmental Infrastructure Server Room',
      connectivity: DeviceConnectivity.offline, // Offline demo!
      doorState: DoorState.closed,
      latchState: LatchState.locked,
      lastSeen: DateTime.now().subtract(const Duration(hours: 4)),
      permissions: const UserDevicePermission(
        canOpen: true,
        canClose: true,
        isOwner: false,
      ),
      ipAddress: '192.168.1.110',
      hardwareFirmwareVersion: 'ESP32-IoE-v2.3.9',
    ),
    Device(
      id: 'esp32_restricted_archive_04',
      name: 'RESTRICTED ARCHIVE',
      description: 'Exam Paper & Confidential Records Vault',
      connectivity: DeviceConnectivity.online,
      doorState: DoorState.closed,
      latchState: LatchState.locked,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
      permissions: const UserDevicePermission(
        canOpen: false,
        canClose: false,
        isOwner: false,
      ), // Unauthorized demo!
      ipAddress: '192.168.1.115',
      hardwareFirmwareVersion: 'ESP32-IoE-v2.4.1',
    ),
  ];

  @override
  Future<Result<List<Device>>> getRegisteredDevices() async {
    AppLogger.info('MockDeviceRepository: fetching registered devices');
    await Future.delayed(const Duration(milliseconds: 350));
    return Result.success(List.unmodifiable(_devices));
  }

  @override
  Future<Result<Device>> getDeviceById(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final device = _devices.where((d) => d.id == deviceId).firstOrNull;
    if (device == null) {
      return Result.failure(const UnexpectedFailure('Device not found.'));
    }
    return Result.success(device);
  }

  @override
  Future<Result<Device>> refreshDeviceStatus(String deviceId) async {
    return getDeviceById(deviceId);
  }

  /// Internal mock update method called by AccessControlRepository to simulate state change
  void updateDeviceState(
    String deviceId, {
    DoorState? doorState,
    LatchState? latchState,
  }) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final current = _devices[index];
      _devices[index] = current.copyWith(
        doorState: doorState ?? current.doorState,
        latchState: latchState ?? current.latchState,
        lastSeen: DateTime.now(),
      );
      AppLogger.info(
        'MockDeviceRepository: updated device $deviceId doorState=$doorState, latchState=$latchState',
      );
    }
  }

  final List<AccessRequest> _requests = [];

  @override
  Future<Result<Map<String, dynamic>>> requestDeviceAccess(String deviceId) async {
    final newReq = AccessRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'usr_mock_student',
      userEmail: 'student@example.com',
      userName: 'Student User',
      deviceId: deviceId,
      deviceName: 'Door $deviceId',
      status: 'pending',
      requestedAt: DateTime.now(),
    );
    _requests.add(newReq);
    return Result.success({'status': 'pending', 'message': 'Request submitted to Admin'});
  }

  @override
  Future<Result<List<AccessRequest>>> getAccessRequests() async {
    return Result.success(List.from(_requests));
  }

  @override
  Future<Result<void>> reviewAccessRequest(String requestId, String action) async {
    final idx = _requests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final req = _requests[idx];
      _requests[idx] = AccessRequest(
        id: req.id,
        userId: req.userId,
        userEmail: req.userEmail,
        userName: req.userName,
        deviceId: req.deviceId,
        deviceName: req.deviceName,
        status: action == 'accept' ? 'accepted' : 'rejected',
        requestedAt: req.requestedAt,
      );
    }
    return Result.success(null);
  }
}
