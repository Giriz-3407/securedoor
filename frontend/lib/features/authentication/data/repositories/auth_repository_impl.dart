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
      await storage.write(AppConstants.keyUserName, user.fullName);
      await storage.write(AppConstants.keyUserRole, user.role);

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
      if (token == null || token.isEmpty) {
        return Result.success(null);
      }

      // Check if we have cached user info locally
      final userId = await storage.read(AppConstants.keyUserId);
      final userEmail = await storage.read(AppConstants.keyUserEmail);
      final userName = await storage.read(AppConstants.keyUserName);
      final userRole = await storage.read(AppConstants.keyUserRole);

      User? localUser;
      if (userId != null && userEmail != null) {
        localUser = User(
          id: userId,
          email: userEmail,
          fullName: userName ?? userEmail.split('@')[0],
          role: userRole ?? (userEmail.toLowerCase() == 'admin@college.edu' ? 'admin' : 'user'),
          createdAt: DateTime.now(),
        );
      }

      // Verify or refresh session from backend if reachable
      try {
        final response = await apiClient.get('/auth/me');
        final userData = response['user'] as Map<String, dynamic>?;
        if (userData != null) {
          final serverUser = User.fromJson(userData);
          await storage.write(AppConstants.keyUserId, serverUser.id);
          await storage.write(AppConstants.keyUserEmail, serverUser.email);
          await storage.write(AppConstants.keyUserName, serverUser.fullName);
          await storage.write(AppConstants.keyUserRole, serverUser.role);
          return Result.success(serverUser);
        }
      } catch (e) {
        AppLogger.warn('Backend /auth/me check returned: $e, maintaining local session');
      }

      // If backend verification had an issue or is loading, remember the local user
      return Result.success(localUser);
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
