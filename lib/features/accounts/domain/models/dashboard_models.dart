import 'package:flutter/material.dart';

/// Filtro temporal de acción rápida para las métricas del dashboard.
enum DashboardDateFilter {
  daily,
  monthly,
  quarterly,
  annual;

  String get label => switch (this) {
        DashboardDateFilter.daily => 'Diario',
        DashboardDateFilter.monthly => 'Mensual',
        DashboardDateFilter.quarterly => 'Trimestral',
        DashboardDateFilter.annual => 'Anual',
      };

  String get periodName => switch (this) {
        DashboardDateFilter.daily => 'Hoy',
        DashboardDateFilter.monthly => 'Este mes (Nov)',
        DashboardDateFilter.quarterly => 'Último trimestre',
        DashboardDateFilter.annual => 'Año 2026',
      };

  IconData get icon => switch (this) {
        DashboardDateFilter.daily => Icons.today_rounded,
        DashboardDateFilter.monthly => Icons.calendar_month_rounded,
        DashboardDateFilter.quarterly => Icons.date_range_rounded,
        DashboardDateFilter.annual => Icons.calendar_today_rounded,
      };
}

/// Métricas clave (KPIs) calculadas según el periodo seleccionado.
class DashboardKpis {
  final DashboardDateFilter filter;
  final double totalBalanceCop;
  final double totalBalanceUsd;
  final double totalIncome;
  final double totalExpenses;
  final double netCashFlow;
  final double percentageChange;
  final int transactionCount;

  const DashboardKpis({
    required this.filter,
    required this.totalBalanceCop,
    required this.totalBalanceUsd,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netCashFlow,
    required this.percentageChange,
    required this.transactionCount,
  });
}

/// Tipos de widgets de gráficos disponibles para personalizar en el dashboard.
enum DashboardChartType {
  incomeVsExpense,
  expensesByCategory,
  balanceEvolution;

  String get title => switch (this) {
        DashboardChartType.incomeVsExpense => 'Flujo: Ingresos vs Gastos',
        DashboardChartType.expensesByCategory => 'Gastos por Categoría',
        DashboardChartType.balanceEvolution => 'Evolución del Balance',
      };

  String get subtitle => switch (this) {
        DashboardChartType.incomeVsExpense =>
          'Comparación entre dinero entrante y saliente',
        DashboardChartType.expensesByCategory =>
          'Distribución porcentual de consumos y transferencias',
        DashboardChartType.balanceEvolution =>
          'Comportamiento y tendencia del saldo consolidado',
      };

  IconData get icon => switch (this) {
        DashboardChartType.incomeVsExpense => Icons.bar_chart_rounded,
        DashboardChartType.expensesByCategory => Icons.pie_chart_outline_rounded,
        DashboardChartType.balanceEvolution => Icons.show_chart_rounded,
      };
}

/// Elemento de gasto por categoría para gráfico de pastel / donut.
class ExpenseCategoryItem {
  final String categoryName;
  final double amount;
  final double percentage;
  final Color color;
  final IconData icon;

  const ExpenseCategoryItem({
    required this.categoryName,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.icon,
  });
}

/// Dato para serie temporal en gráficos de barras o líneas.
class TimeSeriesDataPoint {
  final String label;
  final double income;
  final double expense;
  final double balance;

  const TimeSeriesDataPoint({
    required this.label,
    required this.income,
    required this.expense,
    required this.balance,
  });
}
