import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/bottom_nav_provider.dart';

/// Barra de accesos directos rápidos para operaciones frecuentes en BankOs.
class DashboardQuickActions extends ConsumerWidget {
  const DashboardQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            'Acciones Rápidas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickActionItem(
              key: const Key('quick_action_transfer'),
              icon: Icons.send_rounded,
              label: 'Transferir',
              color: colors.primary,
              onTap: () => context.push('/transactions/transfer'),
            ),
            _QuickActionItem(
              key: const Key('quick_action_accounts'),
              icon: Icons.account_balance_rounded,
              label: 'Cuentas',
              color: colors.secondary,
              onTap: () {
                ref.read(bottomNavIndexProvider.notifier).state = 1;
                context.go('/accounts');
              },
            ),
            _QuickActionItem(
              key: const Key('quick_action_deposit'),
              icon: Icons.add_circle_outline_rounded,
              label: 'Depósito',
              color: colors.tertiary,
              onTap: () => context.go('/transactions/transfer?type=deposit'),
            ),
            _QuickActionItem(
              key: const Key('quick_action_history'),
              icon: Icons.history_rounded,
              label: 'Movimientos',
              color: colors.onSurfaceVariant,
              onTap: () {
                ref.read(bottomNavIndexProvider.notifier).state = 3;
                context.go('/history');
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
