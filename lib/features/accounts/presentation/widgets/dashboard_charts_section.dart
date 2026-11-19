import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../transactions/domain/models/transaction_models.dart';
import '../../domain/models/dashboard_models.dart';
import '../providers/dashboard_providers.dart';

/// Sección dinámica de gráficos personalizables del Dashboard.
/// Cuenta con un botón desplegable con checkboxes para agregar o remover widgets de gráficos.
class DashboardChartsSection extends ConsumerStatefulWidget {
  const DashboardChartsSection({super.key});

  @override
  ConsumerState<DashboardChartsSection> createState() =>
      _DashboardChartsSectionState();
}

class _DashboardChartsSectionState
    extends ConsumerState<DashboardChartsSection> {
  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    final activeCharts = ref.watch(activeDashboardChartsProvider);
    final timeSeries = ref.watch(dashboardTimeSeriesProvider);
    final categories = ref.watch(dashboardCategoryExpensesProvider);
    final accounts = ref.watch(dashboardAccountsProvider);
    final activeFilter = ref.watch(dashboardDateFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado de la sección con el botón desplegable de edición
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Gráficos y Análisis',
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
                      border: Border.all(color: AppTheme.outlineColor),
                    ),
                    child: Text(
                      '${activeCharts.length} activos',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              // Botón desplegable con checks para agregar/remover gráficos
              _ChartsDropdownMenuButton(
                activeCharts: activeCharts,
                onToggle: (type) {
                  ref
                      .read(activeDashboardChartsProvider.notifier)
                      .toggleChart(type);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Estado vacío en caso de desmarcar todos los widgets
        if (activeCharts.isEmpty)
          Card(
            key: const Key('dashboard_charts_empty_state'),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              side: const BorderSide(color: AppTheme.outlineColor),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.add_chart_rounded,
                    size: 42,
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No hay gráficos activos en el Dashboard',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Usa el botón "Editar widgets" para marcar los gráficos que deseas visualizar.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(activeDashboardChartsProvider.notifier)
                          .enableChart(DashboardChartType.incomeVsExpense);
                      ref
                          .read(activeDashboardChartsProvider.notifier)
                          .enableChart(DashboardChartType.expensesByCategory);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Restaurar gráficos predeterminados'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(200, 40),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // Renderizar los gráficos activos con check
          Column(
            children: [
              if (activeCharts.contains(DashboardChartType.incomeVsExpense)) ...[
                _IncomeVsExpenseChartCard(
                  key: const Key('chart_card_income_vs_expense'),
                  timeSeries: timeSeries,
                  filter: activeFilter,
                ),
                const SizedBox(height: 14),
              ],
              if (activeCharts.contains(DashboardChartType.expensesByCategory)) ...[
                _ExpensesByCategoryChartCard(
                  key: const Key('chart_card_expenses_by_category'),
                  categories: categories,
                  touchedIndex: _touchedPieIndex,
                  onTouch: (index) {
                    setState(() {
                      _touchedPieIndex = index;
                    });
                  },
                ),
                const SizedBox(height: 14),
              ],
              if (activeCharts.contains(DashboardChartType.balanceEvolution)) ...[
                _BalanceEvolutionChartCard(
                  key: const Key('chart_card_balance_evolution'),
                  timeSeries: timeSeries,
                  filter: activeFilter,
                ),
                const SizedBox(height: 14),
              ],
              if (activeCharts.contains(DashboardChartType.bankDistribution)) ...[
                _BankDistributionChartCard(
                  key: const Key('chart_card_bank_distribution'),
                  accounts: accounts,
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
      ],
    );
  }
}

/// Botón desplegable que despliega la lista de gráficos con su respectivo checkbox.
class _ChartsDropdownMenuButton extends StatelessWidget {
  final Set<DashboardChartType> activeCharts;
  final ValueChanged<DashboardChartType> onToggle;

  const _ChartsDropdownMenuButton({
    required this.activeCharts,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DashboardChartType>(
      key: const Key('dashboard_charts_dropdown_button'),
      tooltip: 'Editar widgets de gráficos',
      color: AppTheme.cardColor,
      elevation: 10,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        side: const BorderSide(color: AppTheme.outlineColor),
      ),
      onSelected: onToggle,
      itemBuilder: (context) => [
        const PopupMenuItem<DashboardChartType>(
          enabled: false,
          child: Text(
            'SELECCIONAR GRÁFICOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppTheme.textMutedColor,
            ),
          ),
        ),
        for (final chartType in DashboardChartType.values)
          PopupMenuItem<DashboardChartType>(
            key: Key('chart_option_${chartType.name}'),
            value: chartType,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: activeCharts.contains(chartType),
                    activeColor: AppTheme.primaryColor,
                    checkColor: AppTheme.onPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (_) => onToggle(chartType),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  chartType.icon,
                  size: 18,
                  color: activeCharts.contains(chartType)
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chartType.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: activeCharts.contains(chartType)
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: activeCharts.contains(chartType)
                              ? AppTheme.textPrimaryColor
                              : AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariantColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          border: Border.all(color: AppTheme.outlineColor),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 15, color: AppTheme.primaryColor),
            SizedBox(width: 6),
            Text(
              'Editar widgets',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: AppTheme.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// Gráfico 1: Flujo de Ingresos vs. Gastos (Barras agrupadas)
class _IncomeVsExpenseChartCard extends StatelessWidget {
  final List<TimeSeriesDataPoint> timeSeries;
  final DashboardDateFilter filter;

  const _IncomeVsExpenseChartCard({
    super.key,
    required this.timeSeries,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: AppTheme.outlineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con título y leyendas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Flujo: Ingresos vs Gastos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    Text(
                      'Periodo ${filter.label.toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    _ChartLegendItem(
                      color: AppTheme.successColor,
                      label: 'Ingresos',
                    ),
                    SizedBox(width: 10),
                    _ChartLegendItem(
                      color: AppTheme.errorColor,
                      label: 'Gastos',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // BarChart de fl_chart
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _calculateMaxY(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _calculateInterval(),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppTheme.outlineColor.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          final formatted = value >= 1000000
                              ? '${(value / 1000000).toStringAsFixed(1)}M'
                              : '${(value / 1000).round()}k';
                          return Text(
                            formatted,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMutedColor,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < timeSeries.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                timeSeries[idx].label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (int i = 0; i < timeSeries.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: timeSeries[i].income,
                            color: AppTheme.successColor,
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: timeSeries[i].expense,
                            color: AppTheme.errorColor,
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMaxY() {
    double highest = 0;
    for (final point in timeSeries) {
      if (point.income > highest) highest = point.income;
      if (point.expense > highest) highest = point.expense;
    }
    return highest > 0 ? highest * 1.25 : 100000;
  }

  double _calculateInterval() {
    final max = _calculateMaxY();
    return max / 4;
  }
}

/// Gráfico 2: Gastos por Categoría (Gráfico Donut / Pastel)
class _ExpensesByCategoryChartCard extends StatelessWidget {
  final List<ExpenseCategoryItem> categories;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _ExpensesByCategoryChartCard({
    super.key,
    required this.categories,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: AppTheme.outlineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gastos por Categoría',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  'Distribución %',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // PieChart interactivo
            SizedBox(
              height: 170,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, pieTouchResponse) {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              onTouch(-1);
                              return;
                            }
                            onTouch(pieTouchResponse
                                .touchedSection!.touchedSectionIndex);
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 3,
                        centerSpaceRadius: 36,
                        sections: [
                          for (int i = 0; i < categories.length; i++)
                            PieChartSectionData(
                              color: categories[i].color,
                              value: categories[i].percentage,
                              title: '${categories[i].percentage.round()}%',
                              radius: i == touchedIndex ? 36.0 : 30.0,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onPrimaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Lista lateral de categorías
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final cat in categories)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: cat.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    cat.categoryName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${cat.percentage.round()}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gráfico 3: Evolución del Balance (Línea con gradiente inferior)
class _BalanceEvolutionChartCard extends StatelessWidget {
  final List<TimeSeriesDataPoint> timeSeries;
  final DashboardDateFilter filter;

  const _BalanceEvolutionChartCard({
    super.key,
    required this.timeSeries,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: AppTheme.outlineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Evolución del Balance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  'Curva de saldo (${filter.label})',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppTheme.outlineColor.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          final formatted = value >= 1000000
                              ? '${(value / 1000000).toStringAsFixed(1)}M'
                              : '${(value / 1000).round()}k';
                          return Text(
                            formatted,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMutedColor,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < timeSeries.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                timeSeries[idx].label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < timeSeries.length; i++)
                          FlSpot(i.toDouble(), timeSeries[i].balance),
                      ],
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.3),
                            AppTheme.primaryColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gráfico 4: Distribución por Banco / Entidad
class _BankDistributionChartCard extends StatelessWidget {
  final List<ManagedBankAccount> accounts;

  const _BankDistributionChartCard({
    super.key,
    required this.accounts,
  });

  @override
  Widget build(BuildContext context) {
    double totalCop = 0;
    for (final acc in accounts) {
      if (acc.currency.toUpperCase() == 'COP') {
        totalCop += acc.balance;
      }
    }
    if (totalCop == 0) totalCop = 1;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: AppTheme.outlineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Distribución de Fondos por Entidad',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 14),
            for (final acc in accounts) ...[
              Builder(
                builder: (context) {
                  final pct = acc.currency.toUpperCase() == 'COP'
                      ? (acc.balance / totalCop)
                      : 0.15;
                  final clampedPct = pct.clamp(0.05, 1.0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: acc.accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${acc.bankName} (${acc.title})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${(clampedPct * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: acc.accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: clampedPct,
                            backgroundColor: AppTheme.surfaceVariantColor,
                            color: acc.accentColor,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
