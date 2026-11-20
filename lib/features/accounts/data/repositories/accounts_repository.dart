import 'package:dio/dio.dart';

import '../../../auth/domain/models/auth_models.dart';
import '../../domain/models/session_account.dart';

class AccountsRepository {
  const AccountsRepository(this._dio);

  final Dio _dio;

  Future<List<SessionAccount>> fetchAccounts(
    AuthSession session, {
    required CancelToken cancelToken,
  }) async {
    const limit = 100;
    final accounts = <String, SessionAccount>{};
    var skip = 0;

    while (true) {
      final response = await _dio.get<Map<String, dynamic>>(
        '/accounts',
        queryParameters: {
          'skip': skip,
          'limit': limit,
          if (session.role == 'administrador') 'owner_id': session.userId,
        },
        options: _options(session),
        cancelToken: cancelToken,
      );
      final body = response.data;
      final page = body?['data'];
      if (body?['success'] != true || page is! Map<String, dynamic>) {
        throw const FormatException('Respuesta de cuentas inválida.');
      }

      final items = page['items'];
      final total = page['total'];
      if (items is! List || total is! int || total < 0) {
        throw const FormatException('Paginación de cuentas inválida.');
      }
      for (final item in items) {
        final account = _ownedAccount(session, item);
        accounts[account.accountNumber] = account;
      }
      skip += items.length;
      if (items.isEmpty || skip >= total) {
        return List.unmodifiable(accounts.values);
      }
    }
  }

  Future<SessionAccount> fetchAccount(
    AuthSession session,
    String number, {
    required CancelToken cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/accounts/${Uri.encodeComponent(number)}',
      options: _options(session),
      cancelToken: cancelToken,
    );
    return _accountResponse(
      session,
      number,
      response,
      'ACCOUNT_DETAIL_FETCHED',
    );
  }

  Future<void> changeStatus(
    AuthSession session,
    String number, {
    required bool reactivate,
  }) async {
    final action = reactivate ? 'reactivate' : 'deactivate';
    final response = await _dio.patch<Map<String, dynamic>>(
      '/accounts/${Uri.encodeComponent(number)}/$action',
      options: _options(session),
    );
    final account = _accountResponse(
      session,
      number,
      response,
      reactivate ? 'ACCOUNT_REACTIVATED' : 'ACCOUNT_DEACTIVATED',
    );
    if (account.status !=
        (reactivate ? AccountStatus.active : AccountStatus.inactive)) {
      throw const FormatException('El estado de la cuenta no coincide.');
    }
  }

  SessionAccount _accountResponse(
    AuthSession session,
    String number,
    Response<Map<String, dynamic>> response,
    String expectedCode,
  ) {
    final body = response.data;
    if (body?['success'] != true || body?['internal_code'] != expectedCode) {
      throw const FormatException('Respuesta de cuenta inválida.');
    }
    final account = _ownedAccount(session, body?['data']);
    if (account.accountNumber != number) {
      throw const FormatException('El número de cuenta no coincide.');
    }
    return account;
  }

  SessionAccount _ownedAccount(AuthSession session, Object? item) {
    if (item is! Map<String, dynamic> ||
        item['tenant_id'] != session.tenantId ||
        item['owner_id'] != session.userId) {
      throw const FormatException('Cuenta ajena a la sesión.');
    }
    return SessionAccount.fromJson(item);
  }

  Options _options(AuthSession session) =>
      Options(headers: {'Authorization': 'Bearer ${session.accessToken}'});
}
