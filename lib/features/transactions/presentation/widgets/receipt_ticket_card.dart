import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/transaction_models.dart';
import 'transaction_badges.dart';

/// Tarjeta estilo ticket bancario envuelta en [RepaintBoundary] para poder
/// capturarla como imagen PNG y compartirla mediante `share_plus`.
class ReceiptTicketCard extends StatelessWidget {
  final TransactionRecord record;
  final GlobalKey? boundaryKey;

  const ReceiptTicketCard({
    super.key,
    required this.record,
    this.boundaryKey,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      decoration: BoxDecoration(
        gradient: AppTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.outlineColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: AppTheme.cardColor.withValues(alpha: 0.75),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusCard),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        children: [
                          TextSpan(
                            text: 'Bank',
                            style: TextStyle(color: AppTheme.textPrimaryColor),
                          ),
                          TextSpan(
                            text: 'Os',
                            style: TextStyle(color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                    TransferScopeBadge(scope: record.scope),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.successColor,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.successColor,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  record.status == 'COMPLETADA'
                      ? 'Transferencia exitosa'
                      : record.status,
                  style: const TextStyle(
                    color: AppTheme.successColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(record.amount, record.currency),
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 12),
                BankRoutePill(
                  sourceBank: record.sourceBankName,
                  destinationBank: record.destinationBankName,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TicketDashedDivider(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                ReceiptKeyValueRow(
                  label: 'Referencia',
                  value: record.referenceCode,
                  boldValue: true,
                ),
                ReceiptKeyValueRow(
                  label: 'Fecha y hora',
                  value: CurrencyFormatter.formatDateTime(record.createdAt),
                ),
                ReceiptKeyValueRow(
                  label: 'Tipo',
                  value: record.scope.label,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(),
                ),
                ReceiptKeyValueRow(
                  label: 'Banco origen',
                  value: record.sourceBankName,
                ),
                ReceiptKeyValueRow(
                  label: 'Cuenta origen',
                  value:
                      '${record.sourceAccountTitle} (${record.sourceAccountNumber})',
                ),
                ReceiptKeyValueRow(
                  label: 'Banco destino',
                  value: record.destinationBankName,
                ),
                ReceiptKeyValueRow(
                  label: record.scope == TransferScope.ownAccounts
                      ? 'Cuenta destino'
                      : 'Llave / Destino',
                  value: record.destinationLabel ==
                          record.destinationKeyOrAccount
                      ? record.destinationKeyOrAccount
                      : '${record.destinationLabel} (${record.destinationKeyOrAccount})',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(),
                ),
                ReceiptKeyValueRow(
                  label: 'Monto',
                  value: CurrencyFormatter.format(
                    record.amount,
                    record.currency,
                  ),
                ),
                ReceiptKeyValueRow(
                  label: 'Comisión',
                  value: CurrencyFormatter.format(
                    record.feeCharged,
                    record.currency,
                  ),
                  valueColor: record.feeCharged == 0
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                  boldValue: true,
                ),
                ReceiptKeyValueRow(
                  label: 'Total',
                  value: CurrencyFormatter.format(
                    record.totalAmount,
                    record.currency,
                  ),
                  valueColor: AppTheme.primaryColor,
                  boldValue: true,
                ),
                if (record.description.trim().isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(),
                  ),
                  ReceiptKeyValueRow(
                    label: 'Descripción',
                    value: record.description,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (boundaryKey == null) return cardContent;

    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        color: AppTheme.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(2),
        child: cardContent,
      ),
    );
  }
}
