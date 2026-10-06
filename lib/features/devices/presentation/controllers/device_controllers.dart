import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../domain/models/device.dart';
import '../../domain/repositories/device_repository.dart';

sealed class DeviceListState {
  const DeviceListState();
}

class DeviceListLoading extends DeviceListState {
  const DeviceListLoading();
}

class DeviceListLoaded extends DeviceListState {
  final List<Device> devices;
  const DeviceListLoaded(this.devices);
}

class DeviceListError extends DeviceListState {
  final String message;
  const DeviceListError(this.message);
}

class DeviceListNotifier extends Notifier<DeviceListState> {
  late final DeviceRepository _deviceRepository;

  @override
  DeviceListState build() {
    _deviceRepository = ref.watch(deviceRepositoryProvider);
    Future.microtask(() => loadDevices());
    return const DeviceListLoading();
  }

  Future<void> loadDevices() async {
    state = const DeviceListLoading();
    final result = await _deviceRepository.getRegisteredDevices();
    result.when(
      onSuccess: (devices) {
        state = DeviceListLoaded(devices);
      },
      onFailure: (failure) {
        state = DeviceListError(failure.message);
      },
    );
  }

  Future<void> refresh() async {
    final result = await _deviceRepository.getRegisteredDevices();
    result.when(
      onSuccess: (devices) {
        state = DeviceListLoaded(devices);
      },
      onFailure: (failure) {
        state = DeviceListError(failure.message);
      },
    );
  }
}

final deviceListProvider =
    NotifierProvider<DeviceListNotifier, DeviceListState>(
      DeviceListNotifier.new,
    );

final singleDeviceProvider = FutureProvider.family<Device, String>((
  ref,
  deviceId,
) async {
  final repo = ref.watch(deviceRepositoryProvider);
  final result = await repo.getDeviceById(deviceId);
  return result.when(
    onSuccess: (device) => device,
    onFailure: (f) => throw Exception(f.message),
  );
});
