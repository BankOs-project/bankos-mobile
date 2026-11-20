import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../accounts/presentation/providers/session_accounts_provider.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/operations_repository.dart';
import '../../data/repositories/pending_operations_store.dart';
import '../../domain/models/transaction_models.dart';

final operationsRepositoryProvider = Provider<OperationsRepository>(
  (ref) => OperationsRepository(ref.watch(dioProvider)),
);

final pendingOperationsStoreProvider = Provider<PendingOperationsStore>(
  (ref) => PendingOperationsStore(ref.watch(mobileSecureStorageProvider)),
);

final confirmWithDeviceProvider = Provider<Future<bool> Function()>((ref) {
  final auth = LocalAuthentication();
  return () => auth.authenticate(
    localizedReason: 'Confirma la operación con el bloqueo de tu dispositivo.',
  );
});

class OperationState {
  const OperationState({
    this.pending,
    this.receipt,
    this.message,
    this.sending = false,
    this.rejected = false,
  });

  final ConfirmedOperation? pending;
  final OperationReceipt? receipt;
  final String? message;
  final bool sending;
  final bool rejected;

  bool get needsCleanup => pending != null && (receipt != null || rejected);
}

final operationsProvider =
    AsyncNotifierProvider<OperationsNotifier, OperationState>(
      OperationsNotifier.new,
      retry: (_, _) => null,
    );

final activeReceiptProvider = Provider<OperationReceipt?>((ref) {
  final operation = ref.watch(operationsProvider);
  return operation.isLoading ? null : operation.asData?.value.receipt;
});

class OperationsNotifier extends AsyncNotifier<OperationState> {
  @override
  Future<OperationState> build() async {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const OperationState();
    final pending = await ref
        .watch(pendingOperationsStoreProvider)
        .read(session);
    return OperationState(pending: pending);
  }

  Future<void> submit(AuthSession session, OperationDraft draft) async {
    final current = state.asData?.value;
    if (!_isCurrent(session) ||
        state.isLoading ||
        current == null ||
        current.sending ||
        current.pending != null) {
      return;
    }

    if (draft.type.requiresDeviceAuth) {
      state = const AsyncData(OperationState(sending: true));
      var confirmed = false;
      try {
        confirmed = await ref.read(confirmWithDeviceProvider)();
      } catch (_) {
        // Si el dispositivo no puede autenticar, la operación queda sin enviar.
      }
      if (!_isCurrent(session)) return;
      if (!confirmed) {
        state = const AsyncData(
          OperationState(
            message:
                'Confirma con el bloqueo de tu dispositivo para continuar.',
          ),
        );
        return;
      }
    }

    final operation = ConfirmedOperation(draft);
    state = AsyncData(OperationState(pending: operation, sending: true));
    try {
      await ref.read(pendingOperationsStoreProvider).save(session, operation);
    } catch (_) {
      if (_isCurrent(session)) {
        state = const AsyncData(
          OperationState(
            message:
                'No se pudo guardar la confirmación. La operación no se envió.',
          ),
        );
      }
      return;
    }
    if (_isCurrent(session)) await _send(session, operation);
  }

  Future<void> retry() async {
    final session = ref.read(activeSessionProvider);
    final current = state.asData?.value;
    final operation = current?.pending;
    if (state.isLoading ||
        session == null ||
        current == null ||
        operation == null ||
        current.sending) {
      return;
    }
    if (!current.needsCleanup && !operation.canRetry) {
      state = AsyncData(OperationState(pending: operation));
      return;
    }

    state = AsyncData(
      OperationState(
        pending: operation,
        sending: true,
        receipt: current.receipt,
        rejected: current.rejected,
        message: current.message,
      ),
    );
    if (current.needsCleanup) {
      await _finish(
        session,
        operation,
        receipt: current.receipt,
        rejection: current.rejected ? current.message : null,
      );
    } else {
      await _send(session, operation);
    }
  }

  Future<void> _send(AuthSession session, ConfirmedOperation operation) async {
    try {
      final receipt = await ref
          .read(operationsRepositoryProvider)
          .execute(session, operation);
      if (!_isCurrent(session)) return;
      ref.invalidate(sessionAccountsProvider(session));
      await _finish(session, operation, receipt: receipt);
    } on OperationRejected catch (error) {
      if (_isCurrent(session)) {
        await _finish(session, operation, rejection: error.message);
      }
    } catch (_) {
      if (_isCurrent(session)) {
        state = AsyncData(OperationState(pending: operation));
      }
    }
  }

  Future<void> _finish(
    AuthSession session,
    ConfirmedOperation operation, {
    OperationReceipt? receipt,
    String? rejection,
  }) async {
    ConfirmedOperation? pending;
    try {
      await ref.read(pendingOperationsStoreProvider).clear(session);
    } catch (_) {
      pending = operation;
    }
    if (_isCurrent(session)) {
      state = AsyncData(
        OperationState(
          pending: pending,
          receipt: receipt,
          message: rejection,
          rejected: rejection != null,
        ),
      );
    }
  }

  bool _isCurrent(AuthSession session) =>
      ref.mounted && identical(ref.read(activeSessionProvider), session);
}
