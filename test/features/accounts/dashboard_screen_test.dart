import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/features/accounts/domain/models/dashboard_models.dart';
import 'package:bankos_mobile/features/accounts/presentation/providers/dashboard_providers.dart';
import 'package:bankos_mobile/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:bankos_mobile/features/accounts/presentation/screens/dashboard_screen.dart';
import 'package:bankos_mobile/features/accounts/presentation/screens/main_shell_screen.dart';

Widget _createTestableWidget({ProviderContainer? container}) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountsScreen(),
          ),
        ],
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: container ?? ProviderContainer(),
    child: MaterialApp.router(
      theme: AppTheme.darkTheme,
      routerConfig: router,
    ),
  );
}

void main() {
  group('DashboardScreen UI & Functional Flow Tests', () {
    testWidgets(
        'El slide horizontal de cuentas muestra nombre, dinero y número enmascarado',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // Verificar que el slider horizontal existe
      expect(find.byKey(const Key('dashboard_accounts_slider')), findsOneWidget);

      // La primera cuenta activa es Billetera Local (COP)
      expect(find.text('Billetera Local'), findsOneWidget);
      expect(find.text('**** 8821'), findsOneWidget);
      expect(find.textContaining('5.200.000'), findsOneWidget);

      // Deslizar horizontalmente para ver las demás cuentas del slide
      await tester.drag(
        find.byKey(const Key('dashboard_accounts_slider')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      // Al deslizar, las cuentas adicionales como Cuenta Principal se hacen visibles
      expect(find.text('Cuenta Principal'), findsOneWidget);
      expect(find.text('**** 4589'), findsOneWidget);
    });

    testWidgets(
        'Al tocar una tarjeta de cuenta en el slide, redirecciona a la sección de cuentas',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_createTestableWidget(container: container));
      await tester.pumpAndSettle();

      // Tocar la tarjeta de la cuenta visible Billetera Local **** 8821
      final cardFinder = find.byKey(const Key('account_card_**** 8821'));
      expect(cardFinder, findsOneWidget);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      // Verificar que redirigió a la pantalla de Cuentas Bancarias
      expect(find.text('Cuentas Bancarias'), findsOneWidget);

      // Verificar que selectedAccountProvider guardó la cuenta seleccionada
      expect(container.read(selectedAccountProvider), '**** 8821');

      // Verificar que en Cuentas aparece marcada como "Seleccionada"
      expect(find.text('Seleccionada'), findsOneWidget);
      expect(find.text('Opciones de Configuración'), findsOneWidget);
    });

    testWidgets(
        'Filtro de fechas de acción rápida actualiza los KPIs dinámicamente',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_createTestableWidget(container: container));
      await tester.pumpAndSettle();

      // Por defecto está en Mensual
      expect(find.byKey(const Key('kpi_balance_card')), findsOneWidget);
      expect(find.byKey(const Key('kpi_income_card')), findsOneWidget);
      expect(find.byKey(const Key('kpi_expenses_card')), findsOneWidget);

      final initialExpenses = container.read(dashboardKpisProvider).totalExpenses;

      // Cambiar a Diario mediante el chip de acción rápida
      final dailyChip = find.byKey(const Key('quick_filter_daily'));
      expect(dailyChip, findsOneWidget);
      await tester.tap(dailyChip);
      await tester.pumpAndSettle();

      // Verificar cambio de estado en el provider
      expect(container.read(dashboardDateFilterProvider),
          DashboardDateFilter.daily);
      final dailyExpenses = container.read(dashboardKpisProvider).totalExpenses;
      expect(dailyExpenses, lessThan(initialExpenses));

      // Cambiar a Anual mediante chip rápido
      final annualChip = find.byKey(const Key('quick_filter_annual'));
      expect(annualChip, findsOneWidget);
      await tester.tap(annualChip);
      await tester.pumpAndSettle();

      expect(container.read(dashboardDateFilterProvider),
          DashboardDateFilter.annual);
      final annualExpenses = container.read(dashboardKpisProvider).totalExpenses;
      expect(annualExpenses, greaterThan(initialExpenses));
    });

    testWidgets(
        'Botón desplegable de editar widgets muestra checks y conmuta visibilidad de gráficos',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_createTestableWidget(container: container));
      await tester.pumpAndSettle();

      // Por defecto se encuentran los 2 gráficos iniciales
      expect(find.byKey(const Key('chart_card_income_vs_expense')), findsOneWidget);
      expect(find.byKey(const Key('chart_card_expenses_by_category')), findsOneWidget);
      expect(find.byKey(const Key('chart_card_balance_evolution')), findsNothing);

      // Abrir el botón desplegable de edición de gráficos
      final dropdownButton =
          find.byKey(const Key('dashboard_charts_dropdown_button'));
      expect(dropdownButton, findsOneWidget);
      await tester.tap(dropdownButton);
      await tester.pumpAndSettle();

      // Verificar opciones en el desplegable
      expect(find.byKey(const Key('chart_option_incomeVsExpense')), findsOneWidget);
      expect(find.byKey(const Key('chart_option_balanceEvolution')), findsOneWidget);

      // Tocar opción "Evolución del Balance" para activarla
      await tester.tap(find.byKey(const Key('chart_option_balanceEvolution')));
      await tester.pumpAndSettle();

      // Ahora el gráfico de evolución del balance debe estar visible en el dashboard
      expect(find.byKey(const Key('chart_card_balance_evolution')), findsOneWidget);
    });
  });
}
