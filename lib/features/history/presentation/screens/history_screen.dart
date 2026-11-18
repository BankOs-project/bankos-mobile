import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../transactions/domain/models/transaction_models.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';
import '../../../transactions/presentation/widgets/transaction_badges.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(filteredTransactionsProvider);
    final banks = ref.watch(availableHistoryBanksProvider);
    final selectedBank = ref.watch(historyBankFilterProvider);
    final selectedScope = ref.watch(historyScopeFilterProvider);
    final searchQuery = ref.watch(historySearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            tooltip: 'Nueva transferencia',
            icon: const Icon(Icons.send_rounded, size: 20),
            onPressed: () => context.go('/transactions/transfer'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const Key('history_search_field'),
                controller: _searchController,
                onChanged: (value) {
                  ref
                      .read(historySearchQueryProvider.notifier)
                      .setQuery(value);
                },
                decoration: InputDecoration(
                  hintText: 'Buscar por banco, persona, llave o referencia...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(historySearchQueryProvider.notifier)
                                .setQuery('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            _BankFilterBar(
              banks: banks,
              selectedBank: selectedBank,
              onSelected: (bank) {
                ref.read(historyBankFilterProvider.notifier).setBank(bank);
              },
            ),
            const SizedBox(height: 8),
            _ScopeFilterBar(
              selectedScope: selectedScope,
              onSelected: (scope) {
                ref.read(historyScopeFilterProvider.notifier).setScope(scope);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    selectedBank == null
                        ? 'Todos los movimientos'
                        : 'Movimientos · $selectedBank',
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${transactions.length} ${transactions.length == 1 ? 'registro' : 'registros'}',
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: transactions.isEmpty
                  ? _EmptyHistoryView(
                      hasFilters: selectedBank != null ||
                          selectedScope != null ||
                          searchQuery.isNotEmpty,
                      onClearFilters: () {
                        _searchController.clear();
                        ref
                            .read(historySearchQueryProvider.notifier)
                            .setQuery('');
                        ref
                            .read(historyBankFilterProvider.notifier)
                            .setBank(null);
                        ref
                            .read(historyScopeFilterProvider.notifier)
                            .setScope(null);
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: transactions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final record = transactions[index];
                        return HistoryTransactionCard(
                          record: record,
                          focusedBank: selectedBank,
                          onTap: () {
                            ref
                                .read(selectedTransactionProvider.notifier)
                                .select(record);
                            context.push('/transactions/summary');
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankFilterBar extends StatelessWidget {
  final List<String> banks;
  final String? selectedBank;
  final ValueChanged<String?> onSelected;

  const _BankFilterBar({
    required this.banks,
    required this.selectedBank,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          FilterChip(
            key: const Key('bank_filter_all'),
            label: const Text('Todos los bancos'),
            selected: selectedBank == null,
            onSelected: (_) => onSelected(null),
          ),
          ...banks.map((bank) {
            final isSelected = selectedBank == bank;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                key: Key('bank_filter_$bank'),
                avatar: Icon(
                  Icons.account_balance_rounded,
                  size: 14,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.tertiaryColor,
                ),
                label: Text(bank),
                selected: isSelected,
                onSelected: (_) => onSelected(isSelected ? null : bank),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ScopeFilterBar extends StatelessWidget {
  final TransferScope? selectedScope;
  final ValueChanged<TransferScope?> onSelected;

  const _ScopeFilterBar({
    required this.selectedScope,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ChoiceChip(
            key: const Key('scope_filter_all'),
            label: const Text('Todos los tipos'),
            selected: selectedScope == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('scope_filter_own'),
            avatar: const Icon(
              Icons.swap_horiz_rounded,
              size: 15,
              color: AppTheme.secondaryColor,
            ),
            label: const Text('Entre mis cuentas'),
            selected: selectedScope == TransferScope.ownAccounts,
            onSelected: (_) => onSelected(
              selectedScope == TransferScope.ownAccounts
                  ? null
                  : TransferScope.ownAccounts,
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('scope_filter_external'),
            avatar: const Icon(
              Icons.person_outline_rounded,
              size: 15,
              color: AppTheme.infoColor,
            ),
            label: const Text('A otra persona'),
            selected: selectedScope == TransferScope.externalPerson,
            onSelected: (_) => onSelected(
              selectedScope == TransferScope.externalPerson
                  ? null
                  : TransferScope.externalPerson,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de movimiento histórico con ruta bancaria clara (`Origen -> Destino`)
/// e identificador pequeño (`Entre mis cuentas` / `A otra persona`).
class HistoryTransactionCard extends StatelessWidget {
  final TransactionRecord record;
  final String? focusedBank;
  final VoidCallback onTap;

  const HistoryTransactionCard({
    super.key,
    required this.record,
    required this.focusedBank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isIncomingForView;
    final bool isInternalUnfocused;

    if (record.direction == MovementDirection.internalTransfer) {
      if (focusedBank != null) {
        isIncomingForView =
            record.destinationBankName.toLowerCase() ==
            focusedBank!.toLowerCase();
        isInternalUnfocused = false;
      } else {
        isIncomingForView = false;
        isInternalUnfocused = true;
      }
    } else {
      isIncomingForView = record.direction.isIncoming;
      isInternalUnfocused = false;
    }

    final Color amountColor;
    final IconData leadingIcon;
    final String amountPrefix;

    if (isInternalUnfocused) {
      amountColor = AppTheme.secondaryColor;
      leadingIcon = Icons.swap_horiz_rounded;
      amountPrefix = '';
    } else if (isIncomingForView) {
      amountColor = AppTheme.successColor;
      leadingIcon = Icons.arrow_downward_rounded;
      amountPrefix = '+ ';
    } else {
      amountColor = AppTheme.errorColor;
      leadingIcon = Icons.arrow_upward_rounded;
      amountPrefix = '- ';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.outlineColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: amountColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(leadingIcon, color: amountColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${CurrencyFormatter.formatShortDate(record.createdAt)} · ${record.description}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$amountPrefix${CurrencyFormatter.format(record.amount, record.currency, showCurrencyCode: false)}',
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      record.currency,
                      style: const TextStyle(
                        color: AppTheme.textMutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BankRoutePill(
                  sourceBank: record.sourceBankName,
                  destinationBank: record.destinationBankName,
                  compact: true,
                ),
                TransferScopeBadge(scope: record.scope),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistoryView extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClearFilters;

  const _EmptyHistoryView({
    required this.hasFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppTheme.tertiaryColor,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters
                  ? 'No encontramos movimientos con esos filtros'
                  : 'Aún no tienes movimientos registrados',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Prueba limpiando la búsqueda o cambiando el banco seleccionado.'
                  : 'Cuando hagas transferencias aparecerán aquí automáticamente.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 13,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: onClearFilters,
                child: const Text('Limpiar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
