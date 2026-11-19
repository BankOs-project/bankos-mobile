import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../transactions/domain/models/transaction_models.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';
import '../../domain/models/dashboard_models.dart';

/// Filtro de fecha activo para los KPI y métricas del Dashboard.
final dashboardDateFilterProvider =
    StateProvider<DashboardDateFilter>((ref) => DashboardDateFilter.monthly);

/// Gestor de widgets de gráficos visibles en el dashboard.
/// Por defecto se muestran 'Flujo: Ingresos vs Gastos' y 'Gastos por Categoría'.
class ActiveChartsNotifier extends Notifier<Set<DashboardChartType>> {
  @override
  Set<DashboardChartType> build() {
    return {
      DashboardChartType.incomeVsExpense,
      DashboardChartType.expensesByCategory,
    };
  }

  void toggleChart(DashboardChartType type) {
    final next = Set<DashboardChartType>.from(state);
    if (next.contains(type)) {
      next.remove(type);
    } else {
      next.add(type);
    }
    state = next;
  }

  void enableChart(DashboardChartType type) {
    if (!state.contains(type)) {
      state = {...state, type};
    }
  }

  void disableChart(DashboardChartType type) {
    if (state.contains(type)) {
      final next = Set<DashboardChartType>.from(state)..remove(type);
      state = next;
    }
  }
}

final activeDashboardChartsProvider =
    NotifierProvider<ActiveChartsNotifier, Set<DashboardChartType>>(
  ActiveChartsNotifier.new,
);

/// Proveedor de métricas clave (KPIs) calculadas según el filtro temporal seleccionado.
final dashboardKpisProvider = Provider<DashboardKpis>((ref) {
  final filter = ref.watch(dashboardDateFilterProvider);
  final accounts = ref.watch(managedAccountsProvider);
  final transactions = ref.watch(transactionsHistoryProvider);

  // Balance total consolidado por moneda
  double copBalance = 0;
  double usdBalance = 0;
  for (final account in accounts) {
    if (account.currency.toUpperCase() == 'COP') {
      copBalance += account.balance;
    } else if (account.currency.toUpperCase() == 'USD') {
      usdBalance += account.balance;
    }
  }

  // Filtrado de transacciones históricas según el rango seleccionado
  final now = DateTime.now();
  final filteredTransactions = transactions.where((tx) {
    final diff = now.difference(tx.createdAt);
    return switch (filter) {
      DashboardDateFilter.daily => diff.inHours <= 24,
      DashboardDateFilter.monthly => diff.inDays <= 30,
      DashboardDateFilter.quarterly => diff.inDays <= 90,
      DashboardDateFilter.annual => diff.inDays <= 365,
    };
  }).toList();

  // Calcular montos de transacciones registradas
  double txIncome = 0;
  double txExpenses = 0;
  for (final tx in filteredTransactions) {
    final amountInCop = tx.currency.toUpperCase() == 'USD'
        ? tx.amount * 4100 // Tasa representativa para consolidación
        : tx.amount;

    if (tx.direction == MovementDirection.incoming) {
      txIncome += amountInCop;
    } else if (tx.direction == MovementDirection.outgoing) {
      txExpenses += amountInCop;
    }
  }

  // Valores base realistas de periodo enriquecidos con las transacciones vivas
  final (baseIncome, baseExpenses, pctChange) = switch (filter) {
    DashboardDateFilter.daily => (180000.0, 95000.0, -3.2),
    DashboardDateFilter.monthly => (1450000.0, 890000.0, 12.8),
    DashboardDateFilter.quarterly => (4600000.0, 2750000.0, 8.4),
    DashboardDateFilter.annual => (18200000.0, 11400000.0, 15.6),
  };

  final totalIncome = baseIncome + txIncome;
  final totalExpenses = baseExpenses + txExpenses;
  final netCashFlow = totalIncome - totalExpenses;

  return DashboardKpis(
    filter: filter,
    totalBalanceCop: copBalance,
    totalBalanceUsd: usdBalance,
    totalIncome: totalIncome,
    totalExpenses: totalExpenses,
    netCashFlow: netCashFlow,
    percentageChange: pctChange,
    transactionCount: filteredTransactions.length,
  );
});

/// Datos de series de tiempo para gráficos de barras y líneas según el filtro.
final dashboardTimeSeriesProvider = Provider<List<TimeSeriesDataPoint>>((ref) {
  final filter = ref.watch(dashboardDateFilterProvider);

  return switch (filter) {
    DashboardDateFilter.daily => const [
        TimeSeriesDataPoint(
            label: '08:00', income: 40000, expense: 15000, balance: 7550000),
        TimeSeriesDataPoint(
            label: '12:00', income: 80000, expense: 35000, balance: 7595000),
        TimeSeriesDataPoint(
            label: '16:00', income: 20000, expense: 28000, balance: 7587000),
        TimeSeriesDataPoint(
            label: '20:00', income: 40000, expense: 17000, balance: 7610000),
      ],
    DashboardDateFilter.monthly => const [
        TimeSeriesDataPoint(
            label: 'Sem 1', income: 380000, expense: 210000, balance: 7320000),
        TimeSeriesDataPoint(
            label: 'Sem 2', income: 420000, expense: 290000, balance: 7450000),
        TimeSeriesDataPoint(
            label: 'Sem 3', income: 310000, expense: 190000, balance: 7570000),
        TimeSeriesDataPoint(
            label: 'Sem 4', income: 340000, expense: 200000, balance: 7690000),
      ],
    DashboardDateFilter.quarterly => const [
        TimeSeriesDataPoint(
            label: 'Sep', income: 1450000, expense: 910000, balance: 7150000),
        TimeSeriesDataPoint(
            label: 'Oct', income: 1520000, expense: 880000, balance: 7420000),
        TimeSeriesDataPoint(
            label: 'Nov', income: 1630000, expense: 960000, balance: 7690000),
      ],
    DashboardDateFilter.annual => const [
        TimeSeriesDataPoint(
            label: 'Q1', income: 4200000, expense: 2800000, balance: 6800000),
        TimeSeriesDataPoint(
            label: 'Q2', income: 4600000, expense: 2950000, balance: 7100000),
        TimeSeriesDataPoint(
            label: 'Q3', income: 4400000, expense: 2750000, balance: 7420000),
        TimeSeriesDataPoint(
            label: 'Q4', income: 5000000, expense: 2900000, balance: 7690000),
      ],
  };
});

/// Categorías de gastos para el gráfico de torta / donut.
final dashboardCategoryExpensesProvider =
    Provider<List<ExpenseCategoryItem>>((ref) {
  final kpis = ref.watch(dashboardKpisProvider);
  final totalExp = kpis.totalExpenses;

  return [
    ExpenseCategoryItem(
      categoryName: 'Alimentación',
      amount: totalExp * 0.32,
      percentage: 32,
      color: AppTheme.primaryColor,
      icon: Icons.restaurant_rounded,
    ),
    ExpenseCategoryItem(
      categoryName: 'Servicios',
      amount: totalExp * 0.26,
      percentage: 26,
      color: AppTheme.infoColor,
      icon: Icons.receipt_long_rounded,
    ),
    ExpenseCategoryItem(
      categoryName: 'Transferencias',
      amount: totalExp * 0.20,
      percentage: 20,
      color: AppTheme.secondaryColor,
      icon: Icons.swap_horiz_rounded,
    ),
    ExpenseCategoryItem(
      categoryName: 'Compras & Ocio',
      amount: totalExp * 0.14,
      percentage: 14,
      color: AppTheme.warningColor,
      icon: Icons.shopping_bag_rounded,
    ),
    ExpenseCategoryItem(
      categoryName: 'Otros',
      amount: totalExp * 0.08,
      percentage: 8,
      color: AppTheme.tertiaryColor,
      icon: Icons.more_horiz_rounded,
    ),
  ];
});
