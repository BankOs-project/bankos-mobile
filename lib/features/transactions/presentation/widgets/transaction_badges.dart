import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

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
