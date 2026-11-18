import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/transaction_models.dart';
import 'transaction_badges.dart';

/// BottomSheet para seleccionar una cuenta bancaria propia dentro de BankOs.
class AccountSelectorSheet extends StatelessWidget {
  final String title;
  final List<ManagedBankAccount> accounts;
  final String? selectedAccountNumber;
  final String? excludedAccountNumber;
  final String? requiredCurrency;

  const AccountSelectorSheet({
    super.key,
    required this.title,
    required this.accounts,
    this.selectedAccountNumber,
    this.excludedAccountNumber,
    this.requiredCurrency,
  });

  static Future<ManagedBankAccount?> show(
    BuildContext context, {
    required String title,
    required List<ManagedBankAccount> accounts,
    String? selectedAccountNumber,
    String? excludedAccountNumber,
    String? requiredCurrency,
  }) {
    return showModalBottomSheet<ManagedBankAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      builder: (_) => AccountSelectorSheet(
        title: title,
        accounts: accounts,
        selectedAccountNumber: selectedAccountNumber,
        excludedAccountNumber: excludedAccountNumber,
        requiredCurrency: requiredCurrency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Elige el banco y cuenta con la que deseas operar.',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: accounts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final isExcluded =
                      account.accountNumber == excludedAccountNumber;
                  final wrongCurrency = requiredCurrency != null &&
                      account.currency.toUpperCase() !=
                          requiredCurrency!.toUpperCase();
                  final isEnabled =
                      account.isActive && !isExcluded && !wrongCurrency;
                  final isSelected =
                      account.accountNumber == selectedAccountNumber;

                  String? disabledReason;
                  if (!account.isActive) {
                    disabledReason = 'Cuenta inactiva';
                  } else if (isExcluded) {
                    disabledReason = 'Seleccionada como cuenta origen';
                  } else if (wrongCurrency) {
                    disabledReason = 'Requiere moneda $requiredCurrency';
                  }

                  return InkWell(
                    onTap: isEnabled
                        ? () => Navigator.of(context).pop(account)
                        : null,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    child: Opacity(
                      opacity: isEnabled ? 1 : 0.48,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : AppTheme.surfaceVariantColor,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusCard),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.outlineColor,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color:
                                    account.accentColor.withValues(alpha: 0.16),
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
                                      AccountStatusBadge(
                                        status: account.status,
                                      ),
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
                                  if (disabledReason != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      disabledReason,
                                      style: const TextStyle(
                                        color: AppTheme.warningColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
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
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
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
                          ],
                        ),
                      ),
                    ),
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
