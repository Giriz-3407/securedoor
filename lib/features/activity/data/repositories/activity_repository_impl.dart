import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/networking/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/activity_log.dart';
import '../../domain/repositories/activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final ApiClient apiClient;

  ActivityRepositoryImpl({required this.apiClient});

  @override
  Future<Result<List<ActivityLog>>> getActivityLogs({String? deviceId}) async {
    try {
      final queryParams = deviceId != null ? {'deviceId': deviceId} : null;
      final response = await apiClient.get(
        '/activity-logs',
        queryParameters: queryParams,
      );

      final items = response['logs'] as List<dynamic>? ?? [];
      final logs = items
          .map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
          .toList();
      return Result.success(logs);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e, st) {
      AppLogger.error('Error fetching activity logs', e, st);
      return Result.failure(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> logActivity(ActivityLog log) async {
    try {
      await apiClient.post('/activity-logs', body: log.toJson());
      return Result.success(null);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e, st) {
      AppLogger.error('Error recording activity log', e, st);
      return Result.failure(UnexpectedFailure(e.toString()));
    }
  }
}
