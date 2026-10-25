import '../../../../core/utils/result.dart';
import '../models/activity_log.dart';

abstract class ActivityRepository {
  Future<Result<List<ActivityLog>>> getActivityLogs({String? deviceId});
  Future<Result<void>> logActivity(ActivityLog log);
}
