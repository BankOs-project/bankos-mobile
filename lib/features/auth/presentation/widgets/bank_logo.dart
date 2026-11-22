import 'package:flutter/material.dart';

import '../../../../core/theme/bank_theme.dart';
import '../../domain/models/public_bank.dart';

class BankLogo extends StatelessWidget {
  const BankLogo({
    super.key,
    required this.bankName,
    required this.logoUrl,
    this.size = 40,
    this.semanticLabel,
  });

  final String? bankName;
  final Uri? logoUrl;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bank = BankPalette.fromName(normalizeBankSearch(bankName ?? ''));
    final asset = switch (bank) {
      BankPalette.bancolombia => 'bank_bancolombia.png',
      BankPalette.nu => 'bank_nu.png',
      BankPalette.daviplata => 'bank_daviplata.png',
      BankPalette.falabella => 'bank_falabella.png',
      _ => null,
    };
    final initials = switch (bank) {
      BankPalette.andino => 'AN',
      BankPalette.caribe => 'CA',
      BankPalette.uno => 'UNO',
      _ => null,
    };
    final icon = Icon(
      Icons.account_balance_outlined,
      color: colors.primary,
      size: size * 0.55,
    );
    final generic = _circle(colors.surfaceContainerHighest, icon);
    final fallback = asset != null
        ? _circle(
            Colors.white,
            Image.asset(
              'resources/images/$asset',
              width: size * 0.8,
              height: size * 0.8,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => icon,
            ),
          )
        : initials != null
        ? _circle(
            colors.surfaceContainerHighest,
            Padding(
              padding: EdgeInsets.all(size * 0.15),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          )
        : generic;
    final url = logoUrl;
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: true,
      child: url == null
          ? fallback
          : Image.network(
              url.toString(),
              width: size,
              height: size,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              frameBuilder: (_, child, frame, _) => frame == null
                  ? generic
                  : _circle(
                      colors.surfaceContainerHighest,
                      Padding(
                        padding: EdgeInsets.all(size * 0.14),
                        child: child,
                      ),
                    ),
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }

  Widget _circle(Color color, Widget child) => ClipOval(
    child: ColoredBox(
      color: color,
      child: SizedBox.square(
        dimension: size,
        child: Center(child: child),
      ),
    ),
  );
}
