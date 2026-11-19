import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:bankos_mobile/features/transactions/presentation/screens/summary_screen.dart';
import 'package:bankos_mobile/features/transactions/presentation/screens/transfer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _buildTestApp({String initialLocation = '/transactions/transfer'}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/transactions/transfer',
        builder: (_, _) => const TransferScreen(),
      ),
      GoRoute(
        path: '/transactions/summary',
        builder: (_, _) => const SummaryScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (_, _) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Dashboard')),
      ),
      GoRoute(
        path: '/operations',
        builder: (_, _) => const Scaffold(body: Text('Operaciones')),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      theme: AppTheme.darkTheme,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets(
    'flujo completo: transferencia con PIN erróneo, huella visual, PIN 1234, comprobante e historial',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Ingresar llave destino y monto en COP.
      await tester.enterText(
        find.byKey(const Key('destination_key_field')),
        '@pedro.perez',
      );
      await tester.enterText(find.byKey(const Key('amount_field')), '75000');
      await tester.enterText(
        find.byKey(const Key('description_field')),
        'Pago prueba',
      );
      await tester.pumpAndSettle();

      // Verifica transparencia de comisión $0 COP.
      expect(find.text('\$0 COP'), findsOneWidget);

      // Abrir BottomSheet de confirmación.
      final reviewBtn = find.byKey(const Key('review_transfer_button'));
      await tester.ensureVisible(reviewBtn);
      await tester.tap(reviewBtn);
      await tester.pumpAndSettle();

      expect(find.text('Verifica tu envío'), findsOneWidget);

      // Probar pestaña visual de Huella.
      await tester.tap(find.text('Huella'));
      await tester.pumpAndSettle();
      expect(find.text('Huella no disponible aún'), findsOneWidget);

      // Volver a PIN.
      await tester.tap(find.text('Autorizar con PIN'));
      await tester.pumpAndSettle();

      // Probar PIN incorrecto (0000).
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('pin_key_0')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('PIN incorrecto. Intenta nuevamente.'), findsOneWidget);

      // Ingresar PIN correcto (1234).
      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.byKey(Key('pin_key_$digit')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Verifica llegada a SummaryScreen con comprobante real.
      expect(find.text('Transferencia exitosa'), findsOneWidget);
      expect(find.text('\$75.000 COP'), findsWidgets);
      expect(find.byKey(const Key('share_receipt_button')), findsOneWidget);

      // Ir al historial y comprobar que aparece la nueva transacción.
      final historyBtn = find.byKey(const Key('go_to_history_button'));
      await tester.ensureVisible(historyBtn);
      await tester.tap(historyBtn);
      await tester.pumpAndSettle();

      expect(find.text('Envío a @pedro.perez'), findsOneWidget);
      expect(find.text('A otra persona'), findsWidgets);

      // Filtrar por "Entre mis cuentas".
      await tester.tap(find.byKey(const Key('scope_filter_own')));
      await tester.pumpAndSettle();

      expect(find.text('Envío a @pedro.perez'), findsNothing);
      expect(find.text('Traslado entre mis cuentas'), findsOneWidget);

      // Filtrar por banco Davivienda (haciendo scroll horizontal si hace falta).
      final daviviendaChip = find.byKey(const Key('bank_filter_Davivienda'));
      await tester.ensureVisible(daviviendaChip);
      await tester.pumpAndSettle();
      await tester.tap(daviviendaChip);
      await tester.pumpAndSettle();

      expect(find.text('Movimientos · Davivienda'), findsOneWidget);
      expect(find.text('Traslado entre mis cuentas'), findsOneWidget);
    },
  );

  testWidgets(
    'flujo entre mis cuentas: descuenta origen, abona destino y crea comprobante propio',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Cambiar a "Entre mis cuentas".
      await tester.tap(find.byKey(const Key('scope_tab_ownAccounts')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('amount_field')), '100000');
      await tester.pumpAndSettle();

      final reviewBtn = find.byKey(const Key('review_transfer_button'));
      await tester.ensureVisible(reviewBtn);
      await tester.tap(reviewBtn);
      await tester.pumpAndSettle();

      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.byKey(Key('pin_key_$digit')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Transferencia exitosa'), findsOneWidget);
      expect(find.text('Entre mis cuentas'), findsWidgets);
      expect(find.text('\$100.000 COP'), findsWidgets);
    },
  );

  testWidgets(
    'flujo de depósito: abona saldo a cuenta seleccionada y emite comprobante de depósito',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Cambiar operación a Depósito.
      await tester.tap(find.byKey(const Key('op_tab_deposit')));
      await tester.pumpAndSettle();

      expect(find.text('Depositar Dinero'), findsOneWidget);
      expect(find.text('Cuenta destino (abono)'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('amount_field')), '150000');
      await tester.pumpAndSettle();

      final reviewBtn = find.byKey(const Key('review_transfer_button'));
      await tester.ensureVisible(reviewBtn);
      await tester.tap(reviewBtn);
      await tester.pumpAndSettle();

      expect(find.text('Resumen de Depósito'), findsOneWidget);

      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.byKey(Key('pin_key_$digit')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Depósito exitoso'), findsOneWidget);
      expect(find.text('\$150.000 COP'), findsWidgets);
    },
  );

  testWidgets(
    'demostración de idempotencia: simulación de fallo 504 y reintento con la misma llave',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('destination_key_field')),
        '3001234567',
      );
      await tester.enterText(find.byKey(const Key('amount_field')), '30000');
      await tester.pumpAndSettle();

      final reviewBtn = find.byKey(const Key('review_transfer_button'));
      await tester.ensureVisible(reviewBtn);
      await tester.tap(reviewBtn);
      await tester.pumpAndSettle();

      // Verificar sección de Idempotencia
      expect(find.text('Seguridad ACID & Idempotencia BankOS'), findsOneWidget);

      // Simular fallo de red
      await tester.tap(find.text('Simular fallo de red en vuelo'));
      await tester.pumpAndSettle();

      expect(
        find.text('Error 504: Fallo de Red Simulado en Vuelo'),
        findsOneWidget,
      );

      // Reintentar con la misma llave
      await tester.tap(
        find.text('Reintentar con la misma llave (Cero doble cobro)'),
      );
      await tester.pumpAndSettle();

      // Completar PIN
      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.byKey(Key('pin_key_$digit')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Transferencia exitosa'), findsOneWidget);
    },
  );
}
