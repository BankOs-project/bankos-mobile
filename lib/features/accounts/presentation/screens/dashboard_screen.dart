import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounts_mock_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsMockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('BankOs - Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¡Hola, Tenant Principal!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Tienes ${accounts.length} cuentas registradas.'),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text(accounts.first.title),
                subtitle: Text(accounts.first.accountNumber),
                trailing: Text('${accounts.first.currency} \$${accounts.first.balance}'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Acciones Rápidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                ref.read(bottomNavIndexProvider.notifier).state = 1;
                context.go('/accounts');
              },
              child: const Text('Ver mis cuentas'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.go('/transactions/transfer'),
              child: const Text('Transferir'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.go('/operations'),
              child: const Text('Depósito'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.go('/history'),
              child: const Text('Historial'),
            ),
          ],
        ),
      ),
    );
  }
}
