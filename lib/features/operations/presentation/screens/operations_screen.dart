import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OperationsScreen extends StatelessWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operaciones')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Menú de Operaciones',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.send),
                title: const Text('Transferir Dinero'),
                subtitle: const Text('Enviar a otra cuenta'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => context.push('/transactions/transfer'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Depositar dinero'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => context.go('/transactions/transfer?type=deposit'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.money_outlined),
                title: const Text('Retirar dinero'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () =>
                    context.go('/transactions/transfer?type=withdrawal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
