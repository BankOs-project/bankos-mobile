import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/models/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/domain/models/financial_summary.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';

class FinancialPeriod {
  const FinancialPeriod(this.firstDay, this.lastDay, {this.months});

  final DateTime firstDay;
  final DateTime lastDay;
  final int? months;

  // El calendario del Dashboard usa Bogotá (UTC−05:00).
  DateTime get startUtc =>
      DateTime.utc(firstDay.year, firstDay.month, firstDay.day, 5);

  DateTime get endUtc => DateTime.utc(
    lastDay.year,
    lastDay.month,
    lastDay.day + 1,
    5,
  ).subtract(const Duration(microseconds: 1));

  factory FinancialPeriod.trailingMonths(DateTime today, int months) {
    final lastOfStartMonth = DateTime.utc(
      today.year,
      today.month - months + 1,
      0,
    );
    final day = today.day.clamp(1, lastOfStartMonth.day);
    return FinancialPeriod(
      DateTime.utc(lastOfStartMonth.year, lastOfStartMonth.month, day),
      DateTime.utc(today.year, today.month, today.day),
      months: months,
    );
  }
}

final dashboardFinanceFiltersProvider =
    NotifierProvider<
      DashboardFinanceFilters,
      ({String? account, FinancialPeriod period})
    >(DashboardFinanceFilters.new);

class DashboardFinanceFilters
    extends Notifier<({String? account, FinancialPeriod period})> {
  @override
  ({String? account, FinancialPeriod period}) build() {
    ref.watch(activeSessionProvider);
    return (account: null, period: _trailingMonths(1));
  }

  void selectAccount(String? account) =>
      state = (account: account, period: state.period);

  void selectMonths(int months) => selectPeriod(_trailingMonths(months));

  void selectPeriod(FinancialPeriod period) =>
      state = (account: state.account, period: period);

  FinancialPeriod _trailingMonths(int months) => FinancialPeriod.trailingMonths(
    DateTime.now().toUtc().subtract(const Duration(hours: 5)),
    months,
  );
}

typedef FinancialSummaryQuery = ({
  AuthSession session,
  DateTime start,
  DateTime end,
  String? accountNumber,
});

final financialSummaryProvider = FutureProvider.autoDispose
    .family<List<FinancialCurrencySummary>, FinancialSummaryQuery>((
      ref,
      query,
    ) {
      final cancelToken = CancelToken();
      ref.onDispose(cancelToken.cancel);
      ref.listen(activeReceiptProvider, (previous, next) {
        if (next != null &&
            next.id != previous?.id &&
            identical(ref.read(activeSessionProvider), query.session)) {
          ref.invalidateSelf();
        }
      });
      return ref
          .watch(operationsRepositoryProvider)
          .fetchFinancialSummary(
            query.session,
            start: query.start,
            end: query.end,
            accountNumber: query.accountNumber,
            cancelToken: cancelToken,
          );
    }, retry: (_, _) => null);
