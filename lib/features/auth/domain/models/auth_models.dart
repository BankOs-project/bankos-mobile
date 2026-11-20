import 'dart:convert';

class RegistrationChallenge {
  RegistrationChallenge({required this.id, required this.validFor})
    : expiresAt = DateTime.now().add(validFor);

  final String id;
  final Duration validFor;
  final DateTime expiresAt;
}

class LoginRequest {
  const LoginRequest({
    required this.bankId,
    required this.bankName,
    required this.email,
    required this.password,
  });

  final String bankId;
  final String bankName;
  final String email;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'bank_id': bankId,
      'email': email.trim().toLowerCase(),
      'password': password,
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.userId,
    required this.tenantId,
    required this.role,
    required this.bankLabel,
    required this.email,
  });

  final String accessToken;
  final String tokenType;
  final DateTime expiresAt;
  final String userId;
  final String tenantId;
  final String role;
  final String bankLabel;
  final String email;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());

  factory AuthSession.fromJson(
    Map<String, dynamic> json, {
    required String bankLabel,
    required String email,
    DateTime? expiresAt,
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

    final localExpiry =
        expiresAt ??
        DateTime.now().toUtc().add(
          Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 3600),
        );
    final tokenExpiry = _jwtExpiry(accessToken);

    return AuthSession(
      accessToken: accessToken,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      expiresAt: tokenExpiry != null && tokenExpiry.isBefore(localExpiry)
          ? tokenExpiry
          : localExpiry,
      userId: userId,
      tenantId: tenantId,
      role: (json['role'] as String?) ?? 'cliente',
      bankLabel: bankLabel,
      email: email.trim().toLowerCase(),
    );
  }

  // La fecha del JWT solo acorta el plazo local, FastAPI valida el token.
  static DateTime? _jwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final seconds = payload is Map ? payload['exp'] : null;
      if (seconds is! int || seconds < 0 || seconds > 8640000000000) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    } on FormatException {
      return null;
    }
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
