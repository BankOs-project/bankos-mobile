import 'package:flutter/material.dart';

class DashboardChartsSection extends StatelessWidget {
  const DashboardChartsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Gráficos y análisis', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Icon(
              Icons.bar_chart_rounded,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Gráficos pendientes'),
            subtitle: const Text(
              'Se mostrarán con datos reales del historial.',
            ),
          ),
        ),
      ],
    );
  }
}
