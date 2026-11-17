import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/accounts/presentation/screens/main_shell_screen.dart';
import '../../features/accounts/presentation/screens/dashboard_screen.dart';
import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/operations/presentation/screens/operations_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/transactions/presentation/screens/transfer_screen.dart';
import '../../features/transactions/presentation/screens/summary_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
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
        builder: (context, state) => const TransferScreen(),
      ),
      GoRoute(
        path: '/transactions/summary',
        builder: (context, state) => const SummaryScreen(),
      ),
    ],
  );
});
