import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/bank_theme.dart';
import '../../../auth/domain/models/public_bank.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bankName = ref.watch(
      activeSessionProvider.select((session) => session?.bankLabel),
    );
    final appTheme = Theme.of(context);
    final palette = BankPalette.fromName(normalizeBankSearch(bankName ?? ''));

    return Theme(
      data: palette?.theme(appTheme.brightness) ?? appTheme,
      child: Scaffold(
        body: child,
        bottomNavigationBar: BankNavigationBar(location: location),
      ),
    );
  }
}

class BankNavigationBar extends StatelessWidget {
  const BankNavigationBar({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      ('/dashboard', 'Dashboard', Icons.home),
      ('/accounts', 'Cuentas', Icons.account_balance),
      ('/operations', 'Operaciones', Icons.swap_horiz),
      ('/history', 'Movimientos', Icons.history),
    ];
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brand = theme.extension<BankSurfaceColors>();

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (path, label, icon) in tabs)
                Expanded(
                  child: _BankTab(
                    key: ValueKey('bank-tab-$label'),
                    label: label,
                    icon: icon,
                    selected: location == path || location.startsWith('$path/'),
                    fill: brand?.fill ?? colors.primary,
                    onFill: brand?.onFill ?? colors.onPrimary,
                    onTap: () => context.go(path),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankTab extends StatelessWidget {
  const _BankTab({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.fill,
    required this.onFill,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color fill;
  final Color onFill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected ? onFill : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? fill : theme.scaffoldBackgroundColor,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4,
              children: [
                Icon(icon, color: foreground),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
