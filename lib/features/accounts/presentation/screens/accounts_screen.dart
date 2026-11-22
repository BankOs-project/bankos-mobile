import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/bank_surface_card.dart';
import '../../../../core/theme/bank_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/session_account.dart';
import '../widgets/session_accounts_content.dart';

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
            Text('Tus cuentas', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            SessionAccountsContent(
              builder: (accounts) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  for (final account in accounts)
                    _AccountCard(
                      key: ValueKey(account.accountNumber),
                      account: account,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({super.key, required this.account});

  final SessionAccount account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = theme.extension<BankSurfaceColors>();
    final statusColor =
        brand?.onFill ??
        switch (account.status) {
          AccountStatus.active => colors.primary,
          AccountStatus.inactive => colors.onSurfaceVariant,
          AccountStatus.blocked => colors.error,
        };

    return BankSurfaceCard(
      child: ListTile(
        onTap: () => context.push(
          '/accounts/${Uri.encodeComponent(account.accountNumber)}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: (brand?.onFill ?? colors.primary).withValues(
            alpha: 0.12,
          ),
          foregroundColor: brand?.onFill ?? colors.primary,
          child: const Icon(Icons.account_balance_wallet_outlined),
        ),
        title: Text(
          formatAccountBalance(account.balanceUnits, account.currency),
          style: theme.textTheme.titleMedium?.copyWith(color: brand?.onFill),
        ),
        subtitle: Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(account.maskedNumber),
            Text(account.status.label, style: TextStyle(color: statusColor)),
          ],
        ),
      ),
    );
  }
}
