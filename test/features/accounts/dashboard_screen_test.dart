import 'dart:async';

import 'package:bankos_mobile/core/network/dio_provider.dart';
import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/features/accounts/domain/models/session_account.dart';
import 'package:bankos_mobile/features/accounts/presentation/providers/dashboard_finances_provider.dart';
import 'package:bankos_mobile/features/accounts/presentation/providers/session_accounts_provider.dart';
import 'package:bankos_mobile/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:bankos_mobile/features/accounts/presentation/screens/dashboard_screen.dart';
import 'package:bankos_mobile/features/auth/domain/models/auth_models.dart';
import 'package:bankos_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:bankos_mobile/features/transactions/domain/models/transaction_models.dart';
import 'package:bankos_mobile/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _session = AuthSession(
  accessToken: 'test-token',
  tokenType: 'bearer',
  expiresAt: DateTime.utc(2100),
  userId: 'user-1',
  tenantId: 'bank-1',
  role: 'cliente',
  bankLabel: 'Banco Andino',
  email: 'juan@example.com',
);

Response<Map<String, dynamic>> _summaryResponse(
  RequestOptions request,
  List<Map<String, String>> currencies,
) => Response(
  requestOptions: request,
  statusCode: 200,
  data: {
    'success': true,
    'internal_code': 'FINANCIAL_SUMMARY_FETCHED',
    'data': {
      'account_number': request.queryParameters['account_number'],
      'start_date': request.queryParameters['start_date'],
      'end_date': request.queryParameters['end_date'],
      'currencies': currencies,
    },
  },
);

void main() {
  test(
    'los presets acotan meses cortos y el período de Bogotá es inclusivo',
    () {
      final month = FinancialPeriod.trailingMonths(
        DateTime.utc(2026, 3, 31),
        1,
      );
      expect(month.firstDay, DateTime.utc(2026, 2, 28));
      expect(month.startUtc, DateTime.utc(2026, 2, 28, 5));
      expect(month.endUtc, DateTime.utc(2026, 4, 1, 4, 59, 59, 999, 999));
      final year = FinancialPeriod.trailingMonths(
        DateTime.utc(2028, 2, 29),
        12,
      );
      expect(year.firstDay, DateTime.utc(2027, 2, 28));
    },
  );

  testWidgets(
    'Cuentas y Dashboard muestran listas vacías sin inventar saldos',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          activeSessionProvider.overrideWithValue(_session),
          customerNameProvider.overrideWith((ref) => 'Juan'),
          sessionAccountsProvider(_session).overrideWith((ref) => []),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(dioProvider)
          .interceptors
          .add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                expectSync(request.path, '/transactions/summary');
                handler.resolve(_summaryResponse(request, []));
              },
            ),
          );

      Future<void> show(Widget screen) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(theme: AppTheme.darkTheme, home: screen),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(const AccountsScreen());
      expect(find.text('Aún no tienes cuentas en este banco.'), findsOneWidget);

      await show(const DashboardScreen());
      expect(find.text('Aún no tienes cuentas en este banco.'), findsOneWidget);
      expect(find.text('Finanzas'), findsOneWidget);
      expect(find.text('Saldo actual'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(3));
    },
  );

  testWidgets(
    'Finanzas filtra, reintenta y se refresca al confirmar un depósito',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dateRequests = <Map<String, dynamic>>[];
      final pending = Completer<void>();
      var deposited = false;
      final appearance = ValueNotifier(AppTheme.darkTheme);
      addTearDown(appearance.dispose);
      final container = ProviderContainer(
        overrides: [
          activeSessionProvider.overrideWithValue(_session),
          mobileSecureStorageProvider.overrideWithValue(null),
          customerNameProvider.overrideWith((ref) => 'Juan'),
          sessionAccountsProvider(_session).overrideWith(
            (ref) => [
              for (final (number, currency) in [
                ('3200000001', 'COP'),
                ('3200000002', 'USD'),
              ])
                SessionAccount(
                  accountNumber: number,
                  currency: currency,
                  balanceUnits: BigInt.zero,
                  status: AccountStatus.active,
                ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(dioProvider)
          .interceptors
          .add(
            InterceptorsWrapper(
              onRequest: (request, handler) async {
                expectSync(
                  request.headers['Authorization'],
                  'Bearer test-token',
                );
                if (request.path == '/transactions/deposit') {
                  deposited = true;
                  handler.resolve(
                    Response<Map<String, dynamic>>(
                      requestOptions: request,
                      statusCode: 201,
                      data: {
                        'success': true,
                        'data': <String, dynamic>{
                          'id': 'confirmed-deposit',
                          'tenant_id': _session.tenantId,
                          'operation_type': 'DEPOSIT',
                          'status': 'SUCCESS',
                          'created_at': '2026-11-20T12:00:00Z',
                          'destination_account_number': '3200000001',
                          'original_amount': '250.0000',
                          'original_currency': 'COP',
                          'converted_amount': '250.0000',
                          'destination_currency': 'COP',
                          'fee_charged': '0.0000',
                          'exchange_rate_applied': '1',
                          'idempotency_key': request.headers['Idempotency-Key'],
                          'correlation_id': request.headers['X-Correlation-ID'],
                        },
                      },
                    ),
                  );
                  return;
                }
                expectSync(request.path, '/transactions/summary');
                final query = request.queryParameters;
                dateRequests.add(Map.of(query));
                if (dateRequests.length == 1) {
                  await pending.future;
                  handler.reject(
                    DioException(
                      requestOptions: request,
                      type: DioExceptionType.connectionError,
                    ),
                  );
                  return;
                }
                final historical =
                    DateTime.parse(query['start_date'] as String).year == 2020;
                handler.resolve(
                  _summaryResponse(request, [
                    {
                      'currency': 'COP',
                      'available_balance': deposited ? '750.7500' : '500.7500',
                      'income': historical ? '0' : (deposited ? '300' : '50'),
                      'expenses': historical ? '0' : '20',
                    },
                    if (!query.containsKey('account_number'))
                      {
                        'currency': 'USD',
                        'available_balance': '12.1250',
                        'income': '8',
                        'expenses': '2',
                      },
                  ]),
                );
              },
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ValueListenableBuilder(
            valueListenable: appearance,
            builder: (context, theme, child) =>
                MaterialApp(theme: theme, home: child),
            child: const DashboardScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.bySemanticsLabel('Cargando Finanzas'), findsOneWidget);
      expect(find.textContaining('Bogotá'), findsOneWidget);
      expect(dateRequests.single.containsKey('account_number'), isFalse);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar Finanzas.'), findsOneWidget);

      Future<void> tap(String label) async {
        final target = find.text(label).last;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tap('Reintentar Finanzas');
      expect(find.text(r'$500,75 COP'), findsOneWidget);
      expect(find.text(r'$12.125 USD'), findsOneWidget);
      expect(find.text(r'$50 COP'), findsOneWidget);
      expect(find.text(r'$20 COP'), findsOneWidget);
      await tap('Todas las cuentas');
      await tap('•••• 0001 · COP');
      expect(dateRequests.last['account_number'], '3200000001');
      expect(find.text(r'$12.125 USD'), findsNothing);
      expect(find.text(r'$500,75 COP'), findsOneWidget);
      final startMonth = dateRequests.last['start_date'];
      await tap('1 trimestre');
      final startQuarter = dateRequests.last['start_date'];
      await tap('1 año');
      expect(
        dateRequests.last['start_date'],
        isNot(anyOf(startMonth, startQuarter)),
      );
      expect(startMonth, isNot(startQuarter));

      await tap('Elegir fechas');
      final dialog = find.byType(DateRangePickerDialog);
      final localizations = MaterialLocalizations.of(tester.element(dialog));
      await tester.tap(find.byTooltip(localizations.inputDateModeButtonLabel));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '11/01/2020');
      await tester.enterText(fields.at(1), '11/03/2020');
      await tap('Aplicar');
      expect(dateRequests.last, {
        'account_number': '3200000001',
        'start_date': '2020-11-01T05:00:00.000Z',
        'end_date': '2020-11-04T04:59:59.999999Z',
      });
      expect(
        find.text('Del 01/11/2020 al 03/11/2020 · Bogotá'),
        findsOneWidget,
      );
      expect(
        find.text('Sin ingresos ni gastos en este período.'),
        findsOneWidget,
      );
      expect(find.text(r'$500,75 COP'), findsOneWidget);

      final ready = await container.read(operationsProvider.future);
      expect(ready.pending, isNull);
      expect(container.read(operationsProvider).asData, isNotNull);
      expect(container.read(activeSessionProvider), same(_session));
      final beforeOperation = dateRequests.length;
      final operation = container
          .read(operationsProvider.notifier)
          .submit(
            _session,
            const OperationDraft(
              type: FinancialOperationType.deposit,
              accountNumber: '3200000001',
              amount: '250',
            ),
          );
      await tester.pumpAndSettle();
      await operation;
      expect(deposited, isTrue);
      expect(container.read(activeReceiptProvider)?.id, 'confirmed-deposit');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(dateRequests, hasLength(beforeOperation + 1));
      expect(find.text(r'$750,75 COP'), findsOneWidget);
      expect(
        find.text('Sin ingresos ni gastos en este período.'),
        findsOneWidget,
      );
      expect(dateRequests[dateRequests.length - 2], dateRequests.last);
      final beforeTheme = dateRequests.length;
      appearance.value = AppTheme.lightTheme;
      await tester.pumpAndSettle();
      expect(dateRequests, hasLength(beforeTheme));
      expect(find.text(r'$750,75 COP'), findsOneWidget);
      expect(
        find.text('Del 01/11/2020 al 03/11/2020 · Bogotá'),
        findsOneWidget,
      );
      await tap('1 mes');
      expect(find.text(r'$300 COP'), findsOneWidget);
      expect(
        find.text('Sin ingresos ni gastos en este período.'),
        findsNothing,
      );
    },
  );
}
