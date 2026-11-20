import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class SessionStartupScreen extends ConsumerWidget {
  const SessionStartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(authProvider.select((state) => state.startup));
    final auth = ref.read(authProvider.notifier);
    final cleanupFailed = startup == SessionStartup.cleanupFailed;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                startup == SessionStartup.checking ||
                    startup == SessionStartup.ready
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Verificando sesión…'),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cleanupFailed
                            ? 'No pudimos borrar la sesión guardada.'
                            : 'No pudimos verificar tu sesión.',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (!cleanupFailed)
                        const Text(
                          'Comprueba tu conexión y vuelve a intentarlo.',
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: cleanupFailed
                            ? () => auth.logout()
                            : auth.restore,
                        child: const Text('Reintentar'),
                      ),
                      if (!cleanupFailed)
                        TextButton(
                          onPressed: () => auth.logout(),
                          child: const Text('Borrar sesión e ir al ingreso'),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
