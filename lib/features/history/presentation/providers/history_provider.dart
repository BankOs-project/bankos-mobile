import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/presentation/providers/session_accounts_provider.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../../transactions/data/repositories/operations_repository.dart';
import '../../../transactions/domain/models/transaction_models.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';

enum HistoryScope { ownAccounts, otherAccounts }

typedef HistoryQuery = ({
  AuthSession session,
  FinancialOperationType? type,
  String? accountNumber,
  HistoryScope? scope,
  String search,
});

class HistoryData {
  const HistoryData({
    required this.items,
    this.nextSkip,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<OperationReceipt> items;
  final int? nextSkip;
  final bool loadingMore;
  final bool loadMoreFailed;
}

final historyProvider = AsyncNotifierProvider.autoDispose
    .family<HistoryPager, HistoryData, HistoryQuery>(
      HistoryPager.new,
      retry: (_, _) => null,
    );

class HistoryPager extends AsyncNotifier<HistoryData> {
  HistoryPager(this.query);

  final HistoryQuery query;
  late CancelToken _cancelToken;
  late Future<Set<String>> _ownNumbers;

  @override
  Future<HistoryData> build() {
    final cancelToken = _cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel);
    ref.listen(activeReceiptProvider, (previous, next) {
      if (next != null && next.id != previous?.id) ref.invalidateSelf();
    });

    _ownNumbers = query.scope == null
        ? Future.value(const <String>{})
        : ref
              .watch(sessionAccountsProvider(query.session).future)
              .then(
                (accounts) =>
                    accounts.map((account) => account.accountNumber).toSet(),
              );

    return _load(
      ref.watch(operationsRepositoryProvider),
      cancelToken,
      _ownNumbers,
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (state.isLoading ||
        current == null ||
        current.loadingMore ||
        current.nextSkip == null) {
      return;
    }

    final cancelToken = _cancelToken;
    final repository = ref.read(operationsRepositoryProvider);
    state = AsyncData(
      HistoryData(
        items: current.items,
        nextSkip: current.nextSkip,
        loadingMore: true,
      ),
    );
    try {
      final next = await _load(
        repository,
        cancelToken,
        _ownNumbers,
        previous: current,
      );
      if (ref.mounted && !cancelToken.isCancelled) state = AsyncData(next);
    } catch (_) {
      if (ref.mounted && !cancelToken.isCancelled) {
        state = AsyncData(
          HistoryData(
            items: current.items,
            nextSkip: current.nextSkip,
            loadMoreFailed: true,
          ),
        );
      }
    }
  }

  Future<HistoryData> _load(
    OperationsRepository repository,
    CancelToken cancelToken,
    Future<Set<String>> ownNumbers, {
    HistoryData? previous,
  }) async {
    final owned = await ownNumbers;
    final page = await repository.fetchHistory(
      query.session,
      skip: previous?.nextSkip ?? 0,
      type: query.type,
      accountNumber: query.accountNumber,
      cancelToken: cancelToken,
    );
    final visible = {
      for (final movement in previous?.items ?? const <OperationReceipt>[])
        movement.id: movement,
    };
    for (final movement in page.items.where(
      (movement) => _matches(movement, owned),
    )) {
      visible.putIfAbsent(movement.id, () => movement);
    }
    return HistoryData(
      items: List.unmodifiable(visible.values),
      nextSkip: page.nextSkip,
    );
  }

  bool _matches(OperationReceipt movement, Set<String> owned) {
    if (query.scope case final scope?) {
      final isOwn =
          owned.contains(movement.sourceAccount) &&
          owned.contains(movement.destinationAccount);
      if (movement.type != FinancialOperationType.transfer ||
          (scope == HistoryScope.ownAccounts) != isOwn) {
        return false;
      }
    }
    return query.search.isEmpty ||
        [
          movement.sourceAccount,
          movement.destinationAccount,
          movement.id,
          movement.correlationId,
        ].whereType<String>().any(
          (value) => value.toLowerCase().contains(query.search),
        );
  }
}
