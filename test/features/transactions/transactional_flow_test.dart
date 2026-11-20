import 'package:bankos_mobile/core/network/dio_provider.dart';
import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:bankos_mobile/features/auth/domain/models/auth_models.dart';
import 'package:bankos_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:bankos_mobile/features/transactions/data/repositories/pending_operations_store.dart';
import 'package:bankos_mobile/features/transactions/domain/models/transaction_models.dart';
import 'package:bankos_mobile/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:bankos_mobile/features/transactions/presentation/screens/summary_screen.dart';
import 'package:bankos_mobile/features/transactions/presentation/screens/transfer_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _session = AuthSession(
  accessToken: 'test-token',
  tokenType: 'bearer',
  expiresAt: DateTime.utc(2100),
  userId: 'cliente-1',
  tenantId: 'andino',
  role: 'cliente',
  bankLabel: 'Banco Andino',
  email: 'cliente@example.com',
);

enum _Outcome { success, networkLoss, inProgress, rejected }

class _OperationsApi {
  _OperationsApi({this.outcomes = const [_Outcome.success]}) {
    dio.interceptors.add(InterceptorsWrapper(onRequest: _request));
  }

  final List<_Outcome> outcomes;
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
  final requests = <RequestOptions>[];
  final mutations = <RequestOptions>[];
  final journal = PendingOperationsStore(null);
  bool destinationRejected = false;
  String balance = '5000.0000';

  void _request(RequestOptions request, RequestInterceptorHandler handler) {
    requests.add(request);
    expect(request.headers['Authorization'], 'Bearer test-token');

    void resolve(Map<String, Object?> data, [int status = 200]) =>
        handler.resolve(
          Response(
            requestOptions: request,
            statusCode: status,
            data: {'success': true, 'data': data},
          ),
        );

    void reject(int status, String code, String message) => handler.reject(
      DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: request,
          statusCode: status,
          data: {'success': false, 'internal_code': code, 'message': message},
        ),
      ),
    );

    final path = request.path;
    if (path == '/accounts') {
      resolve({
        'total': 1,
        'items': [
          {
            'tenant_id': _session.tenantId,
            'owner_id': _session.userId,
            'account_number': '1000000001',
            'balance': balance,
            'currency': 'COP',
            'status': 'ACTIVE',
          },
        ],
      });
      return;
    }
    if (path == '/accounts/1000000004/destination') {
      if (destinationRejected) {
        reject(
          404,
          'RESOURCE_NOT_FOUND',
          'Cuenta destino no disponible en esta institución',
        );
      } else {
        resolve({
          'account_number': '1000000004',
          'holder_name': 'Cliente destino',
          'currency': 'USD',
        });
      }
      return;
    }
    final body = request.data as Map<String, String>;
    if (path == '/transactions/quote') {
      final type = body['operation_type'];
      final transfer = type == 'TRANSFER';
      expect(body['source_account_number'], '1000000001');
      expect(body['amount'], '100.25');
      expect(
        body['destination_account_number'],
        transfer ? '1000000004' : null,
      );
      expect(request.headers.containsKey('Idempotency-Key'), isFalse);
      resolve({
        'operation_type': type,
        'source_currency': 'COP',
        'destination_currency': transfer ? 'USD' : 'COP',
        'amount_to_debit': transfer
            ? '102.2550'
            : type == 'DEPOSIT'
            ? '0'
            : '100.25',
        'fee_calculated': transfer ? '2.0050' : '0.0000',
        'exchange_rate_applied': transfer ? '0.000250' : '1',
        'final_amount_to_receive': transfer ? '0.0251' : '100.25',
      });
      return;
    }

    mutations.add(request);
    final type = FinancialOperationType.values.singleWhere(
      (item) => path == '/transactions/${item.endpoint}',
    );
    expect(
      body,
      type == FinancialOperationType.transfer
          ? {
              'source_account_number': '1000000001',
              'destination_account_number': '1000000004',
              'amount': '100.25',
            }
          : {'account_number': '1000000001', 'amount': '100.25'},
    );
    final uuid = RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
    );
    expect(request.headers['Idempotency-Key'], matches(uuid));
    expect(request.headers['X-Correlation-ID'], matches(uuid));
    expect(
      request.headers['X-Correlation-ID'],
      isNot(request.headers['Idempotency-Key']),
    );

    switch (outcomes[mutations.length - 1]) {
      case _Outcome.networkLoss:
        handler.reject(
          DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          ),
        );
      case _Outcome.inProgress:
        reject(
          409,
          'IDEMPOTENCY_IN_PROGRESS',
          'Transacción en proceso concurrente',
        );
      case _Outcome.rejected:
        reject(400, 'INSUFFICIENT_FUNDS', 'Saldo insuficiente.');
      case _Outcome.success:
        balance = '4900.0000';
        resolve({
          'id': 'id-confirmado-por-fastapi',
          'tenant_id': _session.tenantId,
          'operation_type': type.apiValue,
          'status': 'SUCCESS',
          'created_at': '2026-11-19T10:20:00Z',
          'source_account_number': type == FinancialOperationType.deposit
              ? null
              : '1000000001',
          'destination_account_number': switch (type) {
            FinancialOperationType.transfer => '1000000004',
            FinancialOperationType.deposit => '1000000001',
            FinancialOperationType.withdrawal => null,
          },
          'original_amount': '100.2500',
          'original_currency': 'COP',
          'fee_charged': type == FinancialOperationType.transfer
              ? '2.0050'
              : '0.0000',
          'converted_amount': type == FinancialOperationType.transfer
              ? '0.0251'
              : '100.2500',
          'destination_currency': type == FinancialOperationType.transfer
              ? 'USD'
              : 'COP',
          'exchange_rate_applied': type == FinancialOperationType.transfer
              ? '0.000250'
              : '1',
          'idempotency_key': request.headers['Idempotency-Key'],
          'correlation_id': request.headers['X-Correlation-ID'],
        }, 201);
    }
  }
}

Future<GoRouter> _open(
  WidgetTester tester,
  _OperationsApi api, {
  FinancialOperationType type = FinancialOperationType.transfer,
  required Future<bool> Function() confirm,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(api.dio.close);
  final router = GoRouter(
    initialLocation: '/transactions/transfer',
    routes: [
      GoRoute(
        path: '/transactions/transfer',
        builder: (_, _) => TransferScreen(initialType: type),
      ),
      GoRoute(
        path: '/transactions/summary',
        builder: (_, _) => const SummaryScreen(),
      ),
      GoRoute(path: '/accounts', builder: (_, _) => const AccountsScreen()),
      GoRoute(path: '/operations', builder: (_, _) => const Scaffold()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeSessionProvider.overrideWithValue(_session),
        dioProvider.overrideWithValue(api.dio),
        pendingOperationsStoreProvider.overrideWithValue(api.journal),
        confirmWithDeviceProvider.overrideWithValue(confirm),
      ],
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _quote(WidgetTester tester, {bool transfer = true}) async {
  if (transfer) {
    await tester.enterText(
      find.byKey(const Key('destination_account_field')),
      '1000000004',
    );
  }
  await tester.enterText(find.byKey(const Key('amount_field')), '100,25');
  final button = find.byKey(const Key('review_transfer_button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('confirm_operation_button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'reintenta un timeout y un 409 sin cambiar cuerpo ni identificadores',
    (tester) async {
      final api = _OperationsApi(
        outcomes: [_Outcome.networkLoss, _Outcome.inProgress, _Outcome.success],
      );
      var deviceConfirmations = 0;
      final router = await _open(
        tester,
        api,
        confirm: () async {
          deviceConfirmations++;
          return true;
        },
      );

      await _quote(tester);
      expect(api.requests.map((r) => r.path), [
        '/accounts',
        '/accounts/1000000004/destination',
        '/transactions/quote',
      ]);
      expect(find.text('Cliente destino · •••• 0004'), findsOneWidget);
      expect(find.text(r'$102,255 COP'), findsOneWidget);
      expect(find.text(r'$2,005 COP'), findsOneWidget);
      expect(find.text('1 COP = 0.000250 USD'), findsOneWidget);
      expect(find.text(r'$0.0251 USD'), findsOneWidget);
      expect(api.mutations, isEmpty);

      await _confirm(tester);
      expect(find.text('Operación pendiente'), findsOneWidget);
      final pending = await api.journal.read(_session);
      expect(pending, isNotNull);

      router.go('/operations');
      await tester.pumpAndSettle();
      router.go('/transactions/transfer');
      await tester.pumpAndSettle();
      expect(find.text('Operación pendiente'), findsOneWidget);

      await tester.tap(find.text('Reintentar operación'));
      await tester.pumpAndSettle();
      expect(find.text('Operación pendiente'), findsOneWidget);
      await tester.tap(find.text('Reintentar operación'));
      await tester.pumpAndSettle();

      expect(deviceConfirmations, 1);
      expect(api.mutations, hasLength(3));
      for (final request in api.mutations) {
        expect(request.data, pending!.body);
        expect(request.headers['Idempotency-Key'], pending.idempotencyKey);
        expect(request.headers['X-Correlation-ID'], pending.correlationId);
      }
      expect(await api.journal.read(_session), isNull);
      expect(find.text('Transferencia exitosa'), findsOneWidget);
      expect(find.text('id-confirmado-por-fastapi'), findsOneWidget);

      router.go('/accounts');
      await tester.pumpAndSettle();
      expect(find.text(r'$4.900 COP'), findsOneWidget);
    },
  );

  testWidgets(
    'un rechazo definitivo termina el intento sin mostrar comprobante',
    (tester) async {
      final api = _OperationsApi(outcomes: [_Outcome.rejected]);
      await _open(tester, api, confirm: () async => true);
      await _quote(tester);
      await _confirm(tester);

      expect(find.text('Operación rechazada'), findsOneWidget);
      expect(find.text('Saldo insuficiente.'), findsOneWidget);
      expect(find.text('Reintentar operación'), findsNothing);
      expect(find.text('Transferencia exitosa'), findsNothing);
      expect(await api.journal.read(_session), isNull);
    },
  );

  testWidgets('un destino rechazado no llega a cotizar ni a ejecutarse', (
    tester,
  ) async {
    final api = _OperationsApi()..destinationRejected = true;
    await _open(
      tester,
      api,
      confirm: () async => throw StateError('Confirmación inesperada'),
    );
    await _quote(tester);
    expect(
      find.text('Cuenta destino no disponible en esta institución'),
      findsOneWidget,
    );
    expect(api.requests.map((r) => r.path), [
      '/accounts',
      '/accounts/1000000004/destination',
    ]);
  });

  for (final type in [
    FinancialOperationType.deposit,
    FinancialOperationType.withdrawal,
  ]) {
    testWidgets('${type.label} cotiza y confirma con el contrato de FastAPI', (
      tester,
    ) async {
      final api = _OperationsApi();
      var deviceConfirmations = 0;
      await _open(
        tester,
        api,
        type: type,
        confirm: () async {
          deviceConfirmations++;
          return true;
        },
      );
      await _quote(tester, transfer: false);
      expect(
        find.text('Cotización de ${type.label.toLowerCase()}'),
        findsOneWidget,
      );
      await _confirm(tester);
      expect(
        deviceConfirmations,
        type == FinancialOperationType.deposit ? 0 : 1,
      );
      expect(api.mutations.single.path, '/transactions/${type.endpoint}');
      expect(
        find.text(
          type == FinancialOperationType.deposit
              ? 'Depósito exitoso'
              : 'Retiro exitoso',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'si falla la autenticación del dispositivo el retiro no se envía',
    (tester) async {
      final api = _OperationsApi();
      await _open(
        tester,
        api,
        type: FinancialOperationType.withdrawal,
        confirm: () async => false,
      );
      await _quote(tester, transfer: false);
      await _confirm(tester);
      expect(
        find.text('Confirma con el bloqueo de tu dispositivo para continuar.'),
        findsOneWidget,
      );
      expect(api.mutations, isEmpty);
      expect(await api.journal.read(_session), isNull);
    },
  );

  test('una reapertura recupera el mismo cuerpo y claves solo para su usuario y banco', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final operation = ConfirmedOperation(
      const OperationDraft(
        type: FinancialOperationType.deposit,
        accountNumber: '1000000001',
        amount: '100.25',
      ),
    );
    await PendingOperationsStore(storage).save(_session, operation);

    final reopened = PendingOperationsStore(storage);
    final restored = await reopened.read(_session);
    expect(restored?.toJson(), operation.toJson());
    final otherBank = AuthSession(
      accessToken: 'other-token',
      tokenType: 'bearer',
      expiresAt: DateTime.utc(2100),
      userId: _session.userId,
      tenantId: 'caribe',
      role: _session.role,
      bankLabel: 'Cooperativa Caribe',
      email: _session.email,
    );
    expect(await reopened.read(otherBank), isNull);
    await reopened.clear(_session);
    expect(await reopened.read(_session), isNull);
  });
}
