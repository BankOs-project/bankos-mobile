import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/domain/models/session_account.dart';
import '../../../accounts/presentation/providers/session_accounts_provider.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/domain/models/transaction_models.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: SafeArea(
        child: session == null
            ? const SizedBox.shrink()
            : _SessionHistory(key: ObjectKey(session), session: session),
      ),
    );
  }
}

class _SessionHistory extends ConsumerStatefulWidget {
  const _SessionHistory({super.key, required this.session});

  final AuthSession session;

  @override
  ConsumerState<_SessionHistory> createState() => _SessionHistoryState();
}

class _SessionHistoryState extends ConsumerState<_SessionHistory> {
  final _searchField = TextEditingController();
  Timer? _searchDelay;
  String _search = '';
  String? _accountNumber;
  FinancialOperationType? _type;
  HistoryScope? _scope;

  @override
  void dispose() {
    _searchDelay?.cancel();
    _searchField.dispose();
    super.dispose();
  }

  void _searchChanged(String text) {
    _searchDelay?.cancel();
    final search = text.trim().toLowerCase();
    if (search == _search) return;
    _searchDelay = Timer(const Duration(milliseconds: 300), () {
      setState(() => _search = search);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsProvider = sessionAccountsProvider(widget.session);
    final accountState = ref.watch(accountsProvider);
    final accounts = accountState.value ?? const <SessionAccount>[];
    final owned = accounts.map((account) => account.accountNumber).toSet();
    final query = (
      session: widget.session,
      type: _type,
      accountNumber: _accountNumber,
      scope: _scope,
      search: _search,
    );
    final provider = historyProvider(query);
    final history = ref.watch(provider);
    final data = history.isLoading ? null : history.asData?.value;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                TextField(
                  key: const Key('history_search'),
                  controller: _searchField,
                  onChanged: _searchChanged,
                  decoration: InputDecoration(
                    labelText: 'Buscar por cuenta o referencia',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () {
                              _searchDelay?.cancel();
                              _searchField.clear();
                              setState(() => _search = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      key: const Key('op_filter_all'),
                      label: const Text('Todas'),
                      selected: _type == null,
                      onSelected: (_) => setState(() => _type = null),
                    ),
                    for (final type in FinancialOperationType.values)
                      ChoiceChip(
                        key: ValueKey('op_filter_${type.name}'),
                        label: Text(type.label),
                        selected: _type == type,
                        onSelected: (selected) => setState(() {
                          _type = selected ? type : null;
                          if (_type != null &&
                              _type != FinancialOperationType.transfer) {
                            _scope = null;
                          }
                        }),
                      ),
                  ],
                ),
                if (accounts.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(('history_account', _accountNumber)),
                    initialValue: owned.contains(_accountNumber)
                        ? _accountNumber
                        : null,
                    isExpanded: true,
                    hint: const Text('Todas las cuentas'),
                    decoration: const InputDecoration(labelText: 'Cuenta'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todas las cuentas'),
                      ),
                      for (final account in accounts)
                        DropdownMenuItem(
                          value: account.accountNumber,
                          child: Text(
                            '${account.maskedNumber} · ${account.currency}',
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _accountNumber = value),
                  ),
                  if (_type == null || _type == FinancialOperationType.transfer)
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          key: const Key('scope_filter_own'),
                          label: const Text('Entre mis cuentas'),
                          selected: _scope == HistoryScope.ownAccounts,
                          onSelected: (selected) => setState(() {
                            _scope = selected ? HistoryScope.ownAccounts : null;
                          }),
                        ),
                        FilterChip(
                          key: const Key('scope_filter_other'),
                          label: const Text('Con terceros'),
                          selected: _scope == HistoryScope.otherAccounts,
                          onSelected: (selected) => setState(() {
                            _scope = selected
                                ? HistoryScope.otherAccounts
                                : null;
                          }),
                        ),
                      ],
                    ),
                ] else if (accountState.hasError)
                  TextButton(
                    onPressed: () => ref.invalidate(accountsProvider),
                    child: const Text('Reintentar filtros por cuenta'),
                  ),
              ],
            ),
          ),
        ),
        if (data != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: data.items.length,
              itemBuilder: (context, index) {
                final movement = data.items[index];
                return Padding(
                  key: ValueKey(movement.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MovementCard(movement: movement, owned: owned),
                );
              },
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverToBoxAdapter(
            child: _historyFooter(
              history,
              data,
              onRetry: () {
                if (_scope != null && accountState.hasError) {
                  ref.invalidate(accountsProvider);
                }
                ref.invalidate(provider);
              },
              onMore: ref.read(provider.notifier).loadMore,
            ),
          ),
        ),
      ],
    );
  }

  Widget _historyFooter(
    AsyncValue<HistoryData> history,
    HistoryData? data, {
    required VoidCallback onRetry,
    required VoidCallback onMore,
  }) {
    if (history.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Cargando movimientos',
        ),
      );
    }
    if (history.hasError || data == null) {
      return Card(
        child: ListTile(
          title: const Text('No pudimos cargar el historial.'),
          subtitle: TextButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ),
      );
    }

    final hasFilters =
        _search.isNotEmpty ||
        _type != null ||
        _accountNumber != null ||
        _scope != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (data.items.isEmpty && !data.loadingMore && !data.loadMoreFailed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              data.nextSkip != null
                  ? 'Sin coincidencias en las páginas consultadas.'
                  : hasFilters
                  ? 'No hay movimientos que coincidan con los filtros.'
                  : 'Todavía no hay movimientos.',
              textAlign: TextAlign.center,
            ),
          ),
        if (data.loadMoreFailed)
          const Text(
            'No pudimos cargar más movimientos.',
            textAlign: TextAlign.center,
          ),
        if (data.loadingMore)
          const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Cargando más movimientos',
            ),
          )
        else if (data.nextSkip != null)
          OutlinedButton(
            onPressed: onMore,
            child: Text(
              data.loadMoreFailed
                  ? 'Reintentar página'
                  : data.items.isEmpty
                  ? 'Buscar en más movimientos'
                  : 'Cargar más movimientos',
            ),
          ),
      ],
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement, required this.owned});

  final OperationReceipt movement;
  final Set<String> owned;

  @override
  Widget build(BuildContext context) {
    final isTransfer = movement.type == FinancialOperationType.transfer;
    final sourceIsOwn = owned.contains(movement.sourceAccount);
    final destinationIsOwn = owned.contains(movement.destinationAccount);
    final incoming = isTransfer && !sourceIsOwn && destinationIsOwn;
    final rejected = movement.status == 'ERROR';
    final title = switch ((
      isTransfer && !rejected,
      sourceIsOwn,
      destinationIsOwn,
    )) {
      (true, false, true) => 'Transferencia recibida',
      (true, true, true) => 'Transferencia entre mis cuentas',
      (true, true, false) => 'Transferencia enviada',
      _ => movement.type.label,
    };
    final amount = incoming && !rejected
        ? formatAccountBalance(movement.received, movement.destinationCurrency)
        : formatAccountBalance(movement.amount, movement.sourceCurrency);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(amount, style: Theme.of(context).textTheme.titleMedium),
            Text(
              MaterialLocalizations.of(context)
                  .formatCompactDate(movement.createdAt.toLocal()),
            ),
            Wrap(
              spacing: 12,
              children: [
                if (movement.sourceAccount case final account?)
                  Text('Origen ${maskAccountNumber(account)}'),
                if (movement.destinationAccount case final account?)
                  Text('Destino ${maskAccountNumber(account)}'),
              ],
            ),
            Text(
              'Referencia ${movement.id}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (rejected) const Chip(label: Text('Rechazada')),
                if (movement.fee > BigInt.zero)
                  Chip(
                    label: Text(
                      'Comisión ${formatAccountBalance(movement.fee, movement.sourceCurrency)}',
                    ),
                  ),
                if (!rejected &&
                    movement.sourceCurrency != movement.destinationCurrency)
                  Chip(
                    label: Text(
                      'Conversión ${movement.sourceCurrency} → ${movement.destinationCurrency} · ${movement.rate} · ${formatAccountBalance(movement.received, movement.destinationCurrency)}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
