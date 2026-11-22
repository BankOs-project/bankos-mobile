import 'package:flutter/material.dart';

class BankLogo extends StatelessWidget {
  const BankLogo({super.key, required this.logoUrl});

  final Uri? logoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Icon(
      Icons.account_balance_outlined,
      color: colors.primary,
    );
    final url = logoUrl;
    return CircleAvatar(
      backgroundColor: colors.surfaceContainerHighest,
      child: url == null
          ? fallback
          : ClipOval(
              child: Image.network(
                url.toString(),
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                frameBuilder: (_, child, frame, _) =>
                    frame == null ? fallback : child,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}
