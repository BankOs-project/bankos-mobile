import 'package:uuid/uuid.dart';

import '../../../accounts/domain/models/session_account.dart';

enum FinancialOperationType {
  transfer('TRANSFER', 'Transferencia', 'transfer'),
  deposit('DEPOSIT', 'Depósito', 'deposit'),
  withdrawal('WITHDRAWAL', 'Retiro', 'withdraw');

  const FinancialOperationType(this.apiValue, this.label, this.endpoint);

  final String apiValue;
  final String label;
  final String endpoint;

  bool get requiresDeviceAuth => this != deposit;
}

enum TransferMode {
  sameBank('SAME_BANK', 'Mismo banco'),
  otherBank('OTHER_BANK', 'Otro banco');

  const TransferMode(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static TransferMode? fromApi(Object? value) => switch (value) {
    'SAME_BANK' => sameBank,
    'OTHER_BANK' => otherBank,
    _ => null,
  };
}

class OperationDraft {
  const OperationDraft({
    required this.type,
    required this.accountNumber,
    required this.amount,
    this.destinationNumber,
    this.transferMode = TransferMode.sameBank,
    this.destinationBankId,
  });

  final FinancialOperationType type;
  final String accountNumber;
  final String? destinationNumber;
  final TransferMode transferMode;
  final String? destinationBankId;
  final String amount;

  Map<String, String> get quoteBody => {
    'operation_type': type.apiValue,
    'source_account_number': accountNumber,
    'destination_account_number': ?destinationNumber,
    if (type == FinancialOperationType.transfer)
      'transfer_mode': transferMode.apiValue,
    'destination_bank_id': ?destinationBankId,
    'amount': amount,
  };

  Map<String, String> get executionBody => {
    if (type == FinancialOperationType.transfer) ...{
      'source_account_number': accountNumber,
      'destination_account_number': destinationNumber!,
    } else
      'account_number': accountNumber,
    'amount': amount,
  };
}

class TransferDestination {
  TransferDestination.fromJson(Map<String, dynamic> json)
    : accountNumber = json['account_number'] as String,
      holderName = json['holder_name'] as String,
      currency = json['currency'] as String;

  final String accountNumber;
  final String holderName;
  final String currency;

  String get maskedHolderName {
    final words = holderName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    if (words.isEmpty) return '***';
    return words
        .take(3)
        .map((word) => '${String.fromCharCode(word.runes.first)}***')
        .join(' ');
  }
}

class QuotedRecipient {
  QuotedRecipient.fromJson(Map<String, dynamic> json)
    : bankName = json['bank_name'] as String,
      maskedHolderName = json['masked_holder_name'] as String,
      lastFour = json['account_last_four'] as String;

  final String bankName;
  final String maskedHolderName;
  final String lastFour;
}

class OperationQuote {
  OperationQuote.fromJson(Map<String, dynamic> json)
    : debit = parseMoneyUnits(json['amount_to_debit']),
      fee = parseMoneyUnits(json['fee_calculated']),
      rate = json['exchange_rate_applied'] as String,
      received = parseMoneyUnits(json['final_amount_to_receive']),
      sourceCurrency = json['source_currency'] as String,
      destinationCurrency = json['destination_currency'] as String,
      amount = parseMoneyUnits(json['original_amount']),
      id = json['quote_id'] as String?,
      expiresAt = DateTime.tryParse('${json['expires_at']}'),
      transferMode = TransferMode.fromApi(json['transfer_mode']),
      recipient = switch (json['recipient']) {
        final Map<String, dynamic> value => QuotedRecipient.fromJson(value),
        _ => null,
      };

  final BigInt debit;
  final BigInt fee;
  final String rate;
  final BigInt received;
  final String sourceCurrency;
  final String destinationCurrency;
  final BigInt amount;
  final String? id;
  final DateTime? expiresAt;
  final TransferMode? transferMode;
  final QuotedRecipient? recipient;

  bool get expired => !(expiresAt?.isAfter(DateTime.now()) ?? true);
}

class ConfirmedOperation {
  ConfirmedOperation(OperationDraft draft, {String? quoteId})
    : type = draft.type,
      body = Map.unmodifiable(
        quoteId == null ? draft.executionBody : {'quote_id': quoteId},
      ),
      idempotencyKey = const Uuid().v4(),
      correlationId = const Uuid().v4(),
      createdAt = DateTime.now().toUtc();

  ConfirmedOperation.fromJson(Map<String, dynamic> json)
    : type = FinancialOperationType.values.byName(json['type'] as String),
      body = Map.unmodifiable((json['body'] as Map).cast<String, String>()),
      idempotencyKey = json['idempotency_key'] as String,
      correlationId = json['correlation_id'] as String,
      createdAt = DateTime.parse(json['created_at'] as String);

  final FinancialOperationType type;
  final Map<String, String> body;
  final String idempotencyKey;
  final String correlationId;
  final DateTime createdAt;

  bool get canRetry =>
      DateTime.now().difference(createdAt) < const Duration(hours: 24);

  Map<String, Object> toJson() => {
    'type': type.name,
    'body': body,
    'idempotency_key': idempotencyKey,
    'correlation_id': correlationId,
    'created_at': createdAt.toIso8601String(),
  };
}

class OperationReceipt {
  OperationReceipt.fromJson(Map<String, dynamic> json, this.type)
    : id = json['id'] as String,
      status = json['status'] as String,
      createdAt = DateTime.parse(json['created_at'] as String),
      sourceAccount = json['source_account_number'] as String?,
      destinationAccount = json['destination_account_number'] as String?,
      amount = parseMoneyUnits(json['original_amount']),
      sourceCurrency = json['original_currency'] as String,
      received = parseMoneyUnits(json['converted_amount']),
      destinationCurrency = json['destination_currency'] as String,
      fee = parseMoneyUnits(json['fee_charged']),
      rate = json['exchange_rate_applied'] as String,
      idempotencyKey = json['idempotency_key'] as String,
      correlationId = json['correlation_id'] as String,
      transferMode = TransferMode.fromApi(json['transfer_mode']),
      transferReference = json['transfer_reference'] as String?;

  final FinancialOperationType type;
  final String id;
  final String status;
  final DateTime createdAt;
  final String? sourceAccount;
  final String? destinationAccount;
  final BigInt amount;
  final String sourceCurrency;
  final BigInt received;
  final String destinationCurrency;
  final BigInt fee;
  final String rate;
  final String idempotencyKey;
  final String correlationId;
  final TransferMode? transferMode;
  final String? transferReference;

  bool get isConfirmedTransfer =>
      type == FinancialOperationType.transfer && status == 'SUCCESS';

  BigInt get debit =>
      type == FinancialOperationType.deposit ? BigInt.zero : amount + fee;

  String get title => switch (type) {
    FinancialOperationType.transfer => 'Transferencia exitosa',
    FinancialOperationType.deposit => 'Depósito exitoso',
    FinancialOperationType.withdrawal => 'Retiro exitoso',
  };

  Map<String, String> get details => {
    'Referencia': id,
    if (transferMode == TransferMode.otherBank)
      'Modalidad': 'Otro banco · Simulación',
    'Referencia de transferencia': ?transferReference,
    'Fecha': createdAt.toLocal().toString().split('.').first,
    if (sourceAccount case final account?)
      'Cuenta origen': maskAccountNumber(account),
    if (destinationAccount case final account?)
      'Cuenta destino': maskAccountNumber(account),
    if (type != FinancialOperationType.transfer || sourceAccount != null)
      'Total debitado': formatAccountBalance(debit, sourceCurrency),
    'Comisión': formatAccountBalance(fee, sourceCurrency),
    'Tasa': '1 $sourceCurrency = $rate $destinationCurrency',
    'Importe recibido': formatAccountBalance(received, destinationCurrency),
    'Identificador de seguimiento': correlationId,
  };

  String toShareableText() => [
    'BankOS · $title',
    for (final field in details.entries) '${field.key}: ${field.value}',
  ].join('\n');
}

String maskAccountNumber(String number) =>
    number.length > 4 ? '•••• ${number.substring(number.length - 4)}' : number;
