import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../data/repositories/accounts_repository.dart';
import '../../domain/models/session_account.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(dioProvider)),
);

final sessionAccountsProvider = FutureProvider.autoDispose
    .family<List<SessionAccount>, AuthSession>((ref, session) {
      final cancelToken = CancelToken();
      ref.onDispose(cancelToken.cancel);
      return ref
          .watch(accountsRepositoryProvider)
          .fetchAccounts(session, cancelToken: cancelToken);
    }, retry: (_, _) => null);
