import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/dio_provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/session_store.dart';
import '../../domain/models/auth_models.dart';
import '../../domain/models/public_bank.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);

final bankDirectoryProvider = FutureProvider.autoDispose<List<PublicBank>>(
  (ref) => ref.watch(authRepositoryProvider).fetchBanks(),
  retry: (_, _) => null,
);

final mobileSecureStorageProvider = Provider<FlutterSecureStorage?>((ref) {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return null;
  }
  return const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
});

final sessionStoreProvider = Provider<SessionStore?>((ref) {
  final storage = ref.watch(mobileSecureStorageProvider);
  return storage == null ? null : SecureSessionStore(storage);
});

enum SessionStartup { checking, ready, unavailable, cleanupFailed }

class AuthState {
  const AuthState({
    this.startup = SessionStartup.ready,
    this.isLoading = false,
    this.session,
    this.customerName,
    this.errorMessage,
    this.internalCode,
  });

  final SessionStartup startup;
  final bool isLoading;
  final AuthSession? session;
  final String? customerName;
  final String? errorMessage;
  final String? internalCode;

  bool get isAuthenticated => session != null;
}

class AuthNotifier extends Notifier<AuthState> {
  Timer? _expiryTimer;
  int _operation = 0;
  Future<void> _storageChanges = Future.value();

  @override
  AuthState build() {
    ref.onDispose(() => _expiryTimer?.cancel());
    ref.listen(authTokenProvider, (previous, next) {
      if (next == null &&
          previous != null &&
          state.session?.accessToken == previous) {
        unawaited(
          logout(
            message: 'La sesión dejó de ser válida. Inicia sesión de nuevo.',
          ),
        );
      }
    });
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(restore());
    });
    return const AuthState(startup: SessionStartup.checking);
  }

  Future<void> restore() async {
    final operation = ++_operation;
    state = const AuthState(startup: SessionStartup.checking);
    _expiryTimer?.cancel();
    ref.read(authTokenProvider.notifier).clear();
    try {
      await _storageChanges;
      if (!_isCurrent(operation)) return;
      final session = await ref.read(sessionStoreProvider)?.read();
      if (!_isCurrent(operation)) return;
      if (session == null) {
        state = const AuthState();
        return;
      }
      if (session.isExpired) {
        await logout(message: 'La sesión venció. Inicia sesión de nuevo.');
        return;
      }

      _scheduleExpiration(session);
      final name = await ref
          .read(authRepositoryProvider)
          .fetchCustomerName(session);
      if (_isCurrent(operation)) _activate(session, customerName: name);
    } on FormatException {
      if (_isCurrent(operation)) await logout();
    } on AuthException catch (error) {
      if (!_isCurrent(operation)) return;
      if (error.internalCode == 'SESSION_REJECTED') {
        await logout(message: error.message);
      } else {
        state = const AuthState(startup: SessionStartup.unavailable);
      }
    } catch (_) {
      if (_isCurrent(operation)) {
        state = const AuthState(startup: SessionStartup.unavailable);
      }
    }
  }

  Future<bool> login({
    required PublicBank bank,
    required String email,
    required String password,
  }) async {
    if (state.isLoading || state.startup != SessionStartup.ready) return false;

    final operation = ++_operation;
    final previousSession = state.session;
    final store = ref.read(sessionStoreProvider);
    _clearMemory();
    try {
      if (previousSession != null && store != null) {
        await _updateStorage(store.clear);
      }
      if (!_isCurrent(operation)) return false;
      final session = await ref
          .read(authRepositoryProvider)
          .login(
            LoginRequest(
              bankId: bank.id,
              bankName: bank.name,
              email: email,
              password: password,
            ),
          );
      if (!_isCurrent(operation)) return false;
      if (store != null) await _updateStorage(() => store.save(session));
      if (!_isCurrent(operation)) return false;
      return _activate(session);
    } on AuthException catch (error) {
      if (_isCurrent(operation)) {
        await logout(message: error.message, code: error.internalCode);
      }
    } catch (_) {
      if (_isCurrent(operation)) {
        await logout(message: 'No se pudo iniciar sesión. Intenta nuevamente.');
      }
    }
    return false;
  }

  void clearError() {
    if (!state.isLoading && state.errorMessage != null) {
      state = AuthState(
        session: state.session,
        customerName: state.customerName,
      );
    }
  }

  Future<void> logout({String? message, String? code}) async {
    final operation = ++_operation;
    final store = ref.read(sessionStoreProvider);
    _clearMemory();
    try {
      if (store != null) await _updateStorage(store.clear);
      if (_isCurrent(operation)) {
        state = AuthState(errorMessage: message, internalCode: code);
      }
    } catch (_) {
      if (_isCurrent(operation)) {
        state = const AuthState(startup: SessionStartup.cleanupFailed);
      }
    }
  }

  bool _activate(AuthSession session, {String? customerName}) {
    if (session.isExpired) {
      unawaited(logout(message: 'La sesión venció. Inicia sesión de nuevo.'));
      return false;
    }
    _scheduleExpiration(session);
    ref.read(authTokenProvider.notifier).setToken(session.accessToken);
    state = AuthState(session: session, customerName: customerName);
    return true;
  }

  void _clearMemory() {
    _expiryTimer?.cancel();
    state = const AuthState(isLoading: true);
    ref.read(authTokenProvider.notifier).clear();
  }

  void _scheduleExpiration(AuthSession session) {
    _expiryTimer?.cancel();
    _expiryTimer = Timer(session.expiresAt.difference(DateTime.now()), () {
      unawaited(logout(message: 'La sesión venció. Inicia sesión de nuevo.'));
    });
  }

  bool _isCurrent(int operation) => ref.mounted && _operation == operation;

  // Serializa los cambios para que un borrado no se adelante a una escritura pendiente.
  Future<void> _updateStorage(Future<void> Function() change) {
    final result = _storageChanges.then((_) => change());
    _storageChanges = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final activeSessionProvider = Provider<AuthSession?>(
  (ref) => ref.watch(authProvider.select((state) => state.session)),
);

final customerNameProvider = FutureProvider.autoDispose<String?>((ref) async {
  final auth = ref.watch(authProvider);
  final session = auth.session;
  if (session == null || auth.customerName != null) return auth.customerName;
  try {
    return await ref.watch(authRepositoryProvider).fetchCustomerName(session);
  } on AuthException catch (error) {
    if (error.internalCode == 'SESSION_REJECTED' &&
        ref.mounted &&
        identical(ref.read(activeSessionProvider), session)) {
      await ref.read(authProvider.notifier).logout(message: error.message);
    }
    return null;
  }
}, retry: (_, _) => null);
