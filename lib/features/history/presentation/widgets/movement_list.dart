import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../accounts/domain/models/session_account.dart';
import '../../../transactions/domain/models/transaction_models.dart';
import '../providers/history_provider.dart';

class MovementList extends ConsumerWidget {
  const MovementList({
    super.key,
    required this.query,
    required this.owned,
    this.onBeforeRetry,
    this.accountDetail = false,
  });

  final HistoryQuery query;
  final Set<String> owned;
  final VoidCallback? onBeforeRetry;
  final bool accountDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = historyProvider(query);
    final history = ref.watch(provider);
    final data = history.isLoading ? null : history.asData?.value;

    return SliverMainAxisGroup(
      slivers: [
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
                  child: _MovementCard(
                    movement: movement,
                    owned: owned,
                    onTap: movement.isConfirmedTransfer
                        ? () => context.push(
                            '/history/receipt',
                            extra: (session: query.session, receipt: movement),
                          )
                        : null,
                  ),
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
                onBeforeRetry?.call();
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
          title: const Text('No pudimos cargar los movimientos.'),
          subtitle: TextButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ),
      );
    }

    final hasFilters =
        query.search.isNotEmpty ||
        query.type != null ||
        query.scope != null ||
        (query.accountNumber != null && !accountDetail);
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
  const _MovementCard({
    required this.movement,
    required this.owned,
    this.onTap,
  });

  final OperationReceipt movement;
  final Set<String> owned;
  final VoidCallback? onTap;

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right_rounded),
                ],
              ),
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
      ),
    );
  }
}
