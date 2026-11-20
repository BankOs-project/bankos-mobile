import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/startup_intro_provider.dart';
import '../../features/auth/domain/models/public_bank.dart';
import '../../features/auth/presentation/screens/bank_selector_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/registration_screen.dart';
import '../../features/auth/presentation/screens/session_startup_screen.dart';
import '../../features/accounts/presentation/screens/main_shell_screen.dart';
import '../../features/accounts/presentation/screens/dashboard_screen.dart';
import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/operations/presentation/screens/operations_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/transactions/domain/models/transaction_models.dart';
import '../../features/transactions/presentation/screens/transfer_screen.dart';
import '../../features/transactions/presentation/screens/summary_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/session',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;
      final isBankEntry = location == '/login' || location == '/register';
      if (!ref.read(startupIntroProvider) ||
          auth.startup != SessionStartup.ready) {
        return location == '/session' ? null : '/session';
      }
      if (location == '/session') {
        return auth.isAuthenticated ? '/dashboard' : '/banks';
      }
      if (auth.isAuthenticated && (isBankEntry || location == '/banks')) {
        return '/dashboard';
      }
      if (!auth.isAuthenticated &&
          location != '/banks' &&
          (!isBankEntry || state.extra is! PublicBank)) {
        return '/banks';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/session',
        builder: (context, state) => const SessionStartupScreen(),
      ),
      GoRoute(
        path: '/banks',
        builder: (context, state) => const BankSelectorScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final bank = state.extra as PublicBank;
          return LoginScreen(key: ValueKey(bank.id), bank: bank);
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          final bank = state.extra as PublicBank;
          return RegistrationScreen(key: ValueKey(bank.id), bank: bank);
        },
      ),
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
          GoRoute(
            path: '/operations',
            builder: (context, state) => const OperationsScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/transactions/transfer',
        builder: (context, state) {
          final type = switch (state.uri.queryParameters['type']) {
            'deposit' => FinancialOperationType.deposit,
            'withdrawal' => FinancialOperationType.withdrawal,
            _ => FinancialOperationType.transfer,
          };
          return TransferScreen(key: ValueKey(type), initialType: type);
        },
      ),
      GoRoute(
        path: '/transactions/summary',
        builder: (context, state) => const SummaryScreen(),
      ),
    ],
  );
  ref.listen(
    authProvider.select((state) => (state.startup, state.isAuthenticated)),
    (_, _) => router.refresh(),
  );
  ref.listen(startupIntroProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
