import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/dashboard_charts_section.dart';
import '../widgets/dashboard_kpi_section.dart';
import '../widgets/dashboard_quick_actions.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final customerName = ref.watch(customerNameProvider).asData?.value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session?.bankLabel ?? 'BankOs',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No tienes notificaciones pendientes'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.18,
                        ),
                        foregroundColor: AppTheme.primaryColor,
                        child: const Icon(Icons.person_outline_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '¡Hola, ${customerName ?? session?.email ?? 'cliente'}!',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const DashboardQuickActions(),
              const SizedBox(height: 24),
              Text(
                'Datos financieros de demostración',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              const DashboardKpiSection(),
              const SizedBox(height: 24),
              const DashboardChartsSection(),
            ],
          ),
        ),
      ),
    );
  }
}
