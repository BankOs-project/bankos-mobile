import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Text(
              'Movimientos Recientes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(Icons.arrow_downward, color: Colors.green),
                title: Text('Depósito Recibido'),
                subtitle: Text('12 Nov 2026 - USD'),
                trailing: Text('+ \$500.00', style: TextStyle(color: Colors.green)),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.arrow_upward, color: Colors.red),
                title: Text('Transferencia Enviada'),
                subtitle: Text('11 Nov 2026 - COP'),
                trailing: Text('- \$150,000', style: TextStyle(color: Colors.red)),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.shopping_bag, color: Colors.blue),
                title: Text('Pago de Servicio'),
                subtitle: Text('10 Nov 2026 - USD'),
                trailing: Text('- \$80.00'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
