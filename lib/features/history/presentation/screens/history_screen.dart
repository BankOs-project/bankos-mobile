import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bank_surface_card.dart';
import '../../../../core/theme/bank_theme.dart';
import '../../../accounts/domain/models/session_account.dart';
import '../../../accounts/presentation/providers/session_accounts_provider.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/domain/models/transaction_models.dart';
import '../providers/history_provider.dart';
import '../widgets/movement_list.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
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
    final theme = Theme.of(context);
    final brand = theme.extension<BankSurfaceColors>();
    final query = (
      session: widget.session,
      type: _type,
      accountNumber: _accountNumber,
      scope: _scope,
      search: _search,
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverToBoxAdapter(
            child: BankSurfaceCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ChipTheme(
                  data: theme.chipTheme.copyWith(
                    selectedColor: Color.alphaBlend(
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                      theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
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
                          decoration: const InputDecoration(
                            labelText: 'Cuenta',
                          ),
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
                        if (_type == null ||
                            _type == FinancialOperationType.transfer)
                          Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                key: const Key('scope_filter_own'),
                                label: const Text('Entre mis cuentas'),
                                selected: _scope == HistoryScope.ownAccounts,
                                onSelected: (selected) => setState(() {
                                  _scope = selected
                                      ? HistoryScope.ownAccounts
                                      : null;
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
                          style: TextButton.styleFrom(
                            foregroundColor: brand?.onFill,
                          ),
                          onPressed: () => ref.invalidate(accountsProvider),
                          child: const Text('Reintentar filtros por cuenta'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        MovementList(
          query: query,
          owned: owned,
          onBeforeRetry: () {
            if (_scope != null && accountState.hasError) {
              ref.invalidate(accountsProvider);
            }
          },
        ),
      ],
    );
  }
}
