import 'package:flutter_test/flutter_test.dart';
import 'package:secure_door_access/core/constants/app_constants.dart';
import 'package:secure_door_access/core/errors/failures.dart';
import 'package:secure_door_access/core/storage/secure_storage_service.dart';
import 'package:secure_door_access/features/authentication/data/repositories/mock_auth_repository.dart';
import 'package:secure_door_access/features/authentication/domain/models/user.dart';

void main() {
  group('Authentication & Session Handling Tests', () {
    late InMemorySecureStorageService mockStorage;
    late MockAuthRepository authRepo;

    setUp(() {
      mockStorage = InMemorySecureStorageService();
      authRepo = MockAuthRepository(storage: mockStorage);
    });

    test('Initial session state is empty when no token is stored', () async {
      final userResult = await authRepo.getCurrentUser();
      expect(userResult.isSuccess, isTrue);
      expect(userResult.dataOrNull, isNull);

      final hasSession = await authRepo.hasValidSession();
      expect(hasSession, isFalse);
    });

    test('Successful login stores security tokens in secure storage', () async {
      final result = await authRepo.login(
        const LoginCredentials(
          email: 'engineer@college.edu',
          password: 'Access@IoE2026',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.email, equals('engineer@college.edu'));

      // Verify tokens were placed into secure storage
      final storedToken = await mockStorage.read(AppConstants.keyAccessToken);
      expect(storedToken, isNotNull);
      expect(storedToken!.startsWith('mock_jwt_token_'), isTrue);

      final hasSession = await authRepo.hasValidSession();
      expect(hasSession, isTrue);
    });

    test(
      'Login fails on invalid credentials without exposing stack trace',
      () async {
        final result = await authRepo.login(
          const LoginCredentials(
            email: 'engineer@college.edu',
            password: 'wrongpassword',
          ),
        );

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<AuthFailure>());
        expect(
          result.failureOrNull?.message,
          contains('Invalid email or password'),
        );

        final token = await mockStorage.read(AppConstants.keyAccessToken);
        expect(token, isNull);
      },
    );

    test('Input validation rejects invalid email format', () async {
      final result = await authRepo.login(
        const LoginCredentials(email: 'not-an-email', password: 'password123'),
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.message,
        contains('valid academic/institutional email'),
      );
    });

    test('Logout invalidates session and wipes all stored tokens', () async {
      // Login first
      await authRepo.login(
        const LoginCredentials(
          email: 'engineer@college.edu',
          password: 'Access@IoE2026',
        ),
      );
      expect(await authRepo.hasValidSession(), isTrue);

      // Perform logout
      final logoutResult = await authRepo.logout();
      expect(logoutResult.isSuccess, isTrue);

      // Verify complete purge
      expect(await authRepo.hasValidSession(), isFalse);
      expect(await mockStorage.read(AppConstants.keyAccessToken), isNull);
      expect(await mockStorage.read(AppConstants.keyUserId), isNull);
    });
  });
}
