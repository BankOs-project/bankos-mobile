import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bankos_mobile/features/accounts/domain/models/dashboard_models.dart';
import 'package:bankos_mobile/features/accounts/presentation/providers/dashboard_providers.dart';

void main() {
  group('Dashboard Providers & Calculations', () {
    test('activeDashboardChartsProvider tiene por defecto 2 gráficos activos', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final activeCharts = container.read(activeDashboardChartsProvider);
      expect(activeCharts.contains(DashboardChartType.incomeVsExpense), isTrue);
      expect(activeCharts.contains(DashboardChartType.expensesByCategory), isTrue);
      expect(activeCharts.contains(DashboardChartType.balanceEvolution), isFalse);
    });

    test('activeDashboardChartsProvider alterna correctamente la visibilidad de gráficos', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(activeDashboardChartsProvider.notifier);

      // Activar balance evolution
      notifier.toggleChart(DashboardChartType.balanceEvolution);
      var charts = container.read(activeDashboardChartsProvider);
      expect(charts.contains(DashboardChartType.balanceEvolution), isTrue);

      // Desactivar incomeVsExpense
      notifier.toggleChart(DashboardChartType.incomeVsExpense);
      charts = container.read(activeDashboardChartsProvider);
      expect(charts.contains(DashboardChartType.incomeVsExpense), isFalse);

      // Desactivar todos
      notifier.toggleChart(DashboardChartType.expensesByCategory);
      notifier.toggleChart(DashboardChartType.balanceEvolution);
      charts = container.read(activeDashboardChartsProvider);
      expect(charts.isEmpty, isTrue);

      // Reactivar
      notifier.enableChart(DashboardChartType.balanceEvolution);
      charts = container.read(activeDashboardChartsProvider);
      expect(charts.contains(DashboardChartType.balanceEvolution), isTrue);
    });

    test('dashboardKpisProvider actualiza métricas según filtro de fecha', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Por defecto: Mensual
      expect(container.read(dashboardDateFilterProvider), DashboardDateFilter.monthly);
      final monthlyKpis = container.read(dashboardKpisProvider);
      expect(monthlyKpis.filter, DashboardDateFilter.monthly);
      expect(monthlyKpis.totalIncome, greaterThan(0));
      expect(monthlyKpis.totalExpenses, greaterThan(0));
      expect(monthlyKpis.totalBalanceCop, greaterThan(0));

      // Cambiar a Diario
      container.read(dashboardDateFilterProvider.notifier).state =
          DashboardDateFilter.daily;
      final dailyKpis = container.read(dashboardKpisProvider);
      expect(dailyKpis.filter, DashboardDateFilter.daily);
      expect(dailyKpis.totalIncome, lessThan(monthlyKpis.totalIncome));
      expect(dailyKpis.totalExpenses, lessThan(monthlyKpis.totalExpenses));

      // Cambiar a Trimestral
      container.read(dashboardDateFilterProvider.notifier).state =
          DashboardDateFilter.quarterly;
      final quarterlyKpis = container.read(dashboardKpisProvider);
      expect(quarterlyKpis.filter, DashboardDateFilter.quarterly);
      expect(quarterlyKpis.totalIncome, greaterThan(monthlyKpis.totalIncome));

      // Cambiar a Anual
      container.read(dashboardDateFilterProvider.notifier).state =
          DashboardDateFilter.annual;
      final annualKpis = container.read(dashboardKpisProvider);
      expect(annualKpis.filter, DashboardDateFilter.annual);
      expect(annualKpis.totalIncome, greaterThan(quarterlyKpis.totalIncome));
    });

    test('dashboardTimeSeriesProvider entrega puntos de acuerdo al filtro activo', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(dashboardDateFilterProvider.notifier).state =
          DashboardDateFilter.daily;
      final dailySeries = container.read(dashboardTimeSeriesProvider);
      expect(dailySeries.first.label, '08:00');

      container.read(dashboardDateFilterProvider.notifier).state =
          DashboardDateFilter.monthly;
      final monthlySeries = container.read(dashboardTimeSeriesProvider);
      expect(monthlySeries.first.label, 'Sem 1');

      container.read(dashboardDateFilterProvider.notifier).state =
          DashboardDateFilter.quarterly;
      final quarterlySeries = container.read(dashboardTimeSeriesProvider);
      expect(quarterlySeries.first.label, 'Sep');

      container.read(dashboardDateFilterProvider.notifier).state =
          DashboardDateFilter.annual;
      final annualSeries = container.read(dashboardTimeSeriesProvider);
      expect(annualSeries.first.label, 'Q1');
    });
  });
}
