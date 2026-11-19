import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (session != null) ...[
              Text(session.bankLabel, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
            ],
            Text(
              'Catálogo de demostración',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            const _ProductCard(
              icon: Icons.savings_outlined,
              title: 'Ahorros',
              description: 'Cuentas para guardar y administrar tu dinero.',
            ),
            const SizedBox(height: 12),
            const _ProductCard(
              icon: Icons.request_quote_outlined,
              title: 'Créditos',
              description: 'Opciones de financiación y préstamos.',
            ),
            const SizedBox(height: 12),
            const _ProductCard(
              icon: Icons.credit_card_rounded,
              title: 'Tarjetas',
              description: 'Tarjetas de débito y crédito para tus compras.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
          foregroundColor: theme.colorScheme.primary,
          child: Icon(icon),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(description),
      ),
    );
  }
}
