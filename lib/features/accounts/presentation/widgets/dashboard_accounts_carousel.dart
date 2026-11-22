import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/bank_surface_card.dart';
import '../../../../core/theme/bank_theme.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../domain/models/session_account.dart';
import '../providers/session_accounts_provider.dart';

class DashboardAccountsCarousel extends ConsumerWidget {
  const DashboardAccountsCarousel({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sessionAccountsProvider(session);
    final accounts = ref.watch(provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text('Tus cuentas', style: Theme.of(context).textTheme.titleMedium),
        accounts.when(
          skipLoadingOnRefresh: accounts.hasValue,
          loading: () => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Cargando cuentas',
            ),
          ),
          error: (_, _) => ListTile(
            title: const Text('No pudimos cargar tus cuentas.'),
            subtitle: TextButton(
              onPressed: () => ref.invalidate(provider),
              child: const Text('Reintentar'),
            ),
          ),
          data: (accounts) => accounts.isEmpty
              ? const Text('Todavía no tienes cuentas.')
              : _AccountPages(accounts: accounts),
        ),
      ],
    );
  }
}

class _AccountPages extends StatefulWidget {
  const _AccountPages({required this.accounts});

  final List<SessionAccount> accounts;

  @override
  State<_AccountPages> createState() => _AccountPagesState();
}

class _AccountPagesState extends State<_AccountPages> {
  final _controller = PageController(keepPage: false);
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.accounts.length;
    return Column(
      spacing: 8,
      children: [
        SizedBox(
          height: 44 + MediaQuery.textScalerOf(context).scale(110),
          child: PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (_, index) => _CarouselCard(widget.accounts[index]),
          ),
        ),
        if (count > 1)
          Text(
            'Cuenta ${_page.clamp(0, count - 1) + 1} de $count',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard(this.account);

  final SessionAccount account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onFill = theme.extension<BankSurfaceColors>()?.onFill;
    return BankSurfaceCard(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          '/accounts/${Uri.encodeComponent(account.accountNumber)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                spacing: 8,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined),
                  Expanded(
                    child: Text(
                      account.type ?? account.maskedNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onFill,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              if (account.type != null) Text(account.maskedNumber),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  formatAccountBalance(account.balanceUnits, account.currency),
                  style: theme.textTheme.titleLarge?.copyWith(color: onFill),
                ),
              ),
              Text(account.status.label),
            ],
          ),
        ),
      ),
    );
  }
}
