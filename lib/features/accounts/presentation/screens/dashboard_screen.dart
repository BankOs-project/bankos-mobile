import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/theme/bank_surface_card.dart';
import '../../../../core/theme/bank_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/bank_logo.dart';
import '../widgets/dashboard_accounts_carousel.dart';
import '../widgets/dashboard_finances_section.dart';
import '../widgets/dashboard_quick_actions.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final profile = ref.watch(customerNameProvider);
    final customerName = profile.isLoading ? null : profile.asData?.value;
    final theme = Theme.of(context);
    final brand = theme.extension<BankSurfaceColors>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BankLogo(
              bankName: session?.bankLabel,
              logoUrl: session?.bankLogoUrl,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                session?.bankLabel ?? 'BankOs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No tienes notificaciones pendientes'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Abrir menú',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => context.push('/menu'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            MediaQuery.textScalerOf(context).scale(24) * 2 + 16,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                '¡Hola, ${customerName ?? session?.email ?? 'cliente'}!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: brand?.onFill ?? theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 24,
            children: [
              const BankSurfaceCard(
                child: ListTile(
                  leading: Icon(Icons.key_rounded),
                  title: Text('Crea tu llave Bre-B'),
                  subtitle: Text('Próximamente'),
                ),
              ),
              if (session != null)
                DashboardAccountsCarousel(
                  key: ObjectKey(session),
                  session: session,
                ),
              const DashboardQuickActions(),
              if (session != null) DashboardFinancesSection(session: session),
            ],
          ),
        ),
      ),
    );
  }
}
