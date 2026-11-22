import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/public_bank.dart';
import '../providers/auth_provider.dart';
import '../widgets/bank_logo.dart';

class BankSelectorScreen extends ConsumerStatefulWidget {
  const BankSelectorScreen({super.key});

  @override
  ConsumerState<BankSelectorScreen> createState() => _BankSelectorScreenState();
}

class _BankSelectorScreenState extends ConsumerState<BankSelectorScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(bankDirectoryProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Elige tu banco')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                if (auth.errorMessage case final message?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    onChanged: (value) =>
                        setState(() => _search = normalizeBankSearch(value)),
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: directory.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Cargando bancos',
                      ),
                    ),
                    error: (_, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No pudimos cargar los bancos.'),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(bankDirectoryProvider),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                    data: (banks) {
                      final matches = banks
                          .where(
                            (bank) =>
                                normalizeBankSearch(bank.name)
                                    .contains(_search),
                          )
                          .toList();
                      if (matches.isEmpty) {
                        return Center(
                          child: Text(
                            banks.isEmpty
                                ? 'Por ahora no hay bancos disponibles.'
                                : 'No encontramos bancos con ese nombre.',
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: matches.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final bank = matches[index];
                          return Card(
                            child: ListTile(
                              key: ValueKey(bank.id),
                              enabled: !auth.isLoading,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: BankLogo(logoUrl: bank.logoUrl),
                              title: Text(bank.name),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: auth.isLoading
                                  ? null
                                  : () {
                                      ref
                                          .read(authProvider.notifier)
                                          .clearError();
                                      context.go('/login', extra: bank);
                                    },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
