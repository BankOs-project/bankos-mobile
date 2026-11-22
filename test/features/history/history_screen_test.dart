import 'dart:async';

import 'package:bankos_mobile/core/network/dio_provider.dart';
import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/features/auth/domain/models/auth_models.dart';
import 'package:bankos_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:bankos_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:bankos_mobile/features/transactions/domain/models/transaction_models.dart';
import 'package:bankos_mobile/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

AuthSession _session(String bank) => AuthSession(
  accessToken: 'token-$bank',
  tokenType: 'bearer',
  expiresAt: DateTime.utc(2100),
  userId: 'user-$bank',
  tenantId: bank,
  role: 'cliente',
  bankLabel: bank,
  email: 'cliente@$bank.example',
);

final _andino = _session('andino');
final _caribe = _session('caribe');
final _sessionProvider = StateProvider<AuthSession>((ref) => _andino);
final _receiptProvider = StateProvider<OperationReceipt?>((ref) => null);
const _owned = '1000000001';
const _otherOwned = '1000000002';

Map<String, dynamic> _record(
  String id, {
  String bank = 'andino',
  String type = 'TRANSFER',
  String? source = '1000000009',
  String? destination = _owned,
}) => {
  'id': id,
  'tenant_id': bank,
  'operation_type': type,
  'status': 'SUCCESS',
  'created_at': '2026-11-19T10:20:00Z',
  'source_account_number': source,
  'destination_account_number': destination,
  'original_amount': '100.2500',
  'original_currency': type == 'TRANSFER' ? 'USD' : 'COP',
  'fee_charged': type == 'TRANSFER' ? '2.0050' : '0.0000',
  'converted_amount': type == 'TRANSFER' ? '401000.2500' : '100.2500',
  'destination_currency': 'COP',
  'exchange_rate_applied': type == 'TRANSFER' ? '4000.002494' : '1',
  'idempotency_key': 'idempotency-$id',
  'correlation_id': 'correlation-$id',
};

typedef _PageHandler =
    FutureOr<({List<Map<String, dynamic>> items, int total})> Function(
      RequestOptions request,
    );

class _HistoryApi {
  _HistoryApi(_PageHandler page) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          void resolve(Map<String, dynamic> data) => handler.resolve(
            Response(
              requestOptions: request,
              data: {'success': true, 'data': data},
            ),
          );
          final token = request.headers['Authorization'];
          final bank = switch (token) {
            'Bearer token-andino' => 'andino',
            'Bearer token-caribe' => 'caribe',
            _ => throw StateError('Token inesperado'),
          };
          if (request.path == '/accounts') {
            final numbers = bank == 'andino'
                ? [_owned, _otherOwned]
                : ['2000000001'];
            resolve({
              'total': numbers.length,
              'items': [
                for (final number in numbers)
                  {
                    'tenant_id': bank,
                    'owner_id': 'user-$bank',
                    'account_number': number,
                    'balance': '0.0000',
                    'currency': 'COP',
                    'status': 'ACTIVE',
                  },
              ],
            });
            return;
          }
          expect(request.path, '/transactions');
          requests.add(request);
          try {
            final result = await page(request);
            resolve({
              'items': result.items,
              'total': result.total,
              'skip': request.queryParameters['skip'],
              'limit': request.queryParameters['limit'],
            });
          } on DioException catch (error) {
            handler.reject(error);
          }
        },
      ),
    );
  }

  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
  final requests = <RequestOptions>[];
  List<Object?> get offsets =>
      requests.map((r) => r.queryParameters['skip']).toList();
}

Future<ProviderContainer> _open(WidgetTester tester, _HistoryApi api) async {
  tester.view.physicalSize = const Size(390, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(api.dio.close);
  final container = ProviderContainer(
    overrides: [
      activeSessionProvider.overrideWith((ref) => ref.watch(_sessionProvider)),
      activeReceiptProvider.overrideWith((ref) => ref.watch(_receiptProvider)),
      dioProvider.overrideWithValue(api.dio),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const HistoryScreen(),
      ),
    ),
  );
  return container;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'la búsqueda puede encontrar coincidencias en una página posterior',
    (tester) async {
      final api = _HistoryApi(
        (request) => (
          items: [
            _record(
              request.queryParameters['skip'] == 0 ? 'primera' : 'buscada',
            ),
          ],
          total: 2,
        ),
      );
      await _open(tester, api);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('history_search')),
        'buscada',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(
        find.text('Sin coincidencias en las páginas consultadas.'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Buscar en más movimientos'));
      expect(api.offsets, [0, 0, 1]);
      expect(find.text('Referencia buscada'), findsOneWidget);
    },
  );

  testWidgets(
    'conserva el tipo de transferencia, muestra FX y deduplica páginas',
    (tester) async {
      final incoming = _record('entrada');
      final initial =
          Completer<({List<Map<String, dynamic>> items, int total})>();
      final api = _HistoryApi((request) {
        if (request.queryParameters['operation_type'] == 'TRANSFER') {
          return (items: [incoming], total: 1);
        }
        if (request.queryParameters['skip'] == 0) return initial.future;
        return (
          items: [
            incoming,
            _record(
              'retiro',
              type: 'WITHDRAWAL',
              source: _owned,
              destination: null,
            ),
          ],
          total: 4,
        );
      });
      await _open(tester, api);
      await tester.pump();
      expect(find.bySemanticsLabel('Cargando movimientos'), findsOneWidget);

      initial.complete((
        items: [
          incoming,
          _record('deposito', type: 'DEPOSIT', source: null),
        ],
        total: 4,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Transferencia recibida'), findsOneWidget);
      expect(find.text(r'$401.000,25 COP'), findsOneWidget);
      expect(find.text(r'Comisión $2.005 USD'), findsOneWidget);
      expect(
        find.textContaining('Conversión USD → COP · 4000.002494'),
        findsOneWidget,
      );

      await _tap(tester, find.text('Cargar más movimientos'));
      expect(api.offsets, [0, 2]);
      expect(
        find.byKey(const ValueKey('entrada'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Referencia retiro'), findsOneWidget);
      expect(find.text('Cargar más movimientos'), findsNothing);

      await _tap(tester, find.byKey(const Key('op_filter_transfer')));
      expect(api.offsets, [0, 2, 0]);
      expect(api.requests.last.queryParameters['operation_type'], 'TRANSFER');
      expect(find.text('Referencia retiro'), findsNothing);
    },
  );

  testWidgets(
    'reintenta fallo inicial y fallo de página desde el mismo offset',
    (tester) async {
      var initialFailed = false;
      var pageFailed = false;
      final api = _HistoryApi((request) {
        final skip = request.queryParameters['skip'];
        if (skip == 0 && !initialFailed) {
          initialFailed = true;
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        if (skip == 1 && !pageFailed) {
          pageFailed = true;
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        return (items: [_record('movimiento-$skip')], total: 2);
      });
      await _open(tester, api);
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar los movimientos.'), findsOneWidget);
      await _tap(tester, find.text('Reintentar'));
      await _tap(tester, find.text('Cargar más movimientos'));

      expect(find.text('No pudimos cargar más movimientos.'), findsOneWidget);
      expect(find.text('Referencia movimiento-0'), findsOneWidget);
      await _tap(tester, find.text('Reintentar página'));
      expect(api.offsets, [0, 0, 1, 1]);
      expect(find.text('Referencia movimiento-1'), findsOneWidget);
    },
  );

  testWidgets(
    'al cambiar de tenant cancela páginas anteriores y reinicia filtros',
    (tester) async {
      final latePage =
          Completer<({List<Map<String, dynamic>> items, int total})>();
      final newPage =
          Completer<({List<Map<String, dynamic>> items, int total})>();
      final api = _HistoryApi((request) {
        if (request.headers['Authorization'] == 'Bearer token-caribe') {
          expect(request.queryParameters['skip'], 0);
          expect(request.queryParameters['operation_type'], isNull);
          return newPage.future;
        }
        return request.queryParameters['skip'] == 0
            ? (items: [_record('solo-andino')], total: 2)
            : latePage.future;
      });
      final container = await _open(tester, api);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('op_filter_transfer')));
      await tester.tap(find.text('Cargar más movimientos'));
      await tester.pump();
      final oldRequest = api.requests.last;

      container.read(_sessionProvider.notifier).state = _caribe;
      await tester.pump();
      await tester.pump();
      expect(find.text('Referencia solo-andino'), findsNothing);
      expect(oldRequest.cancelToken?.isCancelled, isTrue);

      newPage.complete((items: <Map<String, dynamic>>[], total: 0));
      latePage.complete((items: [_record('respuesta-tardia')], total: 2));
      await tester.pumpAndSettle();
      expect(find.text('Todavía no hay movimientos.'), findsOneWidget);
      expect(find.text('Referencia respuesta-tardia'), findsNothing);
    },
  );

  testWidgets('una confirmación reinicia la página conservando los filtros', (
    tester,
  ) async {
    final confirmed = _record('confirmado', type: 'DEPOSIT', source: null);
    var updated = false;
    final api = _HistoryApi(
      (_) => updated
          ? (items: [confirmed], total: 1)
          : (items: <Map<String, dynamic>>[], total: 0),
    );
    final container = await _open(tester, api);
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('op_filter_deposit')));
    updated = true;
    container.read(_receiptProvider.notifier).state = OperationReceipt.fromJson(
      confirmed,
      FinancialOperationType.deposit,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(api.offsets, [0, 0, 0]);
    expect(api.requests.last.queryParameters['operation_type'], 'DEPOSIT');
    expect(find.text('Referencia confirmado'), findsOneWidget);
  });

  testWidgets('conserva filtro por cuentas propias y búsqueda por referencia', (
    tester,
  ) async {
    final api = _HistoryApi(
      (_) => (
        items: [
          _record('externa'),
          _record('propia', source: _otherOwned),
        ],
        total: 2,
      ),
    );
    await _open(tester, api);
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('scope_filter_own')));
    expect(find.text('Referencia propia'), findsOneWidget);
    expect(find.text('Referencia externa'), findsNothing);
    await _tap(tester, find.byKey(const Key('scope_filter_other')));
    expect(find.text('Referencia externa'), findsOneWidget);
    expect(find.text('Referencia propia'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('history_search')),
      'sin-coincidencia',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      find.text('No hay movimientos que coincidan con los filtros.'),
      findsOneWidget,
    );
    expect(api.offsets, [0, 0, 0, 0]);
  });
}
