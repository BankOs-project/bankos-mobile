import 'package:bankos_mobile/features/accounts/data/repositories/accounts_repository.dart';
import 'package:bankos_mobile/features/accounts/domain/models/session_account.dart';
import 'package:bankos_mobile/features/auth/domain/models/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

final _session = AuthSession(
  accessToken: 'test-token',
  tokenType: 'bearer',
  expiresAt: DateTime.utc(2100),
  userId: 'user-1',
  tenantId: 'bank-1',
  role: 'administrador',
  bankLabel: 'Banco Andino',
  email: 'juan@example.com',
);

Map<String, dynamic> _account(
  int number, {
  String ownerId = 'user-1',
  String tenantId = 'bank-1',
}) => {
  'account_number': '123456${number.toString().padLeft(4, '0')}',
  'tenant_id': tenantId,
  'owner_id': ownerId,
  'currency': 'EUR',
  'status': 'BLOCKED',
  'balance': '98765432100010.1234',
};

void main() {
  test(
    'lee todas las páginas para el titular y conserva el saldo decimal',
    () async {
      final requestedOffsets = <int>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
      addTearDown(dio.close);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final skip = options.queryParameters['skip'] as int;
            requestedOffsets.add(skip);
            expect(options.path, '/accounts');
            expect(options.headers['Authorization'], 'Bearer test-token');
            expect(options.queryParameters['owner_id'], 'user-1');
            expect(options.queryParameters['limit'], 100);

            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'success': true,
                  'data': {
                    'total': 101,
                    'items': skip == 0
                        ? List.generate(100, _account)
                        : [_account(100)],
                  },
                },
              ),
            );
          },
        ),
      );

      final accounts = await AccountsRepository(dio)
          .fetchAccounts(_session, cancelToken: CancelToken());
      expect(requestedOffsets, [0, 100]);
      expect(accounts, hasLength(101));
      expect(accounts.last.maskedNumber, '•••• 0100');
      expect(accounts.first.status, AccountStatus.blocked);
      expect(accounts.first.currency, 'EUR');
      expect(accounts.first.balanceUnits, BigInt.parse('987654321000101234'));
      expect(
        formatAccountBalance(accounts.first.balanceUnits, 'EUR'),
        '€98,765,432,100,010.1234 EUR',
      );
    },
  );

  for (final item in [
    _account(1, ownerId: 'otro-cliente'),
    _account(1, tenantId: 'otro-banco'),
  ]) {
    test('rechaza una cuenta ajena al titular o banco de la sesión', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
      addTearDown(dio.close);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'total': 1,
                  'items': [item],
                },
              },
            ),
          ),
        ),
      );
      await expectLater(
        AccountsRepository(dio)
            .fetchAccounts(_session, cancelToken: CancelToken()),
        throwsFormatException,
      );
    });
  }
}
