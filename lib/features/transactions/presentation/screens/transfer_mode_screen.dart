import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TransferModeScreen extends StatelessWidget {
  const TransferModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferir'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/operations');
            }
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_outlined),
                title: const Text('Mismo banco'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    context.push('/transactions/transfer?mode=same-bank'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: const Text('Otro banco'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    context.push('/transactions/transfer?mode=other-bank'),
              ),
            ),
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                leading: Icon(Icons.bolt_outlined),
                title: Text('Bre-B'),
                subtitle: Text('Próximamente'),
                enabled: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
