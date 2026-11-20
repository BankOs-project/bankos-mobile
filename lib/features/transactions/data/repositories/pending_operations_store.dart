import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../auth/domain/models/auth_models.dart';
import '../../domain/models/transaction_models.dart';

class PendingOperationsStore {
  PendingOperationsStore(this._storage);

  final FlutterSecureStorage? _storage;
  final _memory = <String, ConfirmedOperation>{};

  String _key(AuthSession session) =>
      'bankos.pending.v1.${session.tenantId}.${session.userId}';

  Future<ConfirmedOperation?> read(AuthSession session) async {
    final key = _key(session);
    if (_storage == null) return _memory[key];

    final json = await _storage.read(key: key);
    return json == null
        ? null
        : ConfirmedOperation.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> save(AuthSession session, ConfirmedOperation operation) async {
    final key = _key(session);
    if (_storage != null) {
      await _storage.write(key: key, value: jsonEncode(operation.toJson()));
    } else {
      _memory[key] = operation;
    }
  }

  Future<void> clear(AuthSession session) async {
    final key = _key(session);
    if (_storage != null) {
      await _storage.delete(key: key);
    } else {
      _memory.remove(key);
    }
  }
}
