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
        options: Options(
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
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
        if (item is! Map<String, dynamic> ||
            item['tenant_id'] != session.tenantId ||
            item['owner_id'] != session.userId) {
          throw const FormatException('Cuenta ajena a la sesión.');
        }
        final account = SessionAccount.fromJson(item);
        accounts[account.accountNumber] = account;
      }
      skip += items.length;
      if (items.isEmpty || skip >= total) {
        return List.unmodifiable(accounts.values);
      }
    }
  }
}
