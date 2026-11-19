import 'package:dio/dio.dart';

import '../../domain/models/auth_models.dart';

class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  /// Valida las credenciales contra `POST /api/v1/auth/login` en BankOS Backend.
  Future<AuthSession> login(LoginRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/login',
        data: request.toJson(),
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const AuthException(
          message: 'Respuesta inesperada del servidor de autenticación.',
          internalCode: 'INVALID_RESPONSE_FORMAT',
        );
      }

      final success = body['success'] as bool? ?? false;
      final message = (body['message'] as String?) ??
          'No se pudo completar el inicio de sesión.';
      final internalCode = body['internal_code'] as String?;

      if (!success) {
        throw AuthException(
          message: message,
          internalCode: internalCode,
          statusCode: response.statusCode,
        );
      }

      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw const AuthException(
          message: 'No se recibieron los datos de sesión desde el servidor.',
          internalCode: 'MISSING_SESSION_DATA',
        );
      }

      return AuthSession.fromJson(
        data,
        tenantSlug: request.tenantSlug,
        email: request.email,
      );
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (_) {
      throw const AuthException(
        message: 'Ocurrió un error inesperado al iniciar sesión.',
        internalCode: 'UNEXPECTED_ERROR',
      );
    }
  }

  AuthException _mapDioException(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;

    if (body is Map<String, dynamic>) {
      final internalCode = body['internal_code'] as String?;
      final rawMessage = body['message'] as String?;

      // Si FastAPI/Pydantic devuelve errores de validación detallados (422)
      if (internalCode == 'VALIDATION_ERROR') {
        final data = body['data'];
        if (data is Map<String, dynamic> && data['validation_errors'] is List) {
          final errors = data['validation_errors'] as List;
          if (errors.isNotEmpty && errors.first is Map) {
            final firstError = errors.first as Map;
            final field = firstError['field']?.toString() ?? '';
            if (field.contains('password')) {
              return AuthException(
                message: 'La contraseña debe tener al menos 6 caracteres.',
                internalCode: internalCode,
                statusCode: statusCode,
              );
            }
            if (field.contains('email')) {
              return AuthException(
                message: 'El formato del correo electrónico no es válido.',
                internalCode: internalCode,
                statusCode: statusCode,
              );
            }
          }
        }
      }

      if (rawMessage != null && rawMessage.trim().isNotEmpty) {
        return AuthException(
          message: rawMessage,
          internalCode: internalCode,
          statusCode: statusCode,
        );
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const AuthException(
          message:
              'Tiempo de espera agotado al conectar con el servidor de BankOs.',
          internalCode: 'CONNECTION_TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return const AuthException(
          message:
              'No se pudo conectar con la API local de BankOs. Verifica que el backend esté activo en el puerto 8000.',
          internalCode: 'CONNECTION_ERROR',
        );
      case DioExceptionType.badResponse:
        if (statusCode == 401) {
          return const AuthException(
            message: 'Institución bancaria o credenciales no válidas.',
            internalCode: 'AUTHENTICATION_FAILED',
            statusCode: 401,
          );
        }
        if (statusCode == 429) {
          return const AuthException(
            message: 'Demasiados intentos. Intenta nuevamente en unos momentos.',
            internalCode: 'RATE_LIMIT_EXCEEDED',
            statusCode: 429,
          );
        }
        return AuthException(
          message: 'Error del servidor (${statusCode ?? 'desconocido'}).',
          internalCode: 'SERVER_ERROR',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return const AuthException(
          message: 'La solicitud de inicio de sesión fue cancelada.',
          internalCode: 'REQUEST_CANCELLED',
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const AuthException(
          message:
              'No se pudo establecer comunicación con la API local de BankOs.',
          internalCode: 'NETWORK_ERROR',
        );
    }
  }
}
