import 'package:bankos_mobile/core/network/dio_provider.dart';
import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:bankos_mobile/features/auth/domain/models/auth_models.dart';
import 'package:bankos_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:bankos_mobile/features/transactions/data/repositories/pending_operations_store.dart';
import 'package:bankos_mobile/features/transactions/domain/models/transaction_models.dart';
import 'package:bankos_mobile/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:bankos_mobile/features/transactions/presentation/screens/summary_screen.dart';
import 'package:bankos_mobile/features/transactions/presentation/screens/transfer_mode_screen.dart';
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

enum _Outcome {
  success,
  networkLoss,
  inProgress,
  rejected,
  quoteStale,
  quoteExpired,
}

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
  var quoteCount = 0;
  var _mode = 'SAME_BANK';
  var _quotedAmount = '100.25';

  void _request(RequestOptions request, RequestInterceptorHandler handler) {
    requests.add(request);
    void resolve(Object? data, [int status = 200]) => handler.resolve(
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
    if (path == '/banks') {
      expectSync(request.headers['Authorization'], isNull);
      resolve([
        {'bank_id': 'andino-id', 'name': 'Banco Andino'},
        {'bank_id': 'nu-id', 'name': 'Nu'},
        {'bank_id': 'caribe-id', 'name': 'Cooperativa Caribe'},
      ]);
      return;
    }
    expectSync(request.headers['Authorization'], 'Bearer test-token');
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
      final amount = body['amount']!;
      _quotedAmount = amount;
      if (transfer) _mode = body['transfer_mode']!;
      expect(
        body['destination_account_number'],
        !transfer
            ? isNull
            : _mode == 'OTHER_BANK'
            ? isIn(['1000000004', '1000000067'])
            : '1000000004',
      );
      if (transfer) {
        expect(
          body['destination_bank_id'],
          _mode == 'OTHER_BANK' ? isIn(['nu-id', 'caribe-id']) : isNull,
        );
      }
      expect(request.headers.containsKey('Idempotency-Key'), isFalse);
      resolve({
        'operation_type': type,
        'original_amount': amount,
        if (transfer) ...{
          'transfer_mode': _mode,
          'quote_id': 'cotizacion-${++quoteCount}',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
          if (_mode == 'OTHER_BANK')
            'recipient': {
              'bank_name': body['destination_bank_id'] == 'nu-id'
                  ? 'Nu'
                  : 'Cooperativa Caribe',
              'masked_holder_name': 'M*** R***',
              'account_last_four': body['destination_account_number']!
                  .substring(6),
            },
        },
        'source_currency': 'COP',
        'destination_currency': transfer ? 'USD' : 'COP',
        'amount_to_debit': transfer
            ? (_mode == 'OTHER_BANK'
                  ? (double.parse(amount) + 2.005).toStringAsFixed(4)
                  : amount)
            : type == 'DEPOSIT'
            ? '0'
            : '100.25',
        'fee_calculated': transfer && _mode == 'OTHER_BANK'
            ? '2.0050'
            : '0.0000',
        'exchange_rate_applied': transfer ? '0.000250' : '1',
        'final_amount_to_receive': transfer
            ? (double.parse(amount) * 0.000250).toStringAsFixed(4)
            : amount,
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
          ? {'quote_id': 'cotizacion-$quoteCount'}
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
      case _Outcome.quoteStale:
        reject(409, 'QUOTE_STALE', 'Cambió la cotización');
      case _Outcome.quoteExpired:
        reject(409, 'QUOTE_EXPIRED', 'Venció la cotización');
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
            FinancialOperationType.transfer =>
              _mode == 'OTHER_BANK' ? null : '1000000004',
            FinancialOperationType.deposit => '1000000001',
            FinancialOperationType.withdrawal => null,
          },
          'original_amount': _quotedAmount,
          'original_currency': 'COP',
          if (type == FinancialOperationType.transfer) ...{
            'transfer_mode': _mode,
            if (_mode == 'OTHER_BANK')
              'transfer_reference': 'referencia-interbancaria',
          },
          'fee_charged':
              type == FinancialOperationType.transfer && _mode == 'OTHER_BANK'
              ? '2.0050'
              : '0.0000',
          'converted_amount': type == FinancialOperationType.transfer
              ? (double.parse(_quotedAmount) * 0.000250).toStringAsFixed(4)
              : _quotedAmount,
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
  bool startOnSelector = false,
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
        builder: (_, state) {
          final mode = state.uri.queryParameters['mode'];
          if (startOnSelector && mode == null) {
            return const TransferModeScreen();
          }
          return TransferScreen(
            key: ValueKey(mode),
            initialType: type,
            transferMode: mode == 'other-bank'
                ? TransferMode.otherBank
                : TransferMode.sameBank,
          );
        },
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
  final button = find.byKey(const Key('confirm_operation_button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Otro banco usa el directorio y reintenta la cotización confirmada',
    (tester) async {
      final api = _OperationsApi(
        outcomes: [_Outcome.networkLoss, _Outcome.success],
      );
      var confirmations = 0;
      await _open(
        tester,
        api,
        startOnSelector: true,
        confirm: () async => ++confirmations > 1,
      );

      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      expect(find.text('Mismo banco'), findsOneWidget);
      expect(find.text('Próximamente'), findsOneWidget);
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, 'Bre-B')).enabled,
        isFalse,
      );
      await tap(find.text('Otro banco'));
      expect(find.text('Transferencia simulada a otro banco.'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      final bank = find.byKey(const Key('destination_bank_field'));
      await tap(bank);
      expect(find.text('Banco Andino'), findsNothing);
      await tap(find.text('Nu').last);
      await _quote(tester);
      expect(find.text('M*** R***'), findsOneWidget);
      expect(find.text('•••• 0004'), findsOneWidget);
      expect(find.text(r'$102,255 COP'), findsOneWidget);
      expect(find.text(r'$2,005 COP'), findsOneWidget);
      await _confirm(tester);
      expect(api.mutations, isEmpty);
      expect(await api.journal.read(_session), isNull);

      await tap(bank);
      await tap(find.text('Cooperativa Caribe').last);
      final destination = find.byKey(const Key('destination_account_field'));
      expect(
        tester.widget<TextFormField>(destination).controller?.text,
        isEmpty,
      );
      await tester.enterText(destination, '1000000067');
      await tester.enterText(find.byKey(const Key('amount_field')), '125');
      await tap(find.byKey(const Key('review_transfer_button')));
      expect(find.text('•••• 0067'), findsOneWidget);
      final quotes = api.requests
          .where((request) => request.path == '/transactions/quote')
          .toList();
      expect(quotes.map((request) => request.data), [
        containsPair('destination_bank_id', 'nu-id'),
        allOf(
          containsPair('destination_bank_id', 'caribe-id'),
          containsPair('destination_account_number', '1000000067'),
          containsPair('amount', '125'),
        ),
      ]);
      expect(
        api.requests.where((request) => request.path.endsWith('/destination')),
        isEmpty,
      );
      await _confirm(tester);
      expect(find.text('Operación pendiente'), findsOneWidget);
      final pending = (await api.journal.read(_session))!;
      expect(pending.body, {'quote_id': 'cotizacion-2'});
      await tap(find.text('Reintentar operación'));
      expect(api.mutations, hasLength(2));
      for (final request in api.mutations) {
        expect(request.data, pending.body);
        expect(request.headers['Idempotency-Key'], pending.idempotencyKey);
        expect(request.headers['X-Correlation-ID'], pending.correlationId);
      }
      expect(confirmations, 2);
      expect(find.text('Transferencia exitosa'), findsOneWidget);
      expect(find.text('referencia-interbancaria'), findsOneWidget);
    },
  );

  testWidgets(
    'una cotización vencida o cambiada exige cotizar y confirmar de nuevo',
    (tester) async {
      final api = _OperationsApi(
        outcomes: [
          _Outcome.quoteExpired,
          _Outcome.quoteStale,
          _Outcome.success,
        ],
      );
      var confirmations = 0;
      await _open(
        tester,
        api,
        confirm: () async {
          confirmations++;
          return true;
        },
      );
      for (final message in [
        'La cotización venció.',
        'La cotización cambió.',
      ]) {
        await _quote(tester);
        await _confirm(tester);
        expect(find.textContaining(message), findsOneWidget);
        expect(find.text('Reintentar operación'), findsNothing);
        expect(await api.journal.read(_session), isNull);
      }
      await _quote(tester);
      expect(find.text('Confirmar con el dispositivo'), findsOneWidget);
      await _confirm(tester);
      expect(confirmations, 3);
      expect(api.mutations.map((request) => request.data), [
        {'quote_id': 'cotizacion-1'},
        {'quote_id': 'cotizacion-2'},
        {'quote_id': 'cotizacion-3'},
      ]);
      expect(
        api.mutations
            .map((request) => request.headers['Idempotency-Key'])
            .toSet(),
        hasLength(3),
      );
      expect(find.text('Transferencia exitosa'), findsOneWidget);
    },
  );

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
      expect(find.text('Banco Andino'), findsOneWidget);
      expect(find.text('C*** d***'), findsOneWidget);
      expect(find.text('•••• 0004'), findsOneWidget);
      expect(find.text('Cliente destino'), findsNothing);
      expect(find.text(r'$100,25 COP'), findsNWidgets(2));
      expect(find.text(r'$0 COP'), findsOneWidget);
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
