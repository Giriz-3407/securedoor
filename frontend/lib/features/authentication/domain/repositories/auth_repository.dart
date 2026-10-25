import '../../../../core/utils/result.dart';
import '../models/user.dart';

abstract class AuthRepository {
  Future<Result<User>> login(LoginCredentials credentials);
  Future<Result<User?>> getCurrentUser();
  Future<Result<void>> logout();
  Future<bool> hasValidSession();
}
