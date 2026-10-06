import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final SecureStorageService storage;

  MockAuthRepository({required this.storage});

  static final User defaultMockUser = User(
    id: 'usr_ioe_9841',
    email: 'engineer@college.edu',
    fullName: 'IoE Lab Engineer',
    role: 'authorized_operator',
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
  );

  @override
  Future<Result<User>> login(LoginCredentials credentials) async {
    AppLogger.info('MockAuthRepository: processing login attempt');
    await Future.delayed(const Duration(milliseconds: 700));

    // Basic format validation
    if (credentials.email.isEmpty || !credentials.email.contains('@')) {
      return Result.failure(
        const AuthFailure('Please enter a valid academic/institutional email.'),
      );
    }

    if (credentials.password.length < 6) {
      return Result.failure(
        const AuthFailure('Password must be at least 6 characters.'),
      );
    }

    // Mock credential check (allow engineer@college.edu or any valid format for demonstration)
    if (credentials.password == 'wrongpassword') {
      return Result.failure(
        const AuthFailure('Invalid email or password combination.'),
      );
    }

    final user = User(
      id: 'usr_ioe_9841',
      email: credentials.email.trim(),
      fullName: credentials.email.startsWith('admin')
          ? 'Lab Administrator'
          : 'IoE Project Engineer',
      role: credentials.email.startsWith('admin')
          ? 'lab_admin'
          : 'authorized_operator',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    );

    // Save mock secure tokens
    await storage.write(
      AppConstants.keyAccessToken,
      'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}',
    );
    await storage.write(AppConstants.keyUserId, user.id);
    await storage.write(AppConstants.keyUserEmail, user.email);

    AppLogger.info('MockAuthRepository: login successful');
    return Result.success(user);
  }

  @override
  Future<Result<User?>> getCurrentUser() async {
    final token = await storage.read(AppConstants.keyAccessToken);
    if (token == null) {
      return Result.success(null);
    }

    final email =
        await storage.read(AppConstants.keyUserEmail) ?? 'engineer@college.edu';
    final user = User(
      id: 'usr_ioe_9841',
      email: email,
      fullName: email.startsWith('admin')
          ? 'Lab Administrator'
          : 'IoE Project Engineer',
      role: email.startsWith('admin') ? 'lab_admin' : 'authorized_operator',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    );
    return Result.success(user);
  }

  @override
  Future<Result<void>> logout() async {
    await storage.clearAll();
    AppLogger.info('MockAuthRepository: session cleared');
    return Result.success(null);
  }

  @override
  Future<bool> hasValidSession() async {
    final token = await storage.read(AppConstants.keyAccessToken);
    return token != null && token.isNotEmpty;
  }
}
