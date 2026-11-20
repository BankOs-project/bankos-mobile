import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../accounts/domain/models/session_account.dart';
import '../../../accounts/presentation/providers/bottom_nav_provider.dart';
import '../../../accounts/presentation/widgets/session_accounts_content.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/operations_repository.dart';
import '../../domain/models/transaction_models.dart';
import '../providers/transactions_providers.dart';
import '../widgets/transaction_badges.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({
    super.key,
    this.initialType = FinancialOperationType.transfer,
  });

  final FinancialOperationType initialType;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _destination = TextEditingController();
  late var _type = widget.initialType;
  String? _selectedAccount;
  String? _quoteError;
  bool _reviewing = false;

  @override
  void dispose() {
    _amount.dispose();
    _destination.dispose();
    super.dispose();
  }

  Future<void> _review(SessionAccount account) async {
    if (_reviewing || _form.currentState?.validate() != true) return;
    final session = ref.read(activeSessionProvider);
    if (session == null) return;
    final controller = ref.read(operationsProvider.notifier);
    final repository = ref.read(operationsRepositoryProvider);
    final draft = OperationDraft(
      type: _type,
      accountNumber: account.accountNumber,
      amount: _amount.text.trim().replaceAll(',', '.'),
      destinationNumber: _type == FinancialOperationType.transfer
          ? _destination.text.trim()
          : null,
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _reviewing = true;
      _quoteError = null;
    });
    try {
      final destination = draft.destinationNumber == null
          ? null
          : await repository.findDestination(session, draft.destinationNumber!);
      if (!mounted || !identical(ref.read(activeSessionProvider), session)) {
        return;
      }
      final quote = await repository.quote(session, draft);
      if (!mounted || !identical(ref.read(activeSessionProvider), session)) {
        return;
      }
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _QuoteSheet(
          account: account,
          destination: destination,
          quote: quote,
          type: draft.type,
        ),
      );
      if (mounted && confirmed == true) {
        await controller.submit(session, draft);
      }
    } catch (error) {
      if (mounted && identical(ref.read(activeSessionProvider), session)) {
        setState(() => _quoteError = operationErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeReceiptProvider, (previous, next) {
      if (next != null && !identical(previous, next)) {
        context.go('/transactions/summary');
      }
    });
    final operation = ref.watch(operationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operaciones'),
        leading: BackButton(
          onPressed: () {
            ref.read(bottomNavIndexProvider.notifier).state = 2;
            context.go('/operations');
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            operation.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Card(
                child: ListTile(
                  title: const Text(
                    'No pudimos consultar las operaciones pendientes.',
                  ),
                  subtitle: TextButton(
                    onPressed: () => ref.invalidate(operationsProvider),
                    child: const Text('Reintentar'),
                  ),
                ),
              ),
              data: (state) {
                if (state.sending) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.pending case final pending?) {
                  return _PendingCard(
                    state: state,
                    operation: pending,
                    onRetry: ref.read(operationsProvider.notifier).retry,
                  );
                }
                return SessionAccountsContent(
                  builder: (accounts) => _buildForm(
                    accounts
                        .where(
                          (account) => account.status == AccountStatus.active,
                        )
                        .toList(),
                    state,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(List<SessionAccount> accounts, OperationState state) {
    if (accounts.isEmpty) {
      return const Card(
        child: ListTile(
          title: Text('Necesitas una cuenta activa para operar.'),
        ),
      );
    }
    final source = accounts.firstWhere(
      (account) => account.accountNumber == _selectedAccount,
      orElse: () => accounts.first,
    );
    final message = _quoteError ?? state.message;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final type in FinancialOperationType.values)
                ChoiceChip(
                  key: ValueKey('op_tab_${type.name}'),
                  label: Text(type.label),
                  selected: _type == type,
                  onSelected: _reviewing
                      ? null
                      : (_) => setState(() {
                          _type = type;
                          _quoteError = null;
                        }),
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            key: ValueKey(source.accountNumber),
            initialValue: source.accountNumber,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _type == FinancialOperationType.deposit
                  ? 'Cuenta a abonar'
                  : 'Cuenta origen',
            ),
            items: [
              for (final account in accounts)
                DropdownMenuItem(
                  value: account.accountNumber,
                  child: Text('${account.maskedNumber} · ${account.currency}'),
                ),
            ],
            onChanged: _reviewing
                ? null
                : (value) => setState(() => _selectedAccount = value),
          ),
          Text(
            'Saldo actual ${formatAccountBalance(source.balanceUnits, source.currency)}',
          ),
          if (_type == FinancialOperationType.transfer)
            TextFormField(
              key: const Key('destination_account_field'),
              controller: _destination,
              enabled: !_reviewing,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: const InputDecoration(
                labelText: 'Número de cuenta destino',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa el número de cuenta destino.';
                }
                if (value == source.accountNumber) {
                  return 'Elige una cuenta distinta de la de origen.';
                }
                return null;
              },
            ),
          TextFormField(
            key: const Key('amount_field'),
            controller: _amount,
            enabled: !_reviewing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto en ${source.currency}',
            ),
            validator: (value) {
              final amount = (value ?? '').trim().replaceAll(',', '.');
              if (!RegExp(r'^\d{1,14}(?:\.\d{1,4})?$').hasMatch(amount) ||
                  parseMoneyUnits(amount) <= BigInt.zero) {
                return 'Ingresa un monto positivo con hasta 4 decimales.';
              }
              return null;
            },
          ),
          if (message != null)
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  state.rejected && _quoteError == null
                      ? 'Operación rechazada'
                      : message,
                ),
                subtitle: state.rejected && _quoteError == null
                    ? Text(message)
                    : null,
              ),
            ),
          FilledButton.icon(
            key: const Key('review_transfer_button'),
            onPressed: _reviewing ? null : () => _review(source),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(_reviewing ? 'Consultando…' : 'Revisar cotización'),
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.state,
    required this.operation,
    required this.onRetry,
  });

  final OperationState state;
  final ConfirmedOperation operation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final retryAvailable = operation.canRetry;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(
              state.rejected
                  ? 'Operación rechazada'
                  : state.receipt != null
                  ? 'Operación confirmada'
                  : 'Operación pendiente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              state.needsCleanup
                  ? '${state.message ?? 'El servidor confirmó la operación.'} Falta limpiar el registro local.'
                  : retryAvailable
                  ? 'Todavía no tenemos la confirmación del servidor. Reintenta la misma operación.'
                  : 'Venció el plazo de reintento. Consulta el estado con tu banco antes de repetir la operación.',
            ),
            Text('Seguimiento: ${operation.correlationId}'),
            if (retryAvailable || state.needsCleanup)
              FilledButton(
                onPressed: onRetry,
                child: Text(
                  state.needsCleanup
                      ? 'Limpiar registro local'
                      : 'Reintentar operación',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuoteSheet extends StatelessWidget {
  const _QuoteSheet({
    required this.account,
    required this.destination,
    required this.quote,
    required this.type,
  });

  final SessionAccount account;
  final TransferDestination? destination;
  final OperationQuote quote;
  final FinancialOperationType type;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cotización de ${type.label.toLowerCase()}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (destination case final receiver?)
              ReceiptKeyValueRow(
                label: 'Destinatario',
                value:
                    '${receiver.holderName} · ${maskAccountNumber(receiver.accountNumber)}',
              ),
            ReceiptKeyValueRow(label: 'Cuenta', value: account.maskedNumber),
            ReceiptKeyValueRow(
              label: 'Total a debitar',
              value: formatAccountBalance(quote.debit, quote.sourceCurrency),
              boldValue: true,
            ),
            ReceiptKeyValueRow(
              label: 'Comisión',
              value: formatAccountBalance(quote.fee, quote.sourceCurrency),
            ),
            ReceiptKeyValueRow(
              label: 'Tasa de cambio',
              value:
                  '1 ${quote.sourceCurrency} = ${quote.rate} ${quote.destinationCurrency}',
            ),
            ReceiptKeyValueRow(
              label: 'Importe a recibir',
              value: formatAccountBalance(
                quote.received,
                quote.destinationCurrency,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('confirm_operation_button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                type.requiresDeviceAuth
                    ? 'Confirmar con el dispositivo'
                    : 'Confirmar depósito',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
