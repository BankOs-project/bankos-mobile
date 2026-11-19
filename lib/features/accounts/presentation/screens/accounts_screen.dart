import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../transactions/domain/models/transaction_models.dart';
import '../providers/dashboard_providers.dart';

/// Pantalla de gestión y configuración de Cuentas Bancarias de BankOs.
/// Si el usuario llega desde el slide horizontal del Dashboard, enfoca y resalta la cuenta seleccionada
/// y despliega sus opciones de configuración.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(dashboardAccountsProvider);
    final selectedAccountNumber = ref.watch(selectedAccountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas Bancarias'),
        actions: [
          if (selectedAccountNumber != null)
            TextButton.icon(
              onPressed: () {
                ref.read(selectedAccountProvider.notifier).state = null;
              },
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Ver todas'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondaryColor,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mis Cuentas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(color: AppTheme.outlineColor),
                  ),
                  child: Text(
                    '${accounts.length} Vinculadas',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Toca una cuenta para ver sus detalles y configurar sus opciones.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 16),

            // Lista de tarjetas de cuenta
            for (final account in accounts) ...[
              _AccountDetailCard(
                account: account,
                isSelected: account.accountNumber == selectedAccountNumber,
                onTap: () {
                  final current = ref.read(selectedAccountProvider);
                  // Alternar selección
                  ref.read(selectedAccountProvider.notifier).state =
                      current == account.accountNumber
                          ? null
                          : account.accountNumber;
                },
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tarjeta enriquecida de cuenta bancaria con panel de configuración expandible
class _AccountDetailCard extends StatelessWidget {
  final ManagedBankAccount account;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountDetailCard({
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedBalance =
        CurrencyFormatter.format(account.balance, account.currency);
    final isActive = account.status.toUpperCase() == 'ACTIVA';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('account_item_${account.accountNumber}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.outlineColor,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fila Superior: Banco, Nombre y Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: account.accentColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: account.accentColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            Icons.account_balance_rounded,
                            size: 18,
                            color: account.accentColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            Text(
                              account.bankName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: account.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (isSelected) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.16),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusPill),
                              border: Border.all(
                                  color: AppTheme.primaryColor),
                            ),
                            child: const Text(
                              'Seleccionada',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isActive
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor)
                                .withValues(alpha: 0.14),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusPill),
                            border: Border.all(
                              color: (isActive
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            account.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Fila Media: Número y Saldo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.credit_card_rounded,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          account.accountNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      formattedBalance,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),

                // Panel desplegado de opciones de configuración si está seleccionada
                if (isSelected) ...[
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.outlineColor),
                  const SizedBox(height: 8),
                  const Text(
                    'Opciones de Configuración',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ConfigActionChip(
                        icon: Icons.tune_rounded,
                        label: 'Límites de transferencia',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Ajustar límites de ${account.title} (${account.accountNumber})'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      _ConfigActionChip(
                        icon: Icons.edit_note_rounded,
                        label: 'Editar alias',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Editar alias para ${account.accountNumber}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      _ConfigActionChip(
                        icon: Icons.lock_outline_rounded,
                        label: 'Bloqueo temporal',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Estado de seguridad de ${account.title}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      _ConfigActionChip(
                        icon: Icons.file_download_outlined,
                        label: 'Extractos',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Descargando extracto de ${account.bankName}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ConfigActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            border: Border.all(color: AppTheme.outlineColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppTheme.textSecondaryColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
