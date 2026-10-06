import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../domain/models/activity_log.dart';
import '../../domain/repositories/activity_repository.dart';

sealed class ActivityListState {
  const ActivityListState();
}

class ActivityListLoading extends ActivityListState {
  const ActivityListLoading();
}

class ActivityListLoaded extends ActivityListState {
  final List<ActivityLog> logs;
  const ActivityListLoaded(this.logs);
}

class ActivityListError extends ActivityListState {
  final String message;
  const ActivityListError(this.message);
}

class ActivityNotifier extends Notifier<ActivityListState> {
  late final ActivityRepository _repository;
  String? _filterDeviceId;

  @override
  ActivityListState build() {
    _repository = ref.watch(activityRepositoryProvider);
    Future.microtask(() => loadLogs());
    return const ActivityListLoading();
  }

  Future<void> loadLogs({String? deviceId}) async {
    _filterDeviceId = deviceId;
    state = const ActivityListLoading();
    final result = await _repository.getActivityLogs(deviceId: deviceId);
    result.when(
      onSuccess: (logs) {
        state = ActivityListLoaded(logs);
      },
      onFailure: (failure) {
        state = ActivityListError(failure.message);
      },
    );
  }

  Future<void> refresh() async {
    final result = await _repository.getActivityLogs(deviceId: _filterDeviceId);
    result.when(
      onSuccess: (logs) {
        state = ActivityListLoaded(logs);
      },
      onFailure: (failure) {
        state = ActivityListError(failure.message);
      },
    );
  }
}

final activityListProvider =
    NotifierProvider<ActivityNotifier, ActivityListState>(ActivityNotifier.new);
