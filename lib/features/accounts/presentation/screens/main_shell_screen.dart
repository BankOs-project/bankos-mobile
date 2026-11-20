import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/bank_theme.dart';
import '../../../auth/domain/models/public_bank.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/bottom_nav_provider.dart';

class MainShellScreen extends ConsumerWidget {
  final Widget? child;

  const MainShellScreen({super.key, this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final bankName = ref.watch(
      activeSessionProvider.select((session) => session?.bankLabel),
    );
    final appTheme = Theme.of(context);
    final palette = BankPalette.fromName(normalizeBankSearch(bankName ?? ''));

    final shell = Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          ref.read(bottomNavIndexProvider.notifier).state = index;
          if (index == 0) context.go('/dashboard');
          if (index == 1) context.go('/accounts');
          if (index == 2) context.go('/operations');
          if (index == 3) context.go('/history');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Cuentas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Operaciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Movimientos',
          ),
        ],
      ),
    );
    return Theme(
      data: palette?.theme(appTheme.brightness) ?? appTheme,
      child: shell,
    );
  }
}
