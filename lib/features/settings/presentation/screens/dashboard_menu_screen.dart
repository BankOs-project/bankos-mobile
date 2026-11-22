import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class DashboardMenuScreen extends ConsumerWidget {
  const DashboardMenuScreen({super.key});

  void _unavailable(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Funcionalidad aún no disponible'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(authProvider.select((state) => state.isLoading));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú'),
        leading: IconButton(
          tooltip: 'Volver al Dashboard',
          icon: const BackButtonIcon(),
          onPressed: () {
            ScaffoldMessenger.of(context).clearSnackBars();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('Perfil'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      context.push('/menu/profile');
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Configuración general'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      context.push('/menu/settings');
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Documentos y certificados'),
                    onTap: () => _unavailable(context),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded),
                    title: const Text('Ayuda'),
                    onTap: () => _unavailable(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: TextButton.icon(
          onPressed: loading
              ? null
              : () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ref.read(authProvider.notifier).logout();
                },
          icon: const Icon(Icons.power_settings_new_rounded),
          label: const Text(
            'Cerrar sesión',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}
