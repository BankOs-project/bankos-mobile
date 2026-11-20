import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/features/accounts/presentation/providers/session_accounts_provider.dart';
import 'package:bankos_mobile/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:bankos_mobile/features/accounts/presentation/screens/dashboard_screen.dart';
import 'package:bankos_mobile/features/auth/domain/models/auth_models.dart';
import 'package:bankos_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Cuentas y Dashboard muestran listas vacías sin inventar saldos',
    (tester) async {
      final session = AuthSession(
        accessToken: 'test-token',
        tokenType: 'bearer',
        expiresAt: DateTime.utc(2100),
        userId: 'user-1',
        tenantId: 'bank-1',
        role: 'cliente',
        bankLabel: 'Banco Andino',
        email: 'juan@example.com',
      );
      final container = ProviderContainer(
        overrides: [
          activeSessionProvider.overrideWithValue(session),
          customerNameProvider.overrideWith((ref) => 'Juan'),
          sessionAccountsProvider(session).overrideWith((ref) => []),
        ],
      );
      addTearDown(container.dispose);

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
      expect(find.byKey(const Key('kpi_balance_card')), findsNothing);
      expect(find.text('Pendientes de datos del historial.'), findsOneWidget);
    },
  );
}
