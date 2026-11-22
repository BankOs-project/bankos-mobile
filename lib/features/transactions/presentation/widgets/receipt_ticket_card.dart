import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../accounts/domain/models/session_account.dart';
import '../../domain/models/transaction_models.dart';
import 'transaction_badges.dart';

class ReceiptTicketCard extends StatelessWidget {
  const ReceiptTicketCard({super.key, required this.record, this.boundaryKey});

  final OperationReceipt record;
  final GlobalKey? boundaryKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticket = Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.surfaceGradient(theme),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              record.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              formatAccountBalance(record.amount, record.sourceCurrency),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const TicketDashedDivider(),
            const SizedBox(height: 10),
            for (final row in record.details.entries)
              ReceiptKeyValueRow(label: row.key, value: row.value),
          ],
        ),
      ),
    );

    return boundaryKey == null
        ? ticket
        : RepaintBoundary(key: boundaryKey, child: ticket);
  }
}
