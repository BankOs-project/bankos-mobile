import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/transaction_models.dart';

/// Badge pequeño que identifica al instante si la transacción fue entre cuentas
/// propias o hacia otra persona.
class TransferScopeBadge extends StatelessWidget {
  final TransferScope scope;

  const TransferScopeBadge({
    super.key,
    required this.scope,
  });

  @override
  Widget build(BuildContext context) {
    final isOwn = scope == TransferScope.ownAccounts;
    final color = isOwn ? AppTheme.secondaryColor : AppTheme.infoColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(scope.icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            scope.shortBadgeLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador visual de ruta bancaria: `Banco Origen -> Banco Destino`.
class BankRoutePill extends StatelessWidget {
  final String sourceBank;
  final String destinationBank;
  final bool compact;

  const BankRoutePill({
    super.key,
    required this.sourceBank,
    required this.destinationBank,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_rounded,
            size: compact ? 12 : 14,
            color: AppTheme.tertiaryColor,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              sourceBank,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: compact ? 12 : 14,
              color: AppTheme.primaryColor,
            ),
          ),
          Flexible(
            child: Text(
              destinationBank,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge de estado de cuenta bancaria (`ACTIVA` / `INACTIVA`).
class AccountStatusBadge extends StatelessWidget {
  final String status;

  const AccountStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final upper = status.toUpperCase();
    final isActive = upper == 'ACTIVA';
    final color = isActive ? AppTheme.successColor : AppTheme.warningColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        upper,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Fila clave-valor alineada para comprobantes y hojas de confirmación.
class ReceiptKeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool boldValue;

  const ReceiptKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.boldValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? AppTheme.textPrimaryColor,
                fontSize: 13,
                fontWeight: boldValue ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Divisor punteado estilo ticket bancario en puro Flutter.
class TicketDashedDivider extends StatelessWidget {
  const TicketDashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        final dashCount =
            (constraints.constrainWidth() / (dashWidth + dashSpace)).floor();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => const SizedBox(
              width: dashWidth,
              height: 1.2,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppTheme.outlineColor),
              ),
            ),
          ),
        );
      },
    );
  }
}
