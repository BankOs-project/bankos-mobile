import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen de Transacción'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Comprobante',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                title: Text('Monto transferido'),
                trailing: Text('\$100.00 USD', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const Card(
              child: ListTile(
                title: Text('Cuenta Destino'),
                trailing: Text('**** 9845'),
              ),
            ),
            const Card(
              child: ListTile(
                title: Text('Estado'),
                trailing: Text('COMPLETADA', style: TextStyle(color: Colors.green)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.go('/dashboard');
              },
              child: const Text('Volver al Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
