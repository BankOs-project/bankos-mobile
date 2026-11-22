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
import '../../features/accounts/presentation/screens/account_detail_screen.dart';
import '../../features/operations/presentation/screens/operations_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/settings/presentation/screens/dashboard_menu_screen.dart';
import '../../features/settings/presentation/screens/general_settings_screen.dart';
import '../../features/transactions/domain/models/transaction_models.dart';
import '../../features/transactions/presentation/screens/transfer_screen.dart';
import '../../features/transactions/presentation/screens/transfer_mode_screen.dart';
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
      GoRoute(
        path: '/menu',
        builder: (context, state) => const DashboardMenuScreen(),
        routes: [
          GoRoute(
            path: 'settings',
            builder: (context, state) => const GeneralSettingsScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) =>
            MainShellScreen(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountsScreen(),
            routes: [
              GoRoute(
                path: ':accountNumber',
                builder: (context, state) {
                  final number = state.pathParameters['accountNumber']!;
                  return AccountDetailScreen(
                    key: ValueKey(number),
                    number: number,
                  );
                },
              ),
            ],
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
          final mode = switch (state.uri.queryParameters['mode']) {
            'same-bank' => TransferMode.sameBank,
            'other-bank' => TransferMode.otherBank,
            _ => null,
          };
          if (type == FinancialOperationType.transfer && mode == null) {
            return const TransferModeScreen();
          }
          return TransferScreen(
            key: ValueKey((type, mode)),
            initialType: type,
            transferMode: mode ?? TransferMode.sameBank,
          );
        },
      ),
      GoRoute(
        path: '/transactions/summary',
        builder: (context, state) => const SummaryScreen(),
      ),
      GoRoute(
        path: '/history/receipt',
        redirect: (context, state) {
          final selection = state.extra;
          if (selection is! HistoricalReceipt ||
              !identical(selection.session, ref.read(activeSessionProvider)) ||
              !selection.receipt.isConfirmedTransfer) {
            return '/history';
          }
          return null;
        },
        builder: (context, state) =>
            SummaryScreen(historicalReceipt: state.extra as HistoricalReceipt),
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
