import 'package:flutter_test/flutter_test.dart';
import 'package:secure_door_access/core/errors/failures.dart';
import 'package:secure_door_access/features/access_control/data/repositories/mock_access_control_repository.dart';
import 'package:secure_door_access/features/access_control/domain/models/door_command.dart';
import 'package:secure_door_access/features/activity/data/repositories/mock_activity_repository.dart';
import 'package:secure_door_access/features/devices/data/repositories/mock_device_repository.dart';
import 'package:secure_door_access/features/devices/domain/models/device.dart';

void main() {
  group('Remote Command & Access Control Security Tests', () {
    late MockDeviceRepository deviceRepo;
    late MockActivityRepository activityRepo;
    late MockAccessControlRepository accessControlRepo;

    setUp(() {
      deviceRepo = MockDeviceRepository();
      activityRepo = MockActivityRepository();
      accessControlRepo = MockAccessControlRepository(
        deviceRepository: deviceRepo,
        activityRepository: activityRepo,
      );
    });

    test('Command payload contains required security fields (requestId, timestamp, context)', () {
      final payload = DoorCommandPayload(
        deviceId: 'esp32_lab_door_01',
        action: DoorAction.open,
      );

      final json = payload.toJson();
      expect(json['deviceId'], equals('esp32_lab_door_01'));
      expect(json['command'], equals('OPEN'));
      expect(json['requestId'], isNotEmpty);
      expect(json['timestamp'], isNotEmpty);
      expect(json['authenticationContext'], equals('biometric_os'));
    });

    test(
      'Offline device rejects command without attempting hardware actuation',
      () async {
        final recordedStages = <CommandExecutionStage>[];

        // esp32_server_room_03 is configured offline in mock repository
        final command = DoorCommandPayload(
          deviceId: 'esp32_server_room_03',
          action: DoorAction.open,
        );

        final result = await accessControlRepo.executeCommand(
          command,
          onStageChanged: (stage) => recordedStages.add(stage),
        );

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<DeviceOfflineFailure>());
        expect(recordedStages, contains(CommandExecutionStage.deviceOffline));
        expect(
          recordedStages,
          isNot(contains(CommandExecutionStage.physicalStateConfirmed)),
        );

        // Verify activity was logged as offline
        final logsResult = await activityRepo.getActivityLogs(
          deviceId: 'esp32_server_room_03',
        );
        expect(logsResult.isSuccess, isTrue);
        final logs = logsResult.dataOrNull!;
        expect(logs.any((l) => l.requestId == command.requestId), isTrue);
      },
    );

    test(
      'Unauthorized device access is rejected by access control layer',
      () async {
        final recordedStages = <CommandExecutionStage>[];

        // esp32_restricted_archive_04 has canOpen: false, canClose: false
        final command = DoorCommandPayload(
          deviceId: 'esp32_restricted_archive_04',
          action: DoorAction.open,
        );

        final result = await accessControlRepo.executeCommand(
          command,
          onStageChanged: (stage) => recordedStages.add(stage),
        );

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnauthorizedFailure>());
        expect(recordedStages, contains(CommandExecutionStage.unauthorized));

        // Target physical latch state must remain locked
        final device = (await deviceRepo.getDeviceById(
          'esp32_restricted_archive_04',
        )).dataOrNull!;
        expect(device.latchState, equals(LatchState.locked));
      },
    );

    test('Successful OPEN traverses full stage lifecycle and confirms physical latch state', () async {
      final recordedStages = <CommandExecutionStage>[];

      final command = DoorCommandPayload(
        deviceId: 'esp32_lab_door_01',
        action: DoorAction.open,
      );

      final result = await accessControlRepo.executeCommand(
        command,
        onStageChanged: (stage) => recordedStages.add(stage),
      );

      expect(result.isSuccess, isTrue);
      final execResult = result.dataOrNull!;
      expect(execResult.isSuccess, isTrue);
      expect(
        execResult.finalStage,
        equals(CommandExecutionStage.physicalStateConfirmed),
      );

      // Verify stage order: sending -> acknowledged -> responding -> confirmed
      expect(
        recordedStages,
        equals([
          CommandExecutionStage.sendingCommand,
          CommandExecutionStage.commandAcknowledged,
          CommandExecutionStage.deviceResponding,
          CommandExecutionStage.physicalStateConfirmed,
        ]),
      );

      // Verify physical device state was updated to open & unlocked
      final device = (await deviceRepo.getDeviceById('esp32_lab_door_01'))
          .dataOrNull!;
      expect(device.doorState, equals(DoorState.open));
      expect(device.latchState, equals(LatchState.unlocked));
    });

    test('Successful CLOSE traverses full stage lifecycle and confirms physical latch lock', () async {
      final recordedStages = <CommandExecutionStage>[];

      // RESEARCH LAB 02 starts in open & unlocked state
      final command = DoorCommandPayload(
        deviceId: 'esp32_research_lab_02',
        action: DoorAction.close,
      );

      final result = await accessControlRepo.executeCommand(
        command,
        onStageChanged: (stage) => recordedStages.add(stage),
      );

      expect(result.isSuccess, isTrue);
      expect(
        recordedStages,
        contains(CommandExecutionStage.physicalStateConfirmed),
      );

      // Verify physical state is now closed & locked
      final device = (await deviceRepo.getDeviceById('esp32_research_lab_02'))
          .dataOrNull!;
      expect(device.doorState, equals(DoorState.closed));
      expect(device.latchState, equals(LatchState.locked));
    });

    test(
      'Each command generates unique requestId for replay attack protection',
      () {
        final cmd1 = DoorCommandPayload(
          deviceId: 'esp32_lab_door_01',
          action: DoorAction.open,
        );
        final cmd2 = DoorCommandPayload(
          deviceId: 'esp32_lab_door_01',
          action: DoorAction.open,
        );

        expect(cmd1.requestId, isNot(equals(cmd2.requestId)));
      },
    );
  });
}
