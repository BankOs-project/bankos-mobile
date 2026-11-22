import 'package:flutter/material.dart';

import 'bank_theme.dart';

class BankSurfaceCard extends StatelessWidget {
  const BankSurfaceCard({super.key, required this.child, this.clipBehavior});

  final Widget child;
  final Clip? clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = theme.extension<BankSurfaceColors>();
    if (brand == null) return Card(clipBehavior: clipBehavior, child: child);

    return Card(
      color: brand.fill,
      clipBehavior: clipBehavior,
      child: ListTileTheme.merge(
        textColor: brand.onFill,
        iconColor: brand.onFill,
        child: IconTheme.merge(
          data: IconThemeData(color: brand.onFill),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: brand.onFill),
            child: child,
          ),
        ),
      ),
    );
  }
}
