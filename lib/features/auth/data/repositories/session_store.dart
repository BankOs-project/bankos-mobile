import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/auth_models.dart';
import '../../domain/models/public_bank.dart';

abstract interface class SessionStore {
  Future<AuthSession?> read();
  Future<void> save(AuthSession session);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore(this._storage);

  static const _key = 'bankos.auth.session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;

    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return AuthSession.fromJson(
        json,
        bankLabel:
            (json['bank_name'] as String?) ??
            _legacyBankLabel(json['tenant_slug'] as String),
        email: json['email'] as String,
        bankLogoUrl: parseBankLogoUrl(json['bank_logo_url']),
        bankId: json['bank_id'] as String?,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
    } catch (_) {
      throw const FormatException('La sesión guardada no es válida.');
    }
  }

  @override
  Future<void> save(AuthSession session) => _storage.write(
    key: _key,
    value: jsonEncode({
      'access_token': session.accessToken,
      'token_type': session.tokenType,
      'user_id': session.userId,
      'tenant_id': session.tenantId,
      'bank_name': session.bankLabel,
      'bank_logo_url': session.bankLogoUrl?.toString(),
      'bank_id': session.bankId,
      'email': session.email,
      'role': session.role,
      'expires_at': session.expiresAt.toUtc().toIso8601String(),
    }),
  );

  @override
  Future<void> clear() => _storage.delete(key: _key);

  String _legacyBankLabel(String slug) => slug
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
