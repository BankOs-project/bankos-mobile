import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bank_surface_card.dart';
import '../../../../core/theme/bank_theme.dart';

import '../../../auth/domain/models/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/domain/models/financial_summary.dart';
import '../../domain/models/session_account.dart';
import '../providers/dashboard_finances_provider.dart';
import '../providers/session_accounts_provider.dart';

class DashboardFinancesSection extends ConsumerWidget {
  const DashboardFinancesSection({super.key, required this.session});

  final AuthSession session;

  Future<void> _pickPeriod(
    BuildContext context,
    WidgetRef ref,
    FinancialPeriod current,
  ) async {
    final selection = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: DateTimeRange(
        start: current.firstDay,
        end: current.lastDay,
      ),
      helpText: 'Selecciona el período',
      cancelText: 'Cancelar',
      saveText: 'Aplicar',
      confirmText: 'Aplicar',
      fieldStartLabelText: 'Fecha inicial',
      fieldEndLabelText: 'Fecha final',
      errorInvalidRangeText:
          'La fecha final debe ser igual o posterior al inicio.',
    );
    if (selection != null &&
        context.mounted &&
        identical(ref.read(activeSessionProvider), session)) {
      ref
          .read(dashboardFinanceFiltersProvider.notifier)
          .selectPeriod(FinancialPeriod(selection.start, selection.end));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsProvider = sessionAccountsProvider(session);
    final accounts = ref.watch(accountsProvider);
    final filter = ref.watch(dashboardFinanceFiltersProvider);
    final filters = ref.read(dashboardFinanceFiltersProvider.notifier);
    final visibleAccounts = accounts.value;
    final number =
        visibleAccounts == null ||
            visibleAccounts.any(
              (account) => account.accountNumber == filter.account,
            )
        ? filter.account
        : null;
    final period = filter.period;
    final summaryProvider = financialSummaryProvider((
      session: session,
      start: period.startUtc,
      end: period.endUtc,
      accountNumber: number,
    ));
    final summary = ref.watch(summaryProvider);
    final text = Theme.of(context).textTheme;

    ref.listen(accountsProvider, (_, next) {
      if (!identical(ref.read(activeSessionProvider), session)) return;
      final selected = ref.read(dashboardFinanceFiltersProvider).account;
      final list = next.asData?.value;
      if (selected != null &&
          list != null &&
          !list.any((account) => account.accountNumber == selected)) {
        filters.selectAccount(null);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text('Finanzas', style: text.titleLarge),
        if (visibleAccounts != null)
          DropdownButtonFormField<String>(
            key: ValueKey(number),
            initialValue: number ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Cuenta'),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Todas las cuentas'),
              ),
              for (final account in visibleAccounts)
                DropdownMenuItem(
                  value: account.accountNumber,
                  child: Text('${account.maskedNumber} · ${account.currency}'),
                ),
            ],
            onChanged: visibleAccounts.isEmpty
                ? null
                : (value) => filters.selectAccount(value == '' ? null : value),
          ),
        if (visibleAccounts == null && accounts.isLoading)
          const Text('Cargando cuentas…'),
        if (accounts.hasError)
          Row(
            children: [
              const Expanded(child: Text('No pudimos cargar tus cuentas.')),
              TextButton(
                onPressed: () => ref.invalidate(accountsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        Text(
          'Del ${_formatDay(period.firstDay)} al ${_formatDay(period.lastDay)} · Bogotá',
          style: text.bodyMedium,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (label, months) in [
              ('1 mes', 1),
              ('1 trimestre', 3),
              ('1 año', 12),
            ])
              ChoiceChip(
                label: Text(label),
                selected: period.months == months,
                onSelected: (_) => filters.selectMonths(months),
              ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () => _pickPeriod(context, ref, period),
          icon: const Icon(Icons.date_range_outlined),
          label: const Text('Elegir fechas'),
        ),
        summary.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Cargando Finanzas',
            ),
          ),
          error: (_, _) => Card(
            child: ListTile(
              title: const Text('No pudimos cargar Finanzas.'),
              subtitle: TextButton(
                onPressed: () => ref.invalidate(summaryProvider),
                child: const Text('Reintentar Finanzas'),
              ),
            ),
          ),
          data: (totals) => _FinanceTotals(totals),
        ),
      ],
    );
  }

  String _formatDay(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _FinanceTotals extends StatelessWidget {
  const _FinanceTotals(this.totals);

  final List<FinancialCurrencySummary> totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final brand = theme.extension<BankSurfaceColors>();
    final noFlows = totals.every(
      (total) => total.income == BigInt.zero && total.expenses == BigInt.zero,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (totals.isEmpty)
          const Text('Aún no tienes cuentas en este banco.')
        else if (noFlows)
          const Text('Sin ingresos ni gastos en este período.'),
        for (final (title, subtitle, amount) in [
          (
            'Saldo actual',
            'Disponible ahora',
            (FinancialCurrencySummary total) => total.availableBalance,
          ),
          ('Ingresos', null, (FinancialCurrencySummary total) => total.income),
          ('Gastos', null, (FinancialCurrencySummary total) => total.expenses),
        ])
          BankSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    title,
                    style: text.titleMedium?.copyWith(color: brand?.onFill),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: text.bodySmall?.copyWith(color: brand?.onFill),
                    ),
                  if (totals.isEmpty) const Text('—'),
                  for (final total in totals)
                    Text(
                      formatAccountBalance(amount(total), total.currency),
                      style: text.titleLarge?.copyWith(color: brand?.onFill),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
