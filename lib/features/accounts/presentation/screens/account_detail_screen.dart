import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../history/presentation/widgets/movement_list.dart';
import '../../domain/models/session_account.dart';
import '../providers/account_detail_provider.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.number});

  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de cuenta')),
      body: SafeArea(
        child: session == null
            ? const SizedBox.shrink()
            : _AccountDetailBody(
                key: ObjectKey(session),
                query: (session: session, number: number),
              ),
      ),
    );
  }
}

class _AccountDetailBody extends ConsumerWidget {
  const _AccountDetailBody({super.key, required this.query});

  final AccountQuery query;

  Future<void> _copyNumber(BuildContext context, String number) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: number));
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Número de cuenta copiado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = accountDetailProvider(query);
    final detail = ref.watch(provider);
    final account = detail.hasError ? null : detail.value;
    if (account == null) {
      return Center(
        child: detail.isLoading
            ? const CircularProgressIndicator(semanticsLabel: 'Cargando cuenta')
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _accountFailure(
                        detail.error,
                        fallback: 'No pudimos cargar la cuenta.',
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(provider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
      );
    }
    final theme = Theme.of(context);
    final statusColor = switch (account.status) {
      AccountStatus.active => theme.colorScheme.primary,
      AccountStatus.inactive => theme.colorScheme.onSurfaceVariant,
      AccountStatus.blocked => theme.colorScheme.error,
    };

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Text(
                          'Número de cuenta',
                          style: theme.textTheme.labelLarge,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                account.accountNumber,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copiar número de cuenta',
                              icon: const Icon(Icons.copy_rounded),
                              onPressed: () =>
                                  _copyNumber(context, account.accountNumber),
                            ),
                          ],
                        ),
                        Text('Saldo', style: theme.textTheme.labelLarge),
                        Text(
                          formatAccountBalance(
                            account.balanceUnits,
                            account.currency,
                          ),
                          style: theme.textTheme.titleLarge,
                        ),
                        Text('Moneda ${account.currency}'),
                        if (account.type case final type?) Text('Tipo $type'),
                        Text(
                          account.status.label,
                          style: TextStyle(color: statusColor),
                        ),
                        _StatusActions(
                          account: account,
                          query: query,
                          refreshing: detail.isLoading,
                        ),
                      ],
                    ),
                  ),
                ),
                Text('Movimientos', style: theme.textTheme.titleLarge),
              ],
            ),
          ),
        ),
        MovementList(
          query: (
            session: query.session,
            accountNumber: query.number,
            type: null,
            scope: null,
            search: '',
          ),
          owned: {query.number},
          accountDetail: true,
        ),
      ],
    );
  }
}

class _StatusActions extends ConsumerStatefulWidget {
  const _StatusActions({
    required this.account,
    required this.query,
    required this.refreshing,
  });

  final SessionAccount account;
  final AccountQuery query;
  final bool refreshing;

  @override
  ConsumerState<_StatusActions> createState() => _StatusActionsState();
}

class _StatusActionsState extends ConsumerState<_StatusActions> {
  Timer? _cooldownTimer;
  DateTime? _reportedDeadline;
  bool _changing = false;
  String? _notice;

  bool get _isAdmin => widget.query.session.role == 'administrador';
  DateTime? get _deadline =>
      _reportedDeadline ?? widget.account.canDeactivateAt;
  bool get _cooldown =>
      !_isAdmin && (_deadline?.isAfter(DateTime.now()) ?? false);
  bool get _canActivate =>
      widget.account.status == AccountStatus.inactive &&
      (_isAdmin || widget.account.requiresAdminReactivation == false);
  bool get _canDeactivate =>
      widget.account.status == AccountStatus.active && !_cooldown;

  @override
  void initState() {
    super.initState();
    _scheduleCooldown();
  }

  @override
  void didUpdateWidget(covariant _StatusActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.status != widget.account.status ||
        oldWidget.account.requiresAdminReactivation !=
            widget.account.requiresAdminReactivation) {
      _notice = null;
    }
    if (oldWidget.account.status != widget.account.status ||
        oldWidget.account.canDeactivateAt != widget.account.canDeactivateAt) {
      _reportedDeadline = null;
      _scheduleCooldown();
    }
  }

  void _scheduleCooldown() {
    _cooldownTimer?.cancel();
    if (widget.account.status == AccountStatus.active && _cooldown) {
      _cooldownTimer = Timer(_deadline!.difference(DateTime.now()), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirm(bool reactivate) async {
    if (_changing || widget.refreshing) return;
    final action = reactivate ? 'Activar cuenta' : 'Desactivar cuenta';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action),
        content: Text(
          reactivate ? 'Podrás volver a operar con esta cuenta.' : 'La cuenta conservará su saldo y movimientos. Para volver a operar, tendrás que activarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        _changing ||
        widget.refreshing ||
        !(reactivate ? _canActivate : _canDeactivate)) {
      return;
    }
    setState(() {
      _changing = true;
      _notice = null;
    });
    try {
      await ref.read(changeAccountStatusProvider)(widget.query, reactivate);
    } catch (error) {
      if (!mounted) return;
      final body = _errorBody(error);
      final data = body?['data'];
      final cooldownRejected =
          body?['internal_code'] == 'ACCOUNT_DEACTIVATION_COOLDOWN';
      if (cooldownRejected &&
          data is Map &&
          data['can_deactivate_at'] is String) {
        _reportedDeadline = DateTime.tryParse(
          data['can_deactivate_at'] as String,
        );
        _scheduleCooldown();
      }
      setState(() {
        _notice = cooldownRejected && _cooldown
            ? null
            : _accountFailure(
                error,
                fallback: 'No pudimos confirmar el cambio de estado.',
              );
      });
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.account.status;
    final deadline = _deadline;
    final localizations = MaterialLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status == AccountStatus.blocked)
          const Text('El banco debe atender este bloqueo.')
        else if (status == AccountStatus.inactive && !_canActivate)
          const Text('El banco debe reactivar esta cuenta.')
        else if (status == AccountStatus.active &&
            _cooldown &&
            deadline != null)
          Text(
            'Podrás desactivar esta cuenta el ${localizations.formatShortDate(deadline.toLocal())} a las '
            '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(deadline.toLocal()), alwaysUse24HourFormat: true)}:'
            '${deadline.toLocal().second.toString().padLeft(2, '0')} (hora local).',
          )
        else if (_canDeactivate || _canActivate)
          OutlinedButton(
            onPressed: _changing || widget.refreshing
                ? null
                : () => _confirm(_canActivate),
            child: Text(_canActivate ? 'Activar cuenta' : 'Desactivar cuenta'),
          ),
        if (_changing || widget.refreshing)
          const LinearProgressIndicator(semanticsLabel: 'Actualizando cuenta'),
        if (_notice case final notice?)
          Text(
            notice,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

Map<dynamic, dynamic>? _errorBody(Object? error) {
  final body = error is DioException ? error.response?.data : null;
  return body is Map ? body : null;
}

String _accountFailure(Object? error, {required String fallback}) =>
    switch (_errorBody(error)?['internal_code']) {
      'UNAUTHORIZED' => 'Inicia sesión de nuevo para consultar esta cuenta.',
      'AUTHORIZATION_FAILED' => 'Esta cuenta no pertenece a tu sesión.',
      'RESOURCE_NOT_FOUND' => 'La cuenta no está disponible en este banco.',
      'ACCOUNT_BLOCKED' => 'El banco debe atender el bloqueo de esta cuenta.',
      'ACCOUNT_REACTIVATION_REQUIRES_ADMIN' =>
        'El banco debe reactivar esta cuenta.',
      'ACCOUNT_DEACTIVATION_COOLDOWN' =>
        'El plazo de reactivación sigue vigente.',
      _ => fallback,
    };
