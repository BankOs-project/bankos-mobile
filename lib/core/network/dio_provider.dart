import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Resuelve la URL base de la API local de BankOs según la plataforma activa.
///
/// Puede sobrescribirse en tiempo de compilación/ejecución mediante:
/// `flutter run --dart-define=API_BASE_URL=http://<TU_IP>:8000/api/v1`
String resolveApiBaseUrl() {
  if (_envApiBaseUrl.isNotEmpty) {
    return _envApiBaseUrl;
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // En el emulador de Android, localhost del host se accede por 10.0.2.2
    return 'http://10.0.2.2:8000/api/v1';
  }

  return 'http://localhost:8000/api/v1';
}

/// Mantiene el JWT activo en memoria para inyectarlo en peticiones autenticadas.
class AuthTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setToken(String? token) {
    state = token;
  }

  void clear() {
    state = null;
  }
}

final authTokenProvider = NotifierProvider<AuthTokenNotifier, String?>(
  AuthTokenNotifier.new,
);

final apiBaseUrlProvider = Provider<String>((ref) => resolveApiBaseUrl());

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authTokenProvider);
        if (token != null &&
            token.isNotEmpty &&
            options.extra['publicRequest'] != true) {
          options.headers.putIfAbsent('Authorization', () => 'Bearer $token');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final token = ref.read(authTokenProvider);
        final request = error.requestOptions;
        final body = error.response?.data;
        final incorrectProfilePassword =
            request.path == '/auth/me/email-change' &&
            body is Map &&
            body['internal_code'] == 'AUTHENTICATION_FAILED';
        if (error.response?.statusCode == 401 &&
            request.path != '/auth/login' &&
            !incorrectProfilePassword &&
            token != null &&
            request.headers['Authorization'] == 'Bearer $token') {
          ref.read(authTokenProvider.notifier).clear();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
