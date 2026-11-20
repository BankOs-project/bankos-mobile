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

class OperationDraft {
  const OperationDraft({
    required this.type,
    required this.accountNumber,
    required this.amount,
    this.destinationNumber,
  });

  final FinancialOperationType type;
  final String accountNumber;
  final String? destinationNumber;
  final String amount;

  Map<String, String> get quoteBody => {
    'operation_type': type.apiValue,
    'source_account_number': accountNumber,
    'destination_account_number': ?destinationNumber,
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
}

class OperationQuote {
  OperationQuote.fromJson(Map<String, dynamic> json)
    : debit = parseMoneyUnits(json['amount_to_debit']),
      fee = parseMoneyUnits(json['fee_calculated']),
      rate = json['exchange_rate_applied'] as String,
      received = parseMoneyUnits(json['final_amount_to_receive']),
      sourceCurrency = json['source_currency'] as String,
      destinationCurrency = json['destination_currency'] as String;

  final BigInt debit;
  final BigInt fee;
  final String rate;
  final BigInt received;
  final String sourceCurrency;
  final String destinationCurrency;
}

class ConfirmedOperation {
  ConfirmedOperation(OperationDraft draft)
    : type = draft.type,
      body = Map.unmodifiable(draft.executionBody),
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
      correlationId = json['correlation_id'] as String;

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

  BigInt get debit =>
      type == FinancialOperationType.deposit ? BigInt.zero : amount + fee;

  String get title => switch (type) {
    FinancialOperationType.transfer => 'Transferencia exitosa',
    FinancialOperationType.deposit => 'Depósito exitoso',
    FinancialOperationType.withdrawal => 'Retiro exitoso',
  };

  Map<String, String> get details => {
    'Referencia': id,
    'Fecha': createdAt.toLocal().toString().split('.').first,
    if (sourceAccount case final account?)
      'Cuenta origen': maskAccountNumber(account),
    if (destinationAccount case final account?)
      'Cuenta destino': maskAccountNumber(account),
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
