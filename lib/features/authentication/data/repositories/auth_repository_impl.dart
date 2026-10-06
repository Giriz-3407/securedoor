import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/networking/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient apiClient;
  final SecureStorageService storage;

  AuthRepositoryImpl({required this.apiClient, required this.storage});

  @override
  Future<Result<User>> login(LoginCredentials credentials) async {
    try {
      final response = await apiClient.post(
        '/auth/login',
        body: {
          'email': credentials.email.trim(),
          'password': credentials.password,
        },
        requiresAuth: false,
      );

      final token = response['accessToken'] as String?;
      final refreshToken = response['refreshToken'] as String?;
      final userData = response['user'] as Map<String, dynamic>?;

      if (token == null || userData == null) {
        return Result.failure(
          const AuthFailure('Malformed authentication response from server.'),
        );
      }

      await storage.write(AppConstants.keyAccessToken, token);
      if (refreshToken != null) {
        await storage.write(AppConstants.keyRefreshToken, refreshToken);
      }

      final user = User.fromJson(userData);
      await storage.write(AppConstants.keyUserId, user.id);
      await storage.write(AppConstants.keyUserEmail, user.email);

      AppLogger.info('User successfully authenticated via API');
      return Result.success(user);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e, st) {
      AppLogger.error('Login error', e, st);
      return Result.failure(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<User?>> getCurrentUser() async {
    try {
      final token = await storage.read(AppConstants.keyAccessToken);
      if (token == null) {
        return Result.success(null);
      }

      final response = await apiClient.get('/auth/me');
      final userData = response['user'] as Map<String, dynamic>?;
      if (userData == null) {
        return Result.success(null);
      }
      return Result.success(User.fromJson(userData));
    } on AuthFailure {
      await storage.clearAll();
      return Result.success(null);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e, st) {
      AppLogger.error('Failed to get current user', e, st);
      return Result.failure(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      try {
        await apiClient.post('/auth/logout');
      } catch (_) {
        // Even if server call fails, purge local tokens
      }
      await storage.clearAll();
      AppLogger.info('Logged out and cleared secure tokens');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.error('Error during logout', e, st);
      await storage.clearAll();
      return Result.success(null);
    }
  }

  @override
  Future<bool> hasValidSession() async {
    final token = await storage.read(AppConstants.keyAccessToken);
    return token != null && token.isNotEmpty;
  }
}
