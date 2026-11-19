import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/accounts_horizontal_slider.dart';
import '../widgets/dashboard_charts_section.dart';
import '../widgets/dashboard_kpi_section.dart';
import '../widgets/dashboard_quick_actions.dart';

/// Pantalla principal de Dashboard de BankOs.
/// Incluye:
/// - Slide horizontal de todas las cuentas registradas con redirección interactiva.
/// - Métricas clave (KPIs) con filtro interactivo por fechas (Diario, Mensual, Trimestral, Anual).
/// - Sección de gráficos personalizable mediante menú desplegable con checks.
/// - Accesos rápidos a operaciones del sistema.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(dashboardAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            const Text('BankOs'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Transferir dinero',
            icon: const Icon(Icons.send_rounded, size: 20),
            onPressed: () => context.go('/transactions/transfer'),
          ),
          IconButton(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_none_rounded, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No tienes notificaciones pendientes'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Saludo y encabezado de usuario
              _DashboardUserGreeting(accountsCount: accounts.length),

              const SizedBox(height: 18),

              // 1. Slide horizontal de cuentas
              AccountsHorizontalSlider(accounts: accounts),

              const SizedBox(height: 22),

              // 2. Acciones rápidas (Transferir, Cuentas, Depósito, Historial)
              const DashboardQuickActions(),

              const SizedBox(height: 24),

              // 3. Métricas clave (KPIs) con filtro de fecha interactivo
              const DashboardKpiSection(),

              const SizedBox(height: 24),

              // 4. Sección de gráficos dinámicos con selector desplegable de checks
              const DashboardChartsSection(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saludo al usuario con estado de la billetera multibanco
class _DashboardUserGreeting extends StatelessWidget {
  final int accountsCount;

  const _DashboardUserGreeting({required this.accountsCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.18),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Hola, Tenant Principal!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Billetera Multibanco · $accountsCount cuentas conectadas',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
