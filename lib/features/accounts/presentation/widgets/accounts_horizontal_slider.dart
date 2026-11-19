import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../transactions/domain/models/transaction_models.dart';
import '../providers/accounts_mock_provider.dart';
import '../providers/dashboard_providers.dart';

/// Slider horizontal que exhibe todas las cuentas vinculadas.
/// Permite deslizar si hay más cuentas que el ancho visible de la pantalla.
/// Al tocar una cuenta, navega a la sección de cuentas con esa cuenta seleccionada.
class AccountsHorizontalSlider extends ConsumerStatefulWidget {
  final List<ManagedBankAccount> accounts;

  const AccountsHorizontalSlider({
    super.key,
    required this.accounts,
  });

  @override
  ConsumerState<AccountsHorizontalSlider> createState() =>
      _AccountsHorizontalSliderState();
}

class _AccountsHorizontalSliderState
    extends ConsumerState<AccountsHorizontalSlider> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onAccountTapped(ManagedBankAccount account) {
    // Almacenar la cuenta seleccionada para enfocar su configuración en /accounts
    ref.read(selectedAccountProvider.notifier).state = account.accountNumber;

    // Actualizar índice visual del BottomNavigation
    ref.read(bottomNavIndexProvider.notifier).state = 1;

    // Redireccionar a la pantalla de cuentas
    context.go('/accounts');
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accounts;

    if (accounts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 40, color: AppTheme.textSecondaryColor),
              const SizedBox(height: 8),
              const Text(
                'No tienes cuentas registradas.',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado con contador y llamada a la acción
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Mis Cuentas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariantColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.outlineColor,
                      ),
                    ),
                    child: Text(
                      '${accounts.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(bottomNavIndexProvider.notifier).state = 1;
                  context.go('/accounts');
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Administrar'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Carousel / Slider horizontal deslizable
        SizedBox(
          height: 184,
          child: ListView.separated(
            key: const Key('dashboard_accounts_slider'),
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return _AccountSlideCard(
                account: account,
                onTap: () => _onAccountTapped(account),
              );
            },
          ),
        ),

        const SizedBox(height: 6),
        // Indicador discreto de desplazamiento horizontal
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.swipe_rounded,
              size: 14,
              color: AppTheme.textMutedColor,
            ),
            const SizedBox(width: 6),
            Text(
              'Desliza horizontalmente para ver todas (${accounts.length})',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMutedColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tarjeta individual para cada cuenta en el slide horizontal.
class _AccountSlideCard extends StatelessWidget {
  final ManagedBankAccount account;
  final VoidCallback onTap;

  const _AccountSlideCard({
    required this.account,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedBalance =
        CurrencyFormatter.format(account.balance, account.currency);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('account_card_${account.accountNumber}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        splashColor: account.accentColor.withValues(alpha: 0.2),
        highlightColor: account.accentColor.withValues(alpha: 0.08),
        child: Ink(
          width: 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                account.accentColor.withValues(alpha: 0.16),
                AppTheme.cardColor,
                AppTheme.cardColor,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: account.accentColor.withValues(alpha: 0.38),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: account.accentColor.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fila Superior: Banco + Título y Badge de Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: account.accentColor.withValues(alpha: 0.18),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  account.bankName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: account.accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(status: account.status),
                  ],
                ),

                // Fila Media: Número de Cuenta Enmascarado
                Row(
                  children: [
                    const Icon(
                      Icons.credit_card_rounded,
                      size: 15,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      account.accountNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        account.currency,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMutedColor,
                        ),
                      ),
                    ),
                  ],
                ),

                // Fila Inferior: Dinero (Saldo) + Botón de acceso
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saldo disponible',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMutedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formattedBalance,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimaryColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariantColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.outlineColor,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status.toUpperCase() == 'ACTIVA';
    final color = isActive ? AppTheme.successColor : AppTheme.errorColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
