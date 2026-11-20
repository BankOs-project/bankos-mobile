import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/session_account.dart';
import 'session_accounts_content.dart';

class DashboardKpiSection extends StatelessWidget {
  const DashboardKpiSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Resumen financiero', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        const SessionAccountsContent(builder: _BalanceCard.new),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ingresos, gastos y flujo neto'),
                SizedBox(height: 4),
                Text('Pendientes de datos del historial.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard(this.accounts);

  final List<SessionAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = <String, BigInt>{};
    for (final account in accounts) {
      totals.update(
        account.currency,
        (total) => total + account.balanceUnits,
        ifAbsent: () => account.balanceUnits,
      );
    }
    final currencies = totals.keys.toList()..sort();

    return Card(
      key: const Key('kpi_balance_card'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          gradient: AppTheme.surfaceGradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(width: 8),
                Expanded(child: Text('Saldo total por moneda')),
              ],
            ),
            for (final currency in currencies)
              Text(
                formatAccountBalance(totals[currency]!, currency),
                style: theme.textTheme.titleLarge,
              ),
          ],
        ),
      ),
    );
  }
}
