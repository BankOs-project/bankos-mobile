import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/session_account.dart';
import '../providers/session_accounts_provider.dart';

class SessionAccountsContent extends ConsumerWidget {
  const SessionAccountsContent({super.key, required this.builder});

  final Widget Function(List<SessionAccount>) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const SizedBox.shrink();

    final accountsProvider = sessionAccountsProvider(session);
    return ref
        .watch(accountsProvider)
        .when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Cargando cuentas',
              ),
            ),
          ),
          error: (_, _) => _AccountsMessage(
            message: 'No pudimos cargar tus cuentas.',
            action: TextButton.icon(
              onPressed: () => ref.invalidate(accountsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ),
          data: (accounts) => accounts.isEmpty
              ? const _AccountsMessage(
                  message: 'Aún no tienes cuentas en este banco.',
                )
              : builder(accounts),
        );
  }
}

class _AccountsMessage extends StatelessWidget {
  const _AccountsMessage({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            if (action case final button?)
              Align(alignment: Alignment.centerLeft, child: button),
          ],
        ),
      ),
    );
  }
}
