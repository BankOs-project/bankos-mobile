import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/transaction_models.dart';
import 'transaction_badges.dart';

enum _AuthMethod { pin, fingerprint }

/// BottomSheet de comprobación previa y autorización de seguridad.
/// Muestra el resumen completo del envío y solicita PIN (`1234` funcional)
/// o muestra la opción visual de Huella (no disponible aún).
class TransferConfirmationSheet extends StatefulWidget {
  final TransferScope scope;
  final ManagedBankAccount sourceAccount;
  final String destinationBankName;
  final String destinationLabel;
  final String destinationKeyOrAccount;
  final TransactionQuote quote;
  final String description;

  const TransferConfirmationSheet({
    super.key,
    required this.scope,
    required this.sourceAccount,
    required this.destinationBankName,
    required this.destinationLabel,
    required this.destinationKeyOrAccount,
    required this.quote,
    required this.description,
  });

  static const String demoPin = '1234';

  static Future<bool?> show(
    BuildContext context, {
    required TransferScope scope,
    required ManagedBankAccount sourceAccount,
    required String destinationBankName,
    required String destinationLabel,
    required String destinationKeyOrAccount,
    required TransactionQuote quote,
    required String description,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      builder: (_) => TransferConfirmationSheet(
        scope: scope,
        sourceAccount: sourceAccount,
        destinationBankName: destinationBankName,
        destinationLabel: destinationLabel,
        destinationKeyOrAccount: destinationKeyOrAccount,
        quote: quote,
        description: description,
      ),
    );
  }

  @override
  State<TransferConfirmationSheet> createState() =>
      _TransferConfirmationSheetState();
}

class _TransferConfirmationSheetState extends State<TransferConfirmationSheet> {
  _AuthMethod _method = _AuthMethod.pin;
  String _enteredPin = '';
  String? _pinError;

  void _onDigitTap(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _pinError = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _validatePin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _pinError = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _validatePin() {
    if (_enteredPin == TransferConfirmationSheet.demoPin) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _pinError = 'PIN incorrecto. Intenta nuevamente.';
      _enteredPin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outlineColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Verifica tu envío',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TransferScopeBadge(scope: widget.scope),
                ],
              ),
              const SizedBox(height: 12),
              _ConfirmationSummaryCard(
                sourceAccount: widget.sourceAccount,
                destinationBankName: widget.destinationBankName,
                destinationLabel: widget.destinationLabel,
                destinationKeyOrAccount: widget.destinationKeyOrAccount,
                quote: widget.quote,
                description: widget.description,
              ),
              const SizedBox(height: 18),
              const Text(
                'Autoriza la operación',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _SecurityMethodSelector(
                selected: _method,
                onChanged: (value) {
                  setState(() {
                    _method = value;
                    _pinError = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_method == _AuthMethod.pin)
                _PinAuthorizationSection(
                  enteredPin: _enteredPin,
                  errorText: _pinError,
                  onDigitTap: _onDigitTap,
                  onBackspace: _onBackspace,
                )
              else
                _FingerprintPlaceholderSection(
                  onSwitchToPin: () {
                    setState(() => _method = _AuthMethod.pin);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationSummaryCard extends StatelessWidget {
  final ManagedBankAccount sourceAccount;
  final String destinationBankName;
  final String destinationLabel;
  final String destinationKeyOrAccount;
  final TransactionQuote quote;
  final String description;

  const _ConfirmationSummaryCard({
    required this.sourceAccount,
    required this.destinationBankName,
    required this.destinationLabel,
    required this.destinationKeyOrAccount,
    required this.quote,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: BankRoutePill(
              sourceBank: sourceAccount.bankName,
              destinationBank: destinationBankName,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              CurrencyFormatter.format(quote.amount, quote.currency),
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 6),
          ReceiptKeyValueRow(
            label: 'Desde',
            value:
                '${sourceAccount.bankName} (${sourceAccount.accountNumber})',
          ),
          ReceiptKeyValueRow(
            label: 'Hacia',
            value: destinationLabel == destinationKeyOrAccount
                ? destinationKeyOrAccount
                : '$destinationLabel ($destinationKeyOrAccount)',
          ),
          ReceiptKeyValueRow(
            label: 'Banco destino',
            value: destinationBankName,
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
            boldValue: true,
          ),
          if (description.trim().isNotEmpty)
            ReceiptKeyValueRow(
              label: 'Descripción',
              value: description.trim(),
            ),
        ],
      ),
    );
  }
}

class _SecurityMethodSelector extends StatelessWidget {
  final _AuthMethod selected;
  final ValueChanged<_AuthMethod> onChanged;

  const _SecurityMethodSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MethodTabButton(
              icon: Icons.pin_outlined,
              label: 'PIN',
              isSelected: selected == _AuthMethod.pin,
              onTap: () => onChanged(_AuthMethod.pin),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _MethodTabButton(
              icon: Icons.fingerprint_rounded,
              label: 'Huella',
              isSelected: selected == _AuthMethod.fingerprint,
              onTap: () => onChanged(_AuthMethod.fingerprint),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodTabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? AppTheme.onPrimaryColor
                  : AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.onPrimaryColor
                    : AppTheme.textSecondaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinAuthorizationSection extends StatelessWidget {
  final String enteredPin;
  final String? errorText;
  final ValueChanged<String> onDigitTap;
  final VoidCallback onBackspace;

  const _PinAuthorizationSection({
    required this.enteredPin,
    required this.errorText,
    required this.onDigitTap,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Ingresa tu PIN de 4 dígitos para confirmar',
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final filled = index < enteredPin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: errorText != null
                      ? AppTheme.errorColor
                      : (filled
                          ? AppTheme.primaryColor
                          : AppTheme.tertiaryColor),
                  width: 1.8,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        if (errorText != null)
          Text(
            errorText!,
            style: const TextStyle(
              color: AppTheme.errorColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          const Text(
            'PIN de prueba: 1234',
            style: TextStyle(
              color: AppTheme.textMutedColor,
              fontSize: 11,
            ),
          ),
        const SizedBox(height: 14),
        _PinKeypad(
          onDigitTap: onDigitTap,
          onBackspace: onBackspace,
        ),
      ],
    );
  }
}

class _PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigitTap;
  final VoidCallback onBackspace;

  const _PinKeypad({
    required this.onDigitTap,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((key) {
              if (key.isEmpty) {
                return const Expanded(child: SizedBox(height: 48));
              }
              if (key == 'back') {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      key: const Key('pin_key_backspace'),
                      onTap: onBackspace,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariantColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.outlineColor),
                        ),
                        child: const Icon(
                          Icons.backspace_outlined,
                          color: AppTheme.textPrimaryColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    key: Key('pin_key_$key'),
                    onTap: () => onDigitTap(key),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outlineColor),
                      ),
                      child: Text(
                        key,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _FingerprintPlaceholderSection extends StatelessWidget {
  final VoidCallback onSwitchToPin;

  const _FingerprintPlaceholderSection({
    required this.onSwitchToPin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.tertiaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.tertiaryColor.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              size: 36,
              color: AppTheme.tertiaryColor,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Huella no disponible aún',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'La validación biométrica se habilitará próximamente. Por ahora autoriza tu transferencia con PIN.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onSwitchToPin,
            icon: const Icon(Icons.pin_outlined),
            label: const Text('Autorizar con PIN'),
          ),
        ],
      ),
    );
  }
}
