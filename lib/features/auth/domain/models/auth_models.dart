class LoginRequest {
  const LoginRequest({
    required this.tenantSlug,
    required this.email,
    required this.password,
  });

  final String tenantSlug;
  final String email;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'tenant_slug': tenantSlug.trim().toLowerCase(),
      'email': email.trim().toLowerCase(),
      'password': password,
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.userId,
    required this.tenantId,
    required this.role,
    required this.tenantSlug,
    required this.email,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String userId;
  final String tenantId;
  final String role;
  final String tenantSlug;
  final String email;

  factory AuthSession.fromJson(
    Map<String, dynamic> json, {
    required String tenantSlug,
    required String email,
  }) {
    final accessToken = json['access_token'] as String?;
    final userId = json['user_id']?.toString();
    final tenantId = json['tenant_id']?.toString();

    if (accessToken == null ||
        accessToken.isEmpty ||
        userId == null ||
        tenantId == null) {
      throw const AuthException(
        message: 'La respuesta del servidor no contiene una sesión válida.',
        internalCode: 'INVALID_AUTH_PAYLOAD',
      );
    }

    return AuthSession(
      accessToken: accessToken,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 3600,
      userId: userId,
      tenantId: tenantId,
      role: (json['role'] as String?) ?? 'cliente',
      tenantSlug: tenantSlug.trim().toLowerCase(),
      email: email.trim().toLowerCase(),
    );
  }
}

class AuthException implements Exception {
  const AuthException({
    required this.message,
    this.internalCode,
    this.statusCode,
  });

  final String message;
  final String? internalCode;
  final int? statusCode;

  @override
  String toString() => 'AuthException($internalCode, $statusCode): $message';
}
