import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/bank_logo.dart';
import '../widgets/dashboard_finances_section.dart';
import '../widgets/dashboard_quick_actions.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final profile = ref.watch(customerNameProvider);
    final customerName = profile.isLoading ? null : profile.asData?.value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BankLogo(logoUrl: session?.bankLogoUrl),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                session?.bankLabel ?? 'BankOs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
            tooltip: 'Abrir menú',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => context.push('/menu'),
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
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.18,
                        ),
                        foregroundColor: theme.colorScheme.primary,
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
              if (session != null) DashboardFinancesSection(session: session),
            ],
          ),
        ),
      ),
    );
  }
}
