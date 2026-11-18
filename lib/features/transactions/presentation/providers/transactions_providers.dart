import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../accounts/presentation/providers/accounts_mock_provider.dart';
import '../../data/services/quote_calculator_service.dart';
import '../../domain/models/transaction_models.dart';

/// Política de comisión activa. Actualmente sin costo ($0); preparada para
/// conectarse a la configuración del tenant en backend.
final feePolicyProvider = Provider<FeePolicy>((ref) {
  return const FeePolicy.zero();
});

final quoteCalculatorProvider = Provider<QuoteCalculatorService>((ref) {
  return const QuoteCalculatorService();
});

/// Ajustes de saldo en memoria por número de cuenta.
/// Evita modificar `accounts_mock_provider.dart` (módulo de Persona 2) para
/// prevenir conflictos de merge.
class AccountBalanceDeltasNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => const {};

  void applyDelta(String accountNumber, double delta) {
    final current = state[accountNumber] ?? 0;
    state = {
      ...state,
      accountNumber: current + delta,
    };
  }
}

final accountBalanceDeltasProvider =
    NotifierProvider<AccountBalanceDeltasNotifier, Map<String, double>>(
  AccountBalanceDeltasNotifier.new,
);

/// Cuentas gestionadas dentro de la billetera multibanco BankOs.
/// Toma como base `accountsMockProvider`, asigna identidad de banco y suma
/// cuentas adicionales en COP para permitir transferencias reales entre bancos propios.
final managedAccountsProvider = Provider<List<ManagedBankAccount>>((ref) {
  final baseAccounts = ref.watch(accountsMockProvider);
  final deltas = ref.watch(accountBalanceDeltasProvider);

  final mapped = <ManagedBankAccount>[];

  for (final account in baseAccounts) {
    final isCop = account.currency.toUpperCase() == 'COP';
    final isUsd = account.currency.toUpperCase() == 'USD';
    final bankName = isCop
        ? 'Bancolombia'
        : isUsd
            ? 'Nu Colombia'
            : 'Banco de Bogotá';
    final accent = isCop
        ? AppTheme.primaryColor
        : isUsd
            ? AppTheme.secondaryColor
            : AppTheme.tertiaryColor;

    final delta = deltas[account.accountNumber] ?? 0;
    mapped.add(
      ManagedBankAccount(
        bankName: bankName,
        title: account.title,
        accountNumber: account.accountNumber,
        currency: account.currency,
        balance: account.balance + delta,
        status: account.status,
        accentColor: accent,
      ),
    );
  }

  // Cuentas adicionales en COP para pruebas multibanco "Entre mis cuentas".
  final extraCopAccounts = [
    ManagedBankAccount(
      bankName: 'Davivienda',
      title: 'Cuenta Ahorros',
      accountNumber: '**** 3310',
      currency: 'COP',
      balance: 1850000 + (deltas['**** 3310'] ?? 0),
      status: 'ACTIVA',
      accentColor: AppTheme.errorColor,
    ),
    ManagedBankAccount(
      bankName: 'Nequi',
      title: 'Bolsillo Diario',
      accountNumber: '**** 7742',
      currency: 'COP',
      balance: 640000 + (deltas['**** 7742'] ?? 0),
      status: 'ACTIVA',
      accentColor: AppTheme.infoColor,
    ),
  ];

  // Priorizar cuentas COP activas primero para el contexto colombiano.
  final all = [...mapped, ...extraCopAccounts];
  all.sort((a, b) {
    final aScore = (a.isActive ? 0 : 10) + (a.currency == 'COP' ? 0 : 1);
    final bScore = (b.isActive ? 0 : 10) + (b.currency == 'COP' ? 0 : 1);
    return aScore.compareTo(bScore);
  });
  return all;
});

/// Contactos frecuentes con Llave para agilizar pruebas en TransferScreen.
final quickRecipientsProvider = Provider<List<QuickRecipient>>((ref) {
  return const [
    QuickRecipient(
      name: 'María Gómez',
      keyValue: '@maria.gomez',
      bankName: 'Nequi',
      keyTypeLabel: 'Llave',
    ),
    QuickRecipient(
      name: 'Carlos Ramírez',
      keyValue: '300 456 7890',
      bankName: 'Bancolombia',
      keyTypeLabel: 'Celular',
    ),
    QuickRecipient(
      name: 'Laura Torres',
      keyValue: 'laura.torres@correo.co',
      bankName: 'Davivienda',
      keyTypeLabel: 'Correo',
    ),
    QuickRecipient(
      name: 'Andrés Mejía',
      keyValue: '1020456789',
      bankName: 'Nu Colombia',
      keyTypeLabel: 'Documento',
    ),
  ];
});

/// Resultado automático de consultar una Llave (ej. Bre-B, celular, correo o documento).
class ResolvedRecipient {
  final String displayName;
  final String keyValue;
  final String bankName;
  final bool isKnownContact;

  const ResolvedRecipient({
    required this.displayName,
    required this.keyValue,
    required this.bankName,
    required this.isKnownContact,
  });
}

/// Resuelve automáticamente el banco destino (y titular si existe) a partir de la Llave.
ResolvedRecipient? resolveRecipientByKey(
  String rawKey,
  List<QuickRecipient> directory,
) {
  final trimmed = rawKey.trim();
  if (trimmed.length < 3) return null;

  final normalized = trimmed.toLowerCase().replaceAll(' ', '');
  for (final contact in directory) {
    final contactKey = contact.keyValue.toLowerCase().replaceAll(' ', '');
    if (contactKey == normalized) {
      return ResolvedRecipient(
        displayName: contact.name,
        keyValue: contact.keyValue,
        bankName: contact.bankName,
        isKnownContact: true,
      );
    }
  }

  // Resolución determinística demo para cualquier otra llave ingresada.
  const directoryBanks = [
    'Nequi',
    'Bancolombia',
    'Davivienda',
    'Nu Colombia',
    'Banco de Bogotá',
  ];
  final hash = normalized.codeUnits.fold<int>(0, (sum, c) => sum + c);
  final inferredBank = directoryBanks[hash % directoryBanks.length];

  return ResolvedRecipient(
    displayName: trimmed,
    keyValue: trimmed,
    bankName: inferredBank,
    isKnownContact: false,
  );
}

/// Historial de movimientos en memoria (con movimientos iniciales realistas).
class TransactionsHistoryNotifier extends Notifier<List<TransactionRecord>> {
  int _sequence = 1007;

  @override
  List<TransactionRecord> build() {
    return [
      TransactionRecord(
        id: 'txn-1006',
        referenceCode: 'BO-2026-1006',
        scope: TransferScope.ownAccounts,
        direction: MovementDirection.internalTransfer,
        title: 'Traslado entre mis cuentas',
        description: 'Ahorro mensual',
        sourceBankName: 'Bancolombia',
        sourceAccountNumber: '**** 8821',
        sourceAccountTitle: 'Billetera Local',
        destinationBankName: 'Davivienda',
        destinationKeyOrAccount: '**** 3310',
        destinationLabel: 'Mi Cuenta Ahorros',
        amount: 350000,
        currency: 'COP',
        feeCharged: 0,
        status: 'COMPLETADA',
        idempotencyKey: 'idemp-bo-1006',
        createdAt: DateTime(2026, 11, 18, 10, 15),
      ),
      TransactionRecord(
        id: 'txn-1005',
        referenceCode: 'BO-2026-1005',
        scope: TransferScope.externalPerson,
        direction: MovementDirection.outgoing,
        title: 'Envío a María Gómez',
        description: 'Almuerzo equipo',
        sourceBankName: 'Bancolombia',
        sourceAccountNumber: '**** 8821',
        sourceAccountTitle: 'Billetera Local',
        destinationBankName: 'Nequi',
        destinationKeyOrAccount: '@maria.gomez',
        destinationLabel: 'María Gómez',
        amount: 45000,
        currency: 'COP',
        feeCharged: 0,
        status: 'COMPLETADA',
        idempotencyKey: 'idemp-bo-1005',
        createdAt: DateTime(2026, 11, 17, 14, 40),
      ),
      TransactionRecord(
        id: 'txn-1004',
        referenceCode: 'BO-2026-1004',
        scope: TransferScope.externalPerson,
        direction: MovementDirection.incoming,
        title: 'Transferencia recibida · Juan Varela',
        description: 'Pago proyecto compartido',
        sourceBankName: 'Davivienda',
        sourceAccountNumber: '**** 9120',
        sourceAccountTitle: 'Cuenta externa',
        destinationBankName: 'Bancolombia',
        destinationKeyOrAccount: '**** 8821',
        destinationLabel: 'Billetera Local',
        amount: 280000,
        currency: 'COP',
        feeCharged: 0,
        status: 'COMPLETADA',
        idempotencyKey: 'idemp-bo-1004',
        createdAt: DateTime(2026, 11, 16, 18, 22),
      ),
      TransactionRecord(
        id: 'txn-1003',
        referenceCode: 'BO-2026-1003',
        scope: TransferScope.ownAccounts,
        direction: MovementDirection.internalTransfer,
        title: 'Recarga bolsillo diario',
        description: 'Gastos de la semana',
        sourceBankName: 'Davivienda',
        sourceAccountNumber: '**** 3310',
        sourceAccountTitle: 'Cuenta Ahorros',
        destinationBankName: 'Nequi',
        destinationKeyOrAccount: '**** 7742',
        destinationLabel: 'Mi Bolsillo Diario',
        amount: 150000,
        currency: 'COP',
        feeCharged: 0,
        status: 'COMPLETADA',
        idempotencyKey: 'idemp-bo-1003',
        createdAt: DateTime(2026, 11, 15, 9, 5),
      ),
      TransactionRecord(
        id: 'txn-1002',
        referenceCode: 'BO-2026-1002',
        scope: TransferScope.externalPerson,
        direction: MovementDirection.outgoing,
        title: 'Envío a Carlos Ramírez',
        description: 'Cuota transporte',
        sourceBankName: 'Nequi',
        sourceAccountNumber: '**** 7742',
        sourceAccountTitle: 'Bolsillo Diario',
        destinationBankName: 'Bancolombia',
        destinationKeyOrAccount: '300 456 7890',
        destinationLabel: 'Carlos Ramírez',
        amount: 62000,
        currency: 'COP',
        feeCharged: 0,
        status: 'COMPLETADA',
        idempotencyKey: 'idemp-bo-1002',
        createdAt: DateTime(2026, 11, 14, 16, 48),
      ),
      TransactionRecord(
        id: 'txn-1001',
        referenceCode: 'BO-2026-1001',
        scope: TransferScope.externalPerson,
        direction: MovementDirection.incoming,
        title: 'Transferencia recibida · Adriano G.',
        description: 'Reembolso suscripción',
        sourceBankName: 'Nu Colombia',
        sourceAccountNumber: '**** 6044',
        sourceAccountTitle: 'Cuenta externa',
        destinationBankName: 'Nu Colombia',
        destinationKeyOrAccount: '**** 4589',
        destinationLabel: 'Cuenta Principal',
        amount: 120.00,
        currency: 'USD',
        feeCharged: 0,
        status: 'COMPLETADA',
        idempotencyKey: 'idemp-bo-1001',
        createdAt: DateTime(2026, 11, 12, 11, 30),
      ),
    ];
  }

  /// Ejecuta la transferencia en memoria, actualiza saldos y registra comprobante.
  TransactionRecord executeTransfer({
    required TransferScope scope,
    required ManagedBankAccount sourceAccount,
    ManagedBankAccount? destinationOwnAccount,
    required String destinationKey,
    required String destinationLabel,
    required String destinationBankName,
    required TransactionQuote quote,
    required String description,
  }) {
    final seq = _sequence++;
    final now = DateTime.now();

    final deltasNotifier = ref.read(accountBalanceDeltasProvider.notifier);
    deltasNotifier.applyDelta(sourceAccount.accountNumber, -quote.totalDebit);

    if (scope == TransferScope.ownAccounts && destinationOwnAccount != null) {
      deltasNotifier.applyDelta(
        destinationOwnAccount.accountNumber,
        quote.amount,
      );
    }

    final resolvedDestBank = scope == TransferScope.ownAccounts &&
            destinationOwnAccount != null
        ? destinationOwnAccount.bankName
        : destinationBankName;

    final resolvedDestKey = scope == TransferScope.ownAccounts &&
            destinationOwnAccount != null
        ? destinationOwnAccount.accountNumber
        : destinationKey.trim();

    final resolvedDestLabel = scope == TransferScope.ownAccounts &&
            destinationOwnAccount != null
        ? destinationOwnAccount.title
        : (destinationLabel.trim().isNotEmpty
            ? destinationLabel.trim()
            : destinationKey.trim());

    final title = scope == TransferScope.ownAccounts
        ? 'Traslado a $resolvedDestBank'
        : 'Envío a $resolvedDestLabel';

    final record = TransactionRecord(
      id: 'txn-$seq',
      referenceCode: 'BO-${now.year}-$seq',
      scope: scope,
      direction: scope == TransferScope.ownAccounts
          ? MovementDirection.internalTransfer
          : MovementDirection.outgoing,
      title: title,
      description: description.trim().isEmpty
          ? (scope == TransferScope.ownAccounts
              ? 'Movimiento entre cuentas propias'
              : 'Transferencia inmediata')
          : description.trim(),
      sourceBankName: sourceAccount.bankName,
      sourceAccountNumber: sourceAccount.accountNumber,
      sourceAccountTitle: sourceAccount.title,
      destinationBankName: resolvedDestBank,
      destinationKeyOrAccount: resolvedDestKey,
      destinationLabel: resolvedDestLabel,
      amount: quote.amount,
      currency: quote.currency,
      feeCharged: quote.feeAmount,
      status: 'COMPLETADA',
      idempotencyKey: 'idemp-bo-$seq-${now.millisecondsSinceEpoch % 10000}',
      createdAt: now,
    );

    state = [record, ...state];
    ref.read(selectedTransactionProvider.notifier).select(record);
    return record;
  }
}

final transactionsHistoryProvider =
    NotifierProvider<TransactionsHistoryNotifier, List<TransactionRecord>>(
  TransactionsHistoryNotifier.new,
);

/// Comprobante actualmente seleccionado para `SummaryScreen`.
class SelectedTransactionNotifier extends Notifier<TransactionRecord?> {
  @override
  TransactionRecord? build() => null;

  void select(TransactionRecord record) => state = record;
}

final selectedTransactionProvider =
    NotifierProvider<SelectedTransactionNotifier, TransactionRecord?>(
  SelectedTransactionNotifier.new,
);

/// Devuelve el comprobante activo o el movimiento más reciente del historial
/// para que `/transactions/summary` nunca aparezca vacío.
final activeReceiptProvider = Provider<TransactionRecord?>((ref) {
  final selected = ref.watch(selectedTransactionProvider);
  if (selected != null) return selected;
  final history = ref.watch(transactionsHistoryProvider);
  return history.isNotEmpty ? history.first : null;
});

/// Filtros del historial: banco seleccionado (`null` = todos) y búsqueda de texto.
class HistoryBankFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setBank(String? bankName) => state = bankName;
}

final historyBankFilterProvider =
    NotifierProvider<HistoryBankFilterNotifier, String?>(
  HistoryBankFilterNotifier.new,
);

class HistoryScopeFilterNotifier extends Notifier<TransferScope?> {
  @override
  TransferScope? build() => null;

  void setScope(TransferScope? scope) => state = scope;
}

final historyScopeFilterProvider =
    NotifierProvider<HistoryScopeFilterNotifier, TransferScope?>(
  HistoryScopeFilterNotifier.new,
);

class HistorySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final historySearchQueryProvider =
    NotifierProvider<HistorySearchQueryNotifier, String>(
  HistorySearchQueryNotifier.new,
);

/// Lista dinámica de bancos presentes en cuentas e historial para el filtro.
final availableHistoryBanksProvider = Provider<List<String>>((ref) {
  final accounts = ref.watch(managedAccountsProvider);
  final history = ref.watch(transactionsHistoryProvider);
  final banks = <String>{};

  for (final account in accounts) {
    banks.add(account.bankName);
  }
  for (final tx in history) {
    banks.add(tx.sourceBankName);
    banks.add(tx.destinationBankName);
  }

  return banks.toList();
});

/// Historial filtrado por banco, tipo (personal/externo) y búsqueda libre.
final filteredTransactionsProvider = Provider<List<TransactionRecord>>((ref) {
  final all = ref.watch(transactionsHistoryProvider);
  final bankFilter = ref.watch(historyBankFilterProvider);
  final scopeFilter = ref.watch(historyScopeFilterProvider);
  final query = ref.watch(historySearchQueryProvider).trim().toLowerCase();

  return all.where((tx) {
    if (bankFilter != null && !tx.involvesBank(bankFilter)) {
      return false;
    }
    if (scopeFilter != null && tx.scope != scopeFilter) {
      return false;
    }
    if (query.isNotEmpty) {
      final haystack = [
        tx.title,
        tx.description,
        tx.sourceBankName,
        tx.destinationBankName,
        tx.destinationLabel,
        tx.destinationKeyOrAccount,
        tx.referenceCode,
        tx.currency,
      ].join(' ').toLowerCase();
      if (!haystack.contains(query)) return false;
    }
    return true;
  }).toList();
});
