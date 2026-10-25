import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/auth_repository.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final User user;
  const Authenticated(this.user);
}

class Unauthenticated extends AuthState {
  final String? message;
  const Unauthenticated([this.message]);
}

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    ref.watch(authRepositoryProvider);
    Future.microtask(() => checkSession());
    return const AuthInitial();
  }

  Future<void> checkSession() async {
    state = const AuthLoading();
    final result = await _authRepository.getCurrentUser();
    result.when(
      onSuccess: (user) {
        if (user != null) {
          state = Authenticated(user);
        } else {
          state = const Unauthenticated();
        }
      },
      onFailure: (failure) {
        state = Unauthenticated(failure.message);
      },
    );
  }

  Future<bool> login(String email, String password) async {
    state = const AuthLoading();
    final result = await _authRepository.login(
      LoginCredentials(email: email, password: password),
    );

    return result.when(
      onSuccess: (user) {
        state = Authenticated(user);
        return true;
      },
      onFailure: (failure) {
        state = Unauthenticated(failure.message);
        return false;
      },
    );
  }

  Future<void> logout() async {
    await _authRepository.logout();
    state = const Unauthenticated();
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
