import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../accounts/presentation/providers/accounts_mock_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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

/// Ajustes de saldo de demostración para la sesión activa.
class AccountBalanceDeltasNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    ref.watch(activeSessionProvider);
    return const {};
  }

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

/// Cuentas de demostración para los selectores de transferencias del banco activo.
final managedAccountsProvider = Provider<List<ManagedBankAccount>>((ref) {
  final bankName = ref.watch(activeSessionProvider)?.bankLabel ?? 'BankOs';
  final baseAccounts = ref.watch(accountsMockProvider);
  final deltas = ref.watch(accountBalanceDeltasProvider);

  final mapped = <ManagedBankAccount>[];

  for (final account in baseAccounts) {
    final isCop = account.currency.toUpperCase() == 'COP';
    final isUsd = account.currency.toUpperCase() == 'USD';
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

  // Cuentas adicionales en COP para probar traslados dentro del banco activo.
  final extraCopAccounts = [
    ManagedBankAccount(
      bankName: bankName,
      title: 'Cuenta Ahorros',
      accountNumber: '**** 3310',
      currency: 'COP',
      balance: 1850000 + (deltas['**** 3310'] ?? 0),
      status: 'ACTIVA',
      accentColor: AppTheme.errorColor,
    ),
    ManagedBankAccount(
      bankName: bankName,
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

/// Beneficiarios sugeridos para transferencias internas del Core Bancario (Tenant).
final tenantBeneficiariesProvider = Provider<List<BeneficiaryAccount>>((ref) {
  return const [
    BeneficiaryAccount(
      name: 'Carlos Ramírez',
      accountNumber: '**** 9845',
      currency: 'COP',
      accountType: 'Ahorros',
    ),
    BeneficiaryAccount(
      name: 'María Gómez',
      accountNumber: '**** 3310',
      currency: 'USD',
      accountType: 'Corriente',
    ),
    BeneficiaryAccount(
      name: 'Laura Torres',
      accountNumber: '**** 7742',
      currency: 'COP',
      accountType: 'Ahorros',
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
    final bankName = ref.watch(activeSessionProvider)?.bankLabel ?? 'BankOs';
    _sequence = 1007;
    return [
      TransactionRecord(
        id: 'txn-1006',
        referenceCode: 'BO-2026-1006',
        scope: TransferScope.ownAccounts,
        direction: MovementDirection.internalTransfer,
        title: 'Traslado entre mis cuentas',
        description: 'Ahorro mensual',
        tenantName: bankName,
        sourceBankName: bankName,
        sourceAccountNumber: '**** 8821',
        sourceAccountTitle: 'Billetera Local',
        destinationBankName: bankName,
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
        tenantName: bankName,
        sourceBankName: bankName,
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
        tenantName: bankName,
        sourceBankName: 'Davivienda',
        sourceAccountNumber: '**** 9120',
        sourceAccountTitle: 'Cuenta externa',
        destinationBankName: bankName,
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
        tenantName: bankName,
        sourceBankName: bankName,
        sourceAccountNumber: '**** 3310',
        sourceAccountTitle: 'Cuenta Ahorros',
        destinationBankName: bankName,
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
        tenantName: bankName,
        sourceBankName: bankName,
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
        tenantName: bankName,
        sourceBankName: 'Nu Colombia',
        sourceAccountNumber: '**** 6044',
        sourceAccountTitle: 'Cuenta externa',
        destinationBankName: bankName,
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

  /// Ejecuta cualquier operación financiera del Core Bancario (Depósito, Retiro o Transferencia).
  TransactionRecord executeOperation({
    required FinancialOperationType operationType,
    required ManagedBankAccount sourceAccount,
    ManagedBankAccount? destinationOwnAccount,
    String? destinationAccountNumber,
    String? destinationHolderName,
    String? destinationBankName,
    required TransactionQuote quote,
    required String description,
    String? customIdempotencyKey,
  }) {
    final seq = _sequence++;
    final now = DateTime.now();
    final deltasNotifier = ref.read(accountBalanceDeltasProvider.notifier);

    final MovementDirection direction;
    final String title;
    final String resolvedDestBank = destinationOwnAccount?.bankName ??
        destinationBankName ??
        sourceAccount.bankName;
    final String resolvedDestAccount = destinationOwnAccount?.accountNumber ??
        destinationAccountNumber ??
        sourceAccount.accountNumber;
    final String resolvedDestHolder = destinationOwnAccount?.title ??
        destinationHolderName ??
        sourceAccount.title;

    switch (operationType) {
      case FinancialOperationType.deposit:
        deltasNotifier.applyDelta(sourceAccount.accountNumber, quote.amount);
        direction = MovementDirection.incoming;
        title = 'Depósito a ${sourceAccount.title}';
        break;

      case FinancialOperationType.withdrawal:
        deltasNotifier.applyDelta(sourceAccount.accountNumber, -quote.amount);
        direction = MovementDirection.outgoing;
        title = 'Retiro de ${sourceAccount.title}';
        break;

      case FinancialOperationType.transfer:
        deltasNotifier.applyDelta(sourceAccount.accountNumber, -quote.totalDebit);
        if (destinationOwnAccount != null) {
          deltasNotifier.applyDelta(
            destinationOwnAccount.accountNumber,
            quote.finalAmountReceived,
          );
          direction = MovementDirection.internalTransfer;
          title = 'Traslado a ${destinationOwnAccount.bankName}';
        } else {
          direction = MovementDirection.outgoing;
          title = 'Envío a $resolvedDestHolder';
        }
        break;
    }

    final idempKey = customIdempotencyKey ??
        'idemp-bo-$seq-${now.millisecondsSinceEpoch % 10000}';
    final corrId = 'corr-bo-$seq-${now.millisecondsSinceEpoch % 10000}';

    final record = TransactionRecord(
      id: 'txn-$seq',
      referenceCode: 'BO-${now.year}-$seq',
      operationType: operationType,
      direction: direction,
      title: title,
      description: description.trim().isEmpty
          ? (operationType == FinancialOperationType.deposit
              ? 'Depósito en efectivo / corresponsal'
              : operationType == FinancialOperationType.withdrawal
                  ? 'Retiro en cajero o ventanilla'
                  : (destinationOwnAccount != null
                      ? 'Movimiento entre cuentas propias'
                      : 'Transferencia inmediata'))
          : description.trim(),
      tenantName: sourceAccount.bankName,
      sourceAccountNumber: sourceAccount.accountNumber,
      sourceAccountTitle: sourceAccount.title,
      sourceCurrency: quote.sourceCurrency,
      destinationAccountNumber: resolvedDestAccount,
      destinationHolderName: resolvedDestHolder,
      destinationBankName: operationType == FinancialOperationType.transfer
          ? resolvedDestBank
          : sourceAccount.bankName,
      destinationCurrency: quote.destinationCurrency,
      amount: quote.amount,
      feeCharged: quote.feeAmount,
      exchangeRateApplied: quote.exchangeRate,
      finalAmountCredited: quote.finalAmountReceived,
      status: 'COMPLETADA',
      idempotencyKey: idempKey,
      correlationId: corrId,
      createdAt: now,
    );

    state = [record, ...state];
    ref.read(selectedTransactionProvider.notifier).select(record);
    return record;
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
    String? customIdempotencyKey,
  }) {
    return executeOperation(
      operationType: FinancialOperationType.transfer,
      sourceAccount: sourceAccount,
      destinationOwnAccount: destinationOwnAccount,
      destinationAccountNumber: destinationKey,
      destinationHolderName: destinationLabel,
      destinationBankName: destinationBankName,
      quote: quote,
      description: description,
      customIdempotencyKey: customIdempotencyKey,
    );
  }
}

final transactionsHistoryProvider =
    NotifierProvider<TransactionsHistoryNotifier, List<TransactionRecord>>(
  TransactionsHistoryNotifier.new,
);

/// Comprobante actualmente seleccionado para `SummaryScreen`.
class SelectedTransactionNotifier extends Notifier<TransactionRecord?> {
  @override
  TransactionRecord? build() {
    ref.watch(activeSessionProvider);
    return null;
  }

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

/// Filtros del historial: operación, banco seleccionado y búsqueda de texto.
class HistoryOperationFilterNotifier
    extends Notifier<FinancialOperationType?> {
  @override
  FinancialOperationType? build() {
    ref.watch(activeSessionProvider);
    return null;
  }

  void setOperation(FinancialOperationType? type) => state = type;
}

final historyOperationFilterProvider =
    NotifierProvider<HistoryOperationFilterNotifier, FinancialOperationType?>(
  HistoryOperationFilterNotifier.new,
);

class HistoryBankFilterNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(activeSessionProvider);
    return null;
  }

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

/// Historial filtrado por operación, banco, tipo (personal/externo) y búsqueda libre.
final filteredTransactionsProvider = Provider<List<TransactionRecord>>((ref) {
  final all = ref.watch(transactionsHistoryProvider);
  final opFilter = ref.watch(historyOperationFilterProvider);
  final bankFilter = ref.watch(historyBankFilterProvider);
  final scopeFilter = ref.watch(historyScopeFilterProvider);
  final query = ref.watch(historySearchQueryProvider).trim().toLowerCase();

  return all.where((tx) {
    if (opFilter != null && tx.operationType != opFilter) {
      return false;
    }
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
