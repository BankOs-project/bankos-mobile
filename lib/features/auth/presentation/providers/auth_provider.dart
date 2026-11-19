import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.session,
    this.errorMessage,
    this.internalCode,
  });

  final bool isLoading;
  final AuthSession? session;
  final String? errorMessage;
  final String? internalCode;

  bool get isAuthenticated => session != null;

  AuthState copyWith({
    bool? isLoading,
    AuthSession? session,
    String? errorMessage,
    String? internalCode,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      internalCode: clearError ? null : (internalCode ?? this.internalCode),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<bool> login({
    required String tenantSlug,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repository = ref.read(authRepositoryProvider);
      final session = await repository.login(
        LoginRequest(
          tenantSlug: tenantSlug,
          email: email,
          password: password,
        ),
      );

      ref.read(authTokenProvider.notifier).setToken(session.accessToken);
      state = AuthState(isLoading: false, session: session);
      return true;
    } on AuthException catch (e) {
      ref.read(authTokenProvider.notifier).clear();
      state = AuthState(
        isLoading: false,
        errorMessage: e.message,
        internalCode: e.internalCode,
      );
      return false;
    } catch (_) {
      ref.read(authTokenProvider.notifier).clear();
      state = const AuthState(
        isLoading: false,
        errorMessage: 'No se pudo iniciar sesión. Intenta nuevamente.',
        internalCode: 'UNKNOWN_ERROR',
      );
      return false;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void logout() {
    ref.read(authTokenProvider.notifier).clear();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final activeSessionProvider = Provider<AuthSession?>(
  (ref) => ref.watch(authProvider.select((state) => state.session)),
);

final customerNameProvider = FutureProvider.autoDispose<String?>((ref) async {
  if (ref.watch(activeSessionProvider) == null) return null;
  return ref.watch(authRepositoryProvider).fetchCustomerName();
});
