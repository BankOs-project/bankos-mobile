import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/transaction_models.dart';
import '../providers/transactions_providers.dart';
import '../widgets/account_selector_sheet.dart';
import '../widgets/transaction_badges.dart';
import '../widgets/transfer_confirmation_sheet.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  FinancialOperationType _operation = FinancialOperationType.transfer;
  TransferScope _scope = TransferScope.externalPerson;
  String? _selectedSourceNumber;
  String? _selectedDestOwnNumber;

  @override
  void dispose() {
    _keyController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  ManagedBankAccount _resolveSourceAccount(List<ManagedBankAccount> accounts) {
    if (_selectedSourceNumber != null) {
      final match = accounts.where(
        (a) => a.accountNumber == _selectedSourceNumber,
      );
      if (match.isNotEmpty) return match.first;
    }
    final activeCop = accounts.where(
      (a) => a.isActive && a.currency.toUpperCase() == 'COP',
    );
    if (activeCop.isNotEmpty) return activeCop.first;

    final activeAny = accounts.where((a) => a.isActive);
    return activeAny.isNotEmpty ? activeAny.first : accounts.first;
  }

  ManagedBankAccount? _resolveDestOwnAccount(
    List<ManagedBankAccount> accounts,
    ManagedBankAccount source,
  ) {
    final candidates = accounts.where(
      (a) =>
          a.isActive &&
          a.accountNumber != source.accountNumber &&
          a.currency.toUpperCase() == source.currency.toUpperCase(),
    );
    if (candidates.isEmpty) return null;

    if (_selectedDestOwnNumber != null) {
      final match = candidates.where(
        (a) => a.accountNumber == _selectedDestOwnNumber,
      );
      if (match.isNotEmpty) return match.first;
    }
    return candidates.first;
  }

  List<double> _quickAmountsFor(String currency) {
    if (currency.toUpperCase() == 'COP') {
      return const [20000, 50000, 100000, 200000];
    }
    return const [25, 50, 100, 250];
  }

  void _applyQuickAmount(double value, String currency) {
    final text = currency.toUpperCase() == 'COP'
        ? value.round().toString()
        : value.toStringAsFixed(0);
    setState(() {
      _amountController.text = text;
    });
  }

  Future<void> _pickSourceAccount(
    List<ManagedBankAccount> accounts,
    ManagedBankAccount currentSource,
  ) async {
    final picked = await AccountSelectorSheet.show(
      context,
      title: _operation == FinancialOperationType.deposit
          ? 'Cuenta a abonar'
          : 'Cuenta / Banco origen',
      accounts: accounts,
      selectedAccountNumber: currentSource.accountNumber,
    );
    if (picked == null) return;
    setState(() {
      _selectedSourceNumber = picked.accountNumber;
      if (_selectedDestOwnNumber == picked.accountNumber) {
        _selectedDestOwnNumber = null;
      }
    });
  }

  Future<void> _pickDestinationOwnAccount(
    List<ManagedBankAccount> accounts,
    ManagedBankAccount source,
    ManagedBankAccount? currentDest,
  ) async {
    final picked = await AccountSelectorSheet.show(
      context,
      title: 'Cuenta / Banco destino',
      accounts: accounts,
      selectedAccountNumber: currentDest?.accountNumber,
      excludedAccountNumber: source.accountNumber,
      requiredCurrency: source.currency,
    );
    if (picked == null) return;
    setState(() {
      _selectedDestOwnNumber = picked.accountNumber;
    });
  }

  Future<void> _handleReviewAndConfirm({
    required ManagedBankAccount sourceAccount,
    required ManagedBankAccount? destOwnAccount,
    required ResolvedRecipient? resolvedRecipient,
    required TransactionQuote quote,
  }) async {
    if (!quote.isValid) {
      if (quote.validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(quote.validationError!)),
        );
      }
      return;
    }

    FocusScope.of(context).unfocus();

    final destBank = _operation == FinancialOperationType.deposit
        ? 'Depósito Core'
        : _operation == FinancialOperationType.withdrawal
            ? 'Retiro Cajero'
            : (_scope == TransferScope.ownAccounts && destOwnAccount != null
                ? destOwnAccount.bankName
                : (resolvedRecipient?.bankName ?? 'Entidad destino'));

    final destKey = _operation == FinancialOperationType.deposit ||
            _operation == FinancialOperationType.withdrawal
        ? sourceAccount.accountNumber
        : (_scope == TransferScope.ownAccounts && destOwnAccount != null
            ? destOwnAccount.accountNumber
            : (resolvedRecipient?.keyValue ?? _keyController.text.trim()));

    final destLabel = _operation == FinancialOperationType.deposit
        ? 'Abono a cuenta'
        : _operation == FinancialOperationType.withdrawal
            ? 'Retiro en efectivo'
            : (_scope == TransferScope.ownAccounts && destOwnAccount != null
                ? destOwnAccount.title
                : (resolvedRecipient?.displayName ?? _keyController.text.trim()));

    final authorizedKey = await TransferConfirmationSheet.show(
      context,
      scope: _scope,
      sourceAccount: sourceAccount,
      destinationBankName: destBank,
      destinationLabel: destLabel,
      destinationKeyOrAccount: destKey,
      quote: quote,
      description: _descriptionController.text,
    );

    if (authorizedKey == null || !mounted) return;

    ref.read(transactionsHistoryProvider.notifier).executeOperation(
          operationType: _operation,
          sourceAccount: sourceAccount,
          destinationOwnAccount: _operation == FinancialOperationType.transfer &&
                  _scope == TransferScope.ownAccounts
              ? destOwnAccount
              : null,
          destinationAccountNumber: destKey,
          destinationHolderName: destLabel,
          destinationBankName: destBank,
          quote: quote,
          description: _descriptionController.text,
          customIdempotencyKey: authorizedKey,
        );

    context.go('/transactions/summary');
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(managedAccountsProvider);
    final recipients = ref.watch(quickRecipientsProvider);
    final beneficiaries = ref.watch(tenantBeneficiariesProvider);
    final feePolicy = ref.watch(feePolicyProvider);
    final calculator = ref.watch(quoteCalculatorProvider);

    final sourceAccount = _resolveSourceAccount(accounts);
    final destOwnAccount = _resolveDestOwnAccount(accounts, sourceAccount);
    final resolvedRecipient = resolveRecipientByKey(
      _keyController.text,
      recipients,
    );
    final parsedAmount = CurrencyFormatter.parseAmountInput(
      _amountController.text,
      sourceAccount.currency,
    );

    final quote = calculator.calculate(
      operationType: _operation,
      scope: _scope,
      sourceAccount: sourceAccount,
      destinationOwnAccount: _operation == FinancialOperationType.transfer &&
              _scope == TransferScope.ownAccounts
          ? destOwnAccount
          : null,
      destinationKey:
          _scope == TransferScope.externalPerson ? _keyController.text : null,
      amount: parsedAmount,
      feePolicy: feePolicy,
    );

    final destinationBankPreview = _operation == FinancialOperationType.deposit
        ? 'Depósito Core'
        : _operation == FinancialOperationType.withdrawal
            ? 'Retiro Cajero'
            : (_scope == TransferScope.ownAccounts && destOwnAccount != null
                ? destOwnAccount.bankName
                : resolvedRecipient?.bankName);

    final hasTypedAmount = _amountController.text.trim().isNotEmpty;
    final showInlineError = hasTypedAmount &&
        !quote.isValid &&
        quote.validationError != null;

    final appTitle = switch (_operation) {
      FinancialOperationType.transfer => 'Transferir Dinero',
      FinancialOperationType.deposit => 'Depositar Dinero',
      FinancialOperationType.withdrawal => 'Retirar Dinero',
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/operations');
            }
          },
        ),
        title: Text(appTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector superior: Transferencia | Depósito | Retiro
              _OperationTypeToggle(
                selected: _operation,
                onChanged: (op) {
                  setState(() {
                    _operation = op;
                  });
                },
              ),
              const SizedBox(height: 16),

              if (_operation == FinancialOperationType.transfer) ...[
                _TransferScopeToggle(
                  selected: _scope,
                  onChanged: (nextScope) {
                    setState(() => _scope = nextScope);
                  },
                ),
                const SizedBox(height: 16),
              ],

              _SectionHeader(
                title: _operation == FinancialOperationType.deposit
                    ? 'Cuenta destino (abono)'
                    : 'Desde (cuenta origen)',
                subtitle: _operation == FinancialOperationType.deposit
                    ? 'Elige la cuenta donde se acreditará el dinero'
                    : 'Elige la cuenta desde donde saldrá el dinero',
              ),
              const SizedBox(height: 10),
              _AccountSelectorCard(
                key: const Key('source_account_card'),
                account: sourceAccount,
                onTap: () => _pickSourceAccount(accounts, sourceAccount),
              ),

              if (!sourceAccount.isActive) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                    border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.block_rounded,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Cuenta INACTIVA. No es posible realizar operaciones hasta que sea activada por la entidad.',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_operation == FinancialOperationType.transfer) ...[
                const SizedBox(height: 20),
                if (_scope == TransferScope.externalPerson) ...[
                  const _SectionHeader(
                    title: 'Hacia (destinatario / cuenta)',
                    subtitle:
                        'Ingresa la cuenta o llave del destinatario',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('destination_key_field'),
                    controller: _keyController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Cuenta o Llave',
                      hintText:
                          'Cuenta destinatario, celular, correo o llave',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: _keyController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                setState(() => _keyController.clear());
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _QuickRecipientsRow(
                    recipients: recipients,
                    selectedKey: _keyController.text.trim(),
                    onSelect: (recipient) {
                      setState(() {
                        _keyController.text = recipient.keyValue;
                      });
                    },
                  ),
                  if (beneficiaries.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _BeneficiariesChipsRow(
                      beneficiaries: beneficiaries,
                      selectedKey: _keyController.text.trim(),
                      onSelect: (ben) {
                        setState(() {
                          _keyController.text = ben.accountNumber;
                        });
                      },
                    ),
                  ],
                  if (resolvedRecipient != null) ...[
                    const SizedBox(height: 12),
                    _ResolvedRecipientCard(recipient: resolvedRecipient),
                  ],
                ] else ...[
                  const _SectionHeader(
                    title: 'Hacia (otra cuenta propia)',
                    subtitle:
                         'Mueve dinero entre tus cuentas de este banco',
                  ),
                  const SizedBox(height: 10),
                  if (destOwnAccount != null)
                    _AccountSelectorCard(
                      key: const Key('destination_own_account_card'),
                      account: destOwnAccount,
                      onTap: () => _pickDestinationOwnAccount(
                        accounts,
                        sourceAccount,
                        destOwnAccount,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariantColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(
                          color: AppTheme.warningColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppTheme.warningColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No tienes otra cuenta activa en ${sourceAccount.currency}. Selecciona una cuenta en COP para transferir entre tus cuentas.',
                              style: const TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],

              const SizedBox(height: 20),
              _SectionHeader(
                title: switch (_operation) {
                  FinancialOperationType.transfer => 'Monto a enviar',
                  FinancialOperationType.deposit => 'Monto a depositar',
                  FinancialOperationType.withdrawal => 'Monto a retirar',
                },
                subtitle:
                    'Límite máx. ${CurrencyFormatter.format(TenantLimits.maxLimitFor(sourceAccount.currency), sourceAccount.currency)}',
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('amount_field'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                // Formateador estricto de seguridad: bloquea signos negativos (-) y letras
                inputFormatters: [
                  sourceAccount.currency.toUpperCase() == 'COP'
                      ? FilteringTextInputFormatter.digitsOnly
                      : FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                ],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  labelText: 'Monto',
                  hintText: sourceAccount.currency == 'COP'
                      ? '50000'
                      : '100.00',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixText: sourceAccount.currency,
                  suffixStyle: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                  errorText: showInlineError ? quote.validationError : null,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmountsFor(sourceAccount.currency).map((val) {
                  return ActionChip(
                    label: Text(
                      CurrencyFormatter.format(
                        val,
                        sourceAccount.currency,
                        showCurrencyCode: false,
                      ),
                    ),
                    onPressed: () =>
                        _applyQuickAmount(val, sourceAccount.currency),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('description_field'),
                controller: _descriptionController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Ej. Almuerzo, ahorro mensual, depósito nómina',
                  prefixIcon: Icon(Icons.notes_rounded),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),
              _TransferCostPreviewCard(
                sourceBank: sourceAccount.bankName,
                destinationBank: destinationBankPreview,
                quote: quote,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                key: const Key('review_transfer_button'),
                onPressed: quote.isValid
                    ? () => _handleReviewAndConfirm(
                          sourceAccount: sourceAccount,
                          destOwnAccount: destOwnAccount,
                          resolvedRecipient: resolvedRecipient,
                          quote: quote,
                        )
                    : null,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Revisar y confirmar'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _OperationTypeToggle extends StatelessWidget {
  final FinancialOperationType selected;
  final ValueChanged<FinancialOperationType> onChanged;

  const _OperationTypeToggle({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Row(
        children: FinancialOperationType.values.map((op) {
          final isSelected = op == selected;
          return Expanded(
            child: InkWell(
              key: Key('op_tab_${op.name}'),
              onTap: () => onChanged(op),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      op.icon,
                      size: 16,
                      color: isSelected
                          ? AppTheme.onPrimaryColor
                          : AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        op.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.onPrimaryColor
                              : AppTheme.textSecondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TransferScopeToggle extends StatelessWidget {
  final TransferScope selected;
  final ValueChanged<TransferScope> onChanged;

  const _TransferScopeToggle({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Row(
        children: TransferScope.values.map((scope) {
          final isSelected = scope == selected;
          return Expanded(
            child: InkWell(
              key: Key('scope_tab_${scope.name}'),
              onTap: () => onChanged(scope),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      scope.icon,
                      size: 16,
                      color: isSelected
                          ? AppTheme.onPrimaryColor
                          : AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        scope.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.onPrimaryColor
                              : AppTheme.textSecondaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AccountSelectorCard extends StatelessWidget {
  final ManagedBankAccount account;
  final VoidCallback onTap;

  const _AccountSelectorCard({
    super.key,
    required this.account,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: account.accentColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_rounded,
                color: account.accentColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.bankName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AccountStatusBadge(status: account.status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${account.title} · ${account.accountNumber}',
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(
                    account.balance,
                    account.currency,
                    showCurrencyCode: false,
                  ),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  account.currency,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.tertiaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickRecipientsRow extends StatelessWidget {
  final List<QuickRecipient> recipients;
  final String selectedKey;
  final ValueChanged<QuickRecipient> onSelect;

  const _QuickRecipientsRow({
    required this.recipients,
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recipients.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final recipient = recipients[index];
          final isSelected = recipient.keyValue == selectedKey;
          return ChoiceChip(
            avatar: Icon(
              Icons.person_outline_rounded,
              size: 16,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondaryColor,
            ),
            label: Text('${recipient.name} · ${recipient.bankName}'),
            selected: isSelected,
            onSelected: (_) => onSelect(recipient),
          );
        },
      ),
    );
  }
}

class _BeneficiariesChipsRow extends StatelessWidget {
  final List<BeneficiaryAccount> beneficiaries;
  final String selectedKey;
  final ValueChanged<BeneficiaryAccount> onSelect;

  const _BeneficiariesChipsRow({
    required this.beneficiaries,
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: beneficiaries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final ben = beneficiaries[index];
          final isSelected = ben.accountNumber == selectedKey;
          return ChoiceChip(
            avatar: Icon(
              Icons.account_box_outlined,
              size: 16,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondaryColor,
            ),
            label: Text('${ben.name} (${ben.accountNumber} · ${ben.currency})'),
            selected: isSelected,
            onSelected: (_) => onSelect(ben),
          );
        },
      ),
    );
  }
}

class _ResolvedRecipientCard extends StatelessWidget {
  final ResolvedRecipient recipient;

  const _ResolvedRecipientCard({required this.recipient});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('resolved_recipient_card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppTheme.primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient.isKnownContact
                      ? recipient.displayName
                      : 'Llave verificada',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Banco destino detectado: ${recipient.bankName}',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferCostPreviewCard extends StatelessWidget {
  final String sourceBank;
  final String? destinationBank;
  final TransactionQuote quote;

  const _TransferCostPreviewCard({
    required this.sourceBank,
    required this.destinationBank,
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Resumen del envío',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (destinationBank != null)
                Flexible(
                  child: BankRoutePill(
                    sourceBank: sourceBank,
                    destinationBank: destinationBank!,
                    compact: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 4),
          ReceiptKeyValueRow(
            label: 'Monto',
            value: CurrencyFormatter.format(quote.amount, quote.currency),
          ),
          ReceiptKeyValueRow(
            label: 'Comisión',
            value: CurrencyFormatter.format(quote.feeAmount, quote.currency),
            valueColor: quote.feeAmount == 0
                ? AppTheme.successColor
                : AppTheme.warningColor,
            boldValue: true,
          ),
          ReceiptKeyValueRow(
            label: 'Total a debitar',
            value: CurrencyFormatter.format(quote.totalDebit, quote.currency),
            valueColor: AppTheme.primaryColor,
            boldValue: true,
          ),
        ],
      ),
    );
  }
}
