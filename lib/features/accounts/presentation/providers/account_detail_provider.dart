import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/models/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/session_account.dart';
import 'dashboard_finances_provider.dart';
import 'session_accounts_provider.dart';

typedef AccountQuery = ({AuthSession session, String number});

final accountDetailProvider = FutureProvider.autoDispose
    .family<SessionAccount, AccountQuery>((ref, query) {
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      return ref
          .watch(accountsRepositoryProvider)
          .fetchAccount(query.session, query.number, cancelToken: cancel);
    }, retry: (_, _) => null);

final changeAccountStatusProvider =
    Provider<Future<void> Function(AccountQuery query, bool reactivate)>((ref) {
      return (query, reactivate) async {
        if (!identical(ref.read(activeSessionProvider), query.session)) return;
        try {
          await ref
              .read(accountsRepositoryProvider)
              .changeStatus(
                query.session,
                query.number,
                reactivate: reactivate,
              );
        } finally {
          // Un fallo de red puede ocurrir después de que el servidor cambió el estado.
          if (ref.mounted &&
              identical(ref.read(activeSessionProvider), query.session)) {
            ref.invalidate(accountDetailProvider(query));
            ref.invalidate(sessionAccountsProvider(query.session));
            ref.invalidate(financialSummaryProvider);
          }
        }
      };
    });
