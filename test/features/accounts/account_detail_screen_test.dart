import 'package:bankos_mobile/core/network/dio_provider.dart';
import 'package:bankos_mobile/core/router/app_router.dart';
import 'package:bankos_mobile/features/auth/data/repositories/session_store.dart';
import 'package:bankos_mobile/features/auth/domain/models/auth_models.dart';
import 'package:bankos_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:bankos_mobile/features/history/presentation/widgets/movement_list.dart';
import 'package:bankos_mobile/features/transactions/domain/models/transaction_models.dart';
import 'package:bankos_mobile/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:bankos_mobile/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Cuentas abre el detalle B2 y sincroniza estados y operaciones', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureSessionStore(FlutterSecureStorage());
    await store.save(
      AuthSession(
        accessToken: 'test-token',
        tokenType: 'bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        userId: 'client',
        tenantId: 'bank',
        role: 'cliente',
        bankLabel: 'Uno',
        email: 'cliente@example.com',
      ),
    );
    String? clipboard;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    const first = '3200000001';
    const second = '3200000002';
    const blocked = '3200000003';
    const adminInactive = '3200000004';
    const foreign = '3200000005';
    final deadline = DateTime.now().toUtc().add(const Duration(hours: 24));
    var firstStatus = 'ACTIVE';
    var cooledDown = false;
    var listings = 0;
    var details = 0;
    final changes = <String>[];
    final movementPages = <Object?>[];

    Map<String, Object?> account(String number) => {
      'account_number': number,
      'tenant_id': 'bank',
      'owner_id': number == foreign ? 'another-user' : 'client',
      'currency': number == second ? 'USD' : 'COP',
      'balance': '105.50',
      'status': switch (number) {
        first => firstStatus,
        blocked => 'BLOCKED',
        adminInactive => 'INACTIVE',
        _ => 'ACTIVE',
      },
      if (number == first) 'account_type': 'Ahorros',
      'requires_admin_reactivation': number == adminInactive,
      'can_deactivate_at': number == first && cooledDown
          ? deadline.toIso8601String()
          : null,
    };

    Map<String, dynamic> movement(
      String id,
      String amount, {
      String status = 'SUCCESS',
    }) => {
      'id': id,
      'tenant_id': 'bank',
      'operation_type': 'TRANSFER',
      'status': status,
      'created_at': '2026-11-20T12:00:00Z',
      'source_account_number': second,
      'destination_account_number': first,
      'original_amount': amount,
      'original_currency': 'USD',
      'converted_amount': amount,
      'destination_currency': 'COP',
      'fee_charged': '0',
      'exchange_rate_applied': '1',
      'idempotency_key': 'id-$id',
      'correlation_id': 'trace-$id',
    };

    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        mobileSecureStorageProvider.overrideWithValue(null),
        activeReceiptProvider.overrideWithValue(
          OperationReceipt.fromJson(
            movement('transferencia-mas-reciente', '99'),
            FinancialOperationType.transfer,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(dioProvider)
        .interceptors
        .add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              if (request.path != '/banks') {
                expectSync(
                  request.headers['Authorization'],
                  'Bearer test-token',
                );
              }
              void respond(Object? data, [String? code]) {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: request,
                    statusCode: 200,
                    data: {
                      'success': true,
                      'internal_code': code,
                      'data': data,
                    },
                  ),
                );
              }

              switch (request.path) {
                case '/auth/me':
                  respond({
                    'tenant_id': 'bank',
                    'id': 'client',
                    'is_active': true,
                    'role': 'cliente',
                    'full_name': 'Cliente',
                  });
                case '/banks':
                  respond([]);
                case '/accounts':
                  listings++;
                  respond({
                    'items': [
                      for (final number in [
                        first,
                        second,
                        blocked,
                        adminInactive,
                      ])
                        account(number),
                    ],
                    'total': 4,
                  });
                case '/transactions/summary':
                  respond({
                    'account_number': request.queryParameters['account_number'],
                    'start_date': request.queryParameters['start_date'],
                    'end_date': request.queryParameters['end_date'],
                    'currencies': [],
                  });
                case '/transactions':
                  final number = request.queryParameters['account_number'];
                  expectSync(number, isNot(foreign));
                  final offset = request.queryParameters['skip'];
                  if (number == first) movementPages.add(offset);
                  respond({
                    'skip': offset,
                    'total': number == null ? 3 : (number == first ? 2 : 0),
                    'items': [
                      if (number == first)
                        movement(
                          'movimiento-$offset',
                          offset == 0 ? '5' : '17',
                        ),
                      if (number == null) ...[
                        movement('movimiento-0', '5'),
                        movement('movimiento-1', '17'),
                        movement('rechazado', '33', status: 'ERROR'),
                      ],
                    ],
                  });
                case '/accounts/$first/deactivate':
                case '/accounts/$first/reactivate':
                  expectSync(request.method, 'PATCH');
                  expectSync(request.data, isNull);
                  final reactivate = request.path.endsWith('/reactivate');
                  changes.add(reactivate ? 'reactivate' : 'deactivate');
                  firstStatus = reactivate ? 'ACTIVE' : 'INACTIVE';
                  cooledDown = reactivate;
                  respond(
                    account(first),
                    reactivate ? 'ACCOUNT_REACTIVATED' : 'ACCOUNT_DEACTIVATED',
                  );
                default:
                  expectSync(request.method, 'GET');
                  final number = request.path.split('/').last;
                  expectSync(
                    number,
                    isIn([first, second, blocked, adminInactive, foreign]),
                  );
                  if (number == first) details++;
                  respond(account(number), 'ACCOUNT_DETAIL_FETCHED');
              }
            },
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const BankOsApp()),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go('/accounts');
    await tester.pumpAndSettle();

    Future<void> tap(Finder target) async {
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tap(find.text('•••• 0001'));
    expect(find.text('Detalle de cuenta'), findsOneWidget);
    expect(find.text(first), findsOneWidget);
    expect(find.text(r'$105,5 COP'), findsOneWidget);
    expect(find.text('Tipo Ahorros'), findsOneWidget);
    expect(find.text('Moneda COP'), findsOneWidget);
    expect(find.text('ACTIVA'), findsOneWidget);
    await tap(find.byTooltip('Copiar número de cuenta'));
    expect(clipboard, first);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(find.text('Cargar más movimientos'));
    expect(movementPages, [0, 1]);
    expect(find.text('Referencia movimiento-1'), findsOneWidget);
    await tap(find.text('Referencia movimiento-1'));
    expect(find.text('Comprobante'), findsOneWidget);
    expect(find.text('movimiento-1'), findsOneWidget);
    expect(find.text(r'$17.00 USD'), findsWidgets);
    await tap(find.byTooltip('Volver'));
    expect(find.text('Detalle de cuenta'), findsOneWidget);
    expect(find.text('Referencia movimiento-1'), findsOneWidget);
    expect(movementPages, [0, 1]);

    await tap(find.text('Desactivar cuenta'));
    await tap(find.text('Cancelar'));
    expect(changes, isEmpty);
    final previousListings = listings;
    final previousDetails = details;
    await tap(find.text('Desactivar cuenta'));
    await tap(find.text('Confirmar'));
    expect(changes, ['deactivate']);
    expect(details, greaterThan(previousDetails));
    expect(find.text('INACTIVA'), findsOneWidget);
    expect(find.text('Activar cuenta'), findsOneWidget);
    expect(find.text('Referencia movimiento-1'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(listings, greaterThan(previousListings));
    expect(find.widgetWithText(ListTile, '•••• 0001'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, '•••• 0001'),
        matching: find.text('INACTIVA'),
      ),
      findsOneWidget,
    );

    router.go('/transactions/transfer?type=deposit');
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdown.initialValue, second);
    await tap(find.text('•••• 0002 · USD'));
    expect(find.text('•••• 0001 · COP'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    router.go('/accounts/$first');
    await tester.pumpAndSettle();
    expect(find.text('Referencia movimiento-0'), findsOneWidget);
    await tap(find.text('Activar cuenta'));
    await tap(find.text('Confirmar'));
    expect(changes, ['deactivate', 'reactivate']);
    expect(find.text('ACTIVA'), findsOneWidget);
    final cooldown = find.textContaining('Podrás desactivar esta cuenta');
    expect(cooldown, findsOneWidget);
    final localizations = MaterialLocalizations.of(tester.element(cooldown));
    expect(
      tester.widget<Text>(cooldown).data,
      contains(localizations.formatShortDate(deadline.toLocal())),
    );
    expect(find.text('Desactivar cuenta'), findsNothing);

    router.go('/accounts/$blocked');
    await tester.pumpAndSettle();
    expect(find.text('BLOQUEADA'), findsOneWidget);
    expect(find.text('El banco debe atender este bloqueo.'), findsOneWidget);
    expect(find.text('Activar cuenta'), findsNothing);
    expect(find.text('Tipo Ahorros'), findsNothing);

    router.go('/accounts/$adminInactive');
    await tester.pumpAndSettle();
    expect(find.text('INACTIVA'), findsOneWidget);
    expect(find.text('El banco debe reactivar esta cuenta.'), findsOneWidget);
    expect(find.text('Activar cuenta'), findsNothing);

    router.go('/operations');
    await tester.pumpAndSettle();
    expect(find.text('Comprobante'), findsNothing);
    expect(find.text('Volver al Dashboard'), findsNothing);
    await tap(find.text('Movimientos'));
    expect(find.widgetWithText(AppBar, 'Movimientos'), findsOneWidget);
    final search = find.byType(TextField);
    await tester.enterText(search, 'movimiento');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tap(find.text('Referencia movimiento-0'));
    expect(find.text('movimiento-0'), findsOneWidget);
    expect(find.text('movimiento-1'), findsNothing);
    expect(find.text('transferencia-mas-reciente'), findsNothing);
    expect(find.text('Compartir comprobante'), findsOneWidget);
    await tap(find.byTooltip('Copiar resumen'));
    expect(clipboard, contains('Referencia: movimiento-0'));
    await tap(find.byTooltip('Volver'));
    expect(tester.widget<TextField>(search).controller?.text, 'movimiento');
    await tap(find.text('Referencia movimiento-1'));
    expect(find.text('movimiento-1'), findsOneWidget);
    expect(find.text('movimiento-0'), findsNothing);
    await tap(find.byTooltip('Copiar resumen'));
    expect(clipboard, contains('Referencia: movimiento-1'));
    await tap(find.byTooltip('Volver'));
    await tester.enterText(search, '');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tap(find.text('Referencia rechazado'));
    expect(find.text('Rechazada'), findsOneWidget);
    expect(find.text('Comprobante'), findsNothing);

    router.go('/accounts/$foreign');
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar la cuenta.'), findsOneWidget);
    expect(find.byType(MovementList), findsNothing);
    await container.read(authProvider.notifier).logout();
    await tester.pumpAndSettle();
  });
}
