import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../auth/domain/models/auth_models.dart';
import '../domain/user_profile.dart';

class ProfileRepository {
  const ProfileRepository(this._dio);

  static const _profile = '/auth/me';
  static const _photo = '$_profile/photo';
  static const _email = '$_profile/email-change';
  static const maxPhotoBytes = 2 * 1024 * 1024;

  final Dio _dio;

  Future<UserProfile> getProfile(AuthSession session, CancelToken cancel) =>
      _profileRequest('GET', _profile, 'USER_PROFILE', session, cancel);

  Future<UserProfile> update(
    AuthSession session,
    CancelToken cancel,
    Map<String, String?> fields,
  ) => _profileRequest(
    'PATCH',
    _profile,
    'USER_PROFILE_UPDATED',
    session,
    cancel,
    data: fields,
  );

  Future<UserProfile> uploadPhoto(
    AuthSession session,
    CancelToken cancel,
    Uint8List bytes,
  ) {
    if (bytes.length > maxPhotoBytes) {
      throw const ProfileException('La foto debe pesar hasta 2 MiB.');
    }
    final type = _photoType(bytes);
    if (type == null) {
      throw const ProfileException('Selecciona una foto JPEG o PNG.');
    }
    return _profileRequest(
      'PUT',
      _photo,
      'PROFILE_PHOTO_UPDATED',
      session,
      cancel,
      data: bytes,
      contentType: type,
    );
  }

  Future<UserProfile> removePhoto(AuthSession session, CancelToken cancel) =>
      _profileRequest(
        'DELETE',
        _photo,
        'PROFILE_PHOTO_REMOVED',
        session,
        cancel,
      );

  Future<Uint8List?> getPhoto(AuthSession session, CancelToken cancel) =>
      _request(() async {
        final response = await _dio.get<Uint8List>(
          _photo,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Accept': 'image/jpeg, image/png',
            },
            validateStatus: (status) => status == 200 || status == 404,
          ),
          cancelToken: cancel,
        );
        if (response.statusCode == 404) return null;
        final bytes = response.data;
        if (bytes == null ||
            bytes.length > maxPhotoBytes ||
            _photoType(bytes) == null) {
          throw const ProfileException('No pudimos abrir la foto.');
        }
        return bytes;
      });

  Future<PendingProfileEmail> startEmailChange(
    AuthSession session,
    CancelToken cancel, {
    required String email,
    required String password,
  }) async {
    final data = await _json(
      'POST',
      _email,
      'PROFILE_EMAIL_PENDING',
      session,
      cancel,
      data: {'new_email': email, 'current_password': password},
    );
    final id = data['request_id'];
    final seconds = data['expires_in'];
    if (id is! String || id.isEmpty || seconds is! int || seconds <= 0) {
      throw const ProfileException('No pudimos leer la solicitud de correo.');
    }
    return PendingProfileEmail(
      email,
      id,
      DateTime.now().add(Duration(seconds: seconds)),
    );
  }

  Future<UserProfile> verifyEmail(
    AuthSession session,
    CancelToken cancel,
    PendingProfileEmail pending,
    String code,
  ) => _profileRequest(
    'POST',
    '$_email/verify',
    'PROFILE_EMAIL_UPDATED',
    session,
    cancel,
    data: {'request_id': pending.requestId, 'email_code': code},
  );

  Future<UserProfile> _profileRequest(
    String method,
    String path,
    String code,
    AuthSession session,
    CancelToken cancel, {
    Object? data,
    String? contentType,
  }) async {
    final profile = await _json(
      method,
      path,
      code,
      session,
      cancel,
      data: data,
      contentType: contentType,
    );
    if (profile['id'] != session.userId ||
        profile['tenant_id'] != session.tenantId ||
        profile['role'] != session.role ||
        profile['is_active'] != true) {
      throw const ProfileException('El perfil no corresponde a esta sesión.');
    }
    if (profile['full_name'] is! String || profile['email'] is! String) {
      throw const ProfileException('No pudimos leer el perfil del servidor.');
    }
    return UserProfile.fromJson(profile);
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path,
    String code,
    AuthSession session,
    CancelToken cancel, {
    Object? data,
    String? contentType,
  }) => _request(() async {
    final response = await _dio.request<Map<String, dynamic>>(
      path,
      data: data,
      cancelToken: cancel,
      options: Options(
        method: method,
        contentType: contentType,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      ),
    );
    final body = response.data;
    final payload = body?['data'];
    if (body?['success'] != true ||
        body?['internal_code'] != code ||
        payload is! Map<String, dynamic>) {
      throw const ProfileException(
        'No pudimos leer la respuesta del servidor.',
      );
    }
    return payload;
  });

  Future<T> _request<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      final body = error.response?.data;
      final code = body is Map ? body['internal_code'] : null;
      final data = body is Map ? body['data'] : null;
      final validations = data is Map ? data['validation_errors'] : null;
      final fields = <String, String>{};
      if (validations is List) {
        for (final item in validations.whereType<Map>()) {
          if (item case {
            'field': final String field,
            'message': final String message,
          }) {
            fields[field.split(' -> ').last] = message;
          }
        }
      }
      if (code == 'PROFILE_DOCUMENT_INCOMPLETE') {
        fields['document_number'] =
            'Indica o elimina el tipo y el número juntos.';
      }
      if (code == 'AUTHENTICATION_FAILED') {
        fields['current_password'] = 'Comprueba la contraseña actual.';
      }
      final retry =
          int.tryParse(error.response?.headers.value('retry-after') ?? '') ??
          (data is Map && data['retry_after_seconds'] is int
              ? data['retry_after_seconds'] as int
              : null);
      final message = switch (code) {
        'PROFILE_EMAIL_INVALID' => 'El código es inválido o venció.',
        'PROFILE_EMAIL_UNCHANGED' => 'Indica un correo distinto al actual.',
        'PROFILE_EMAIL_UNAVAILABLE_IN_BANK' =>
          'El correo no está disponible en este banco.',
        'PROFILE_EMAIL_UNAVAILABLE' =>
          'No pudimos enviar el código. Intenta más tarde.',
        'PROFILE_PHOTO_TOO_LARGE' => 'La foto debe pesar hasta 2 MiB.',
        'PROFILE_PHOTO_UNSUPPORTED_TYPE' => 'Selecciona una foto JPEG o PNG.',
        'PROFILE_PHOTO_INVALID' =>
          'Usa una imagen estática válida de hasta 2048 × 2048.',
        'RATE_LIMIT_EXCEEDED' when retry != null =>
          'Espera $retry segundos antes de reintentar.',
        'RATE_LIMIT_EXCEEDED' => 'Espera un momento antes de reintentar.',
        _ when fields.isNotEmpty => 'Revisa los campos indicados.',
        _ => 'No pudimos completar la solicitud. Intenta de nuevo.',
      };
      throw ProfileException(
        message,
        fields: fields,
        retryAfter:
            error.response?.statusCode == 429 && retry != null && retry > 0
            ? Duration(seconds: retry)
            : null,
      );
    }
  }

  String? _photoType(Uint8List bytes) {
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= png.length &&
        png.indexed.every((entry) => bytes[entry.$1] == entry.$2)) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    return null;
  }
}
