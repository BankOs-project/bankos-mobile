import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../transactions/domain/models/transaction_models.dart';
import '../../domain/models/dashboard_models.dart';
import '../providers/dashboard_providers.dart';

/// Sección de métricas clave (KPIs) con filtro por fechas de acción rápida.
/// Los KPIs se actualizan de forma reactiva al alternar entre Diario, Mensual, Trimestral y Anual.
class DashboardKpiSection extends ConsumerWidget {
  const DashboardKpiSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(dashboardDateFilterProvider);
    final kpis = ref.watch(dashboardKpisProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado con selector desplegable de fecha
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen Financiero',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  Text(
                    'Periodo: ${activeFilter.periodName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),

              // Botón desplegable para filtro por fechas
              PopupMenuButton<DashboardDateFilter>(
                key: const Key('dashboard_date_filter_popup'),
                initialValue: activeFilter,
                tooltip: 'Filtrar por fecha',
                onSelected: (filter) {
                  ref.read(dashboardDateFilterProvider.notifier).state = filter;
                },
                color: AppTheme.cardColor,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                  side: const BorderSide(color: AppTheme.outlineColor),
                ),
                itemBuilder: (context) => [
                  for (final filter in DashboardDateFilter.values)
                    PopupMenuItem(
                      value: filter,
                      child: Row(
                        children: [
                          Icon(
                            filter.icon,
                            size: 18,
                            color: filter == activeFilter
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              filter.label,
                              style: TextStyle(
                                color: filter == activeFilter
                                    ? AppTheme.primaryColor
                                    : AppTheme.textPrimaryColor,
                                fontWeight: filter == activeFilter
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (filter == activeFilter)
                            const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    border: Border.all(color: AppTheme.outlineColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(activeFilter.icon,
                          size: 15, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        activeFilter.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Barra de botones de acción rápida: Diario, Mensual, Trimestral, Anual
        SizedBox(
          height: 38,
          child: ListView(
            key: const Key('dashboard_quick_filter_chips'),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              for (final filter in DashboardDateFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _QuickFilterChip(
                    filter: filter,
                    isSelected: filter == activeFilter,
                    onTap: () {
                      ref.read(dashboardDateFilterProvider.notifier).state =
                          filter;
                    },
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Tarjeta principal: Balance Total Consolidado
        _BalanceKpiCard(kpis: kpis),

        const SizedBox(height: 10),

        // Fila de KPIs: Ingresos y Gastos Totales
        Row(
          children: [
            Expanded(
              child: _MetricKpiCard(
                key: const Key('kpi_income_card'),
                title: 'Ingresos',
                amount: kpis.totalIncome,
                currency: 'COP',
                icon: Icons.south_west_rounded,
                accentColor: AppTheme.successColor,
                periodText: activeFilter.label,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricKpiCard(
                key: const Key('kpi_expenses_card'),
                title: 'Gastos Totales',
                amount: kpis.totalExpenses,
                currency: 'COP',
                icon: Icons.north_east_rounded,
                accentColor: AppTheme.errorColor,
                periodText: activeFilter.label,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Barra informativa de Flujo Neto y Variación
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppTheme.radiusInput),
            border: Border.all(color: AppTheme.outlineColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    kpis.netCashFlow >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 16,
                    color: kpis.netCashFlow >= 0
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Flujo neto: ${CurrencyFormatter.format(kpis.netCashFlow, 'COP')}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kpis.netCashFlow >= 0
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (kpis.percentageChange >= 0
                          ? AppTheme.successColor
                          : AppTheme.errorColor)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${kpis.percentageChange >= 0 ? '+' : ''}${kpis.percentageChange.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: kpis.percentageChange >= 0
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chip de acción rápida para cambiar el filtro temporal
class _QuickFilterChip extends StatelessWidget {
  final DashboardDateFilter filter;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('quick_filter_${filter.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.18)
                : AppTheme.surfaceVariantColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color:
                  isSelected ? AppTheme.primaryColor : AppTheme.outlineColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filter.icon,
                size: 14,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                filter.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta principal de Balance Total Consolidado
class _BalanceKpiCard extends StatelessWidget {
  final DashboardKpis kpis;

  const _BalanceKpiCard({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final copFormatted =
        CurrencyFormatter.format(kpis.totalBalanceCop, 'COP');
    final usdFormatted =
        CurrencyFormatter.format(kpis.totalBalanceUsd, 'USD');

    return Card(
      key: const Key('kpi_balance_card'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: AppTheme.outlineColor),
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.08),
              AppTheme.cardColor,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Balance Total',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    '+ $usdFormatted',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              copFormatted,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimaryColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Saldo disponible unificado en todas tus cuentas',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta individual para métricas de Ingresos o Gastos
class _MetricKpiCard extends StatelessWidget {
  final String title;
  final double amount;
  final String currency;
  final IconData icon;
  final Color accentColor;
  final String periodText;

  const _MetricKpiCard({
    super.key,
    required this.title,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.accentColor,
    required this.periodText,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = CurrencyFormatter.format(amount, currency);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: AppTheme.outlineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 14, color: accentColor),
                ),
                Text(
                  periodText,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatted,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
