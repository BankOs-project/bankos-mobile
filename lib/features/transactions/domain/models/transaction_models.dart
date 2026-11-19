import 'package:flutter/material.dart';

/// Tipos de operaciones financieras soportadas en el core bancario BankOS.
enum FinancialOperationType {
  transfer,
  deposit,
  withdrawal;

  String get label => switch (this) {
        FinancialOperationType.transfer => 'Transferencia',
        FinancialOperationType.deposit => 'Depósito',
        FinancialOperationType.withdrawal => 'Retiro',
      };

  IconData get icon => switch (this) {
        FinancialOperationType.transfer => Icons.swap_horiz_rounded,
        FinancialOperationType.deposit => Icons.arrow_downward_rounded,
        FinancialOperationType.withdrawal => Icons.arrow_upward_rounded,
      };
}

/// Alcance de la transferencia iniciada desde el banco activo.
enum TransferScope {
  externalPerson,
  ownAccounts;

  String get label => switch (this) {
        TransferScope.externalPerson => 'A otra cuenta',
        TransferScope.ownAccounts => 'Entre mis cuentas',
      };

  String get shortBadgeLabel => label;

  IconData get icon => switch (this) {
        TransferScope.externalPerson => Icons.person_outline_rounded,
        TransferScope.ownAccounts => Icons.swap_horiz_rounded,
      };
}

/// Dirección contable del movimiento para presentación visual y KPIs.
enum MovementDirection {
  outgoing,
  incoming,
  internalTransfer;

  bool get isIncoming => this == MovementDirection.incoming;
  bool get isInternal => this == MovementDirection.internalTransfer;
}

/// Límites máximos por transacción configurables por Tenant.
class TenantLimits {
  const TenantLimits._();

  static const double maxLimitCop = 5000000; // $5.000.000 COP
  static const double maxLimitUsd = 1250; // $1.250 USD
  static const double maxLimitEur = 1150; // €1.150 EUR

  static double maxLimitFor(String currency) {
    return switch (currency.toUpperCase()) {
      'USD' => maxLimitUsd,
      'EUR' => maxLimitEur,
      _ => maxLimitCop,
    };
  }
}

/// Tabla estática de tasas de cambio parametrizada por el Tenant (BaaS).
class TenantExchangeRates {
  const TenantExchangeRates._();

  static double getRate(String fromCurrency, String toCurrency) {
    final from = fromCurrency.toUpperCase();
    final to = toCurrency.toUpperCase();
    if (from == to) return 1.0;

    if (from == 'USD' && to == 'COP') return 4000.0;
    if (from == 'COP' && to == 'USD') return 1.0 / 4000.0;
    if (from == 'EUR' && to == 'USD') return 1.08;
    if (from == 'USD' && to == 'EUR') return 1.0 / 1.08;
    if (from == 'EUR' && to == 'COP') return 4320.0;
    if (from == 'COP' && to == 'EUR') return 1.0 / 4320.0;

    return 1.0;
  }
}

/// Política de comisión parametrizada por Tenant (fija o porcentual).
enum FeePolicyType { zero, fixed, percentage }

class FeePolicy {
  final FeePolicyType type;
  final double value;

  const FeePolicy._({
    required this.type,
    required this.value,
  });

  const FeePolicy.zero() : this._(type: FeePolicyType.zero, value: 0);

  const FeePolicy.fixed(double amount)
      : this._(type: FeePolicyType.fixed, value: amount);

  const FeePolicy.percentage(double percent)
      : this._(type: FeePolicyType.percentage, value: percent);

  double calculateFee(double amount) {
    if (amount <= 0) return 0;
    return switch (type) {
      FeePolicyType.zero => 0,
      FeePolicyType.fixed => value,
      FeePolicyType.percentage => (amount * value) / 100,
    };
  }
}

/// Cuenta bancaria del cliente en su Tenant de BankOS.
class ManagedBankAccount {
  final String bankName;
  final String title;
  final String accountNumber;
  final String currency;
  final double balance;
  final String status;
  final Color accentColor;

  const ManagedBankAccount({
    required this.bankName,
    required this.title,
    required this.accountNumber,
    required this.currency,
    required this.balance,
    required this.status,
    required this.accentColor,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVA';

  String get displayLabel => '$title · $accountNumber';

  /// Nombre y tipo unificado con los últimos dígitos: `Banco Andino - Local (**8821)`.
  String get formattedAccountSummary => CurrencyFormatter.formatAccountDisplay(
        bankName: bankName,
        title: title,
        accountNumber: accountNumber,
      );

  ManagedBankAccount copyWith({double? balance}) {
    return ManagedBankAccount(
      bankName: bankName,
      title: title,
      accountNumber: accountNumber,
      currency: currency,
      balance: balance ?? this.balance,
      status: status,
      accentColor: accentColor,
    );
  }
}

/// Beneficiario sugerido para pruebas de transferencias en el tenant.
class BeneficiaryAccount {
  final String name;
  final String accountNumber;
  final String currency;
  final String accountType;

  const BeneficiaryAccount({
    required this.name,
    required this.accountNumber,
    required this.currency,
    required this.accountType,
  });
}

/// Compatibilidad con selector previo de contactos rápidos.
class QuickRecipient {
  final String name;
  final String keyValue;
  final String bankName;
  final String keyTypeLabel;

  const QuickRecipient({
    required this.name,
    required this.keyValue,
    required this.bankName,
    required this.keyTypeLabel,
  });
}

/// Resultado de la pre-cotización / resumen previo a autorizar con PIN.
class TransactionQuote {
  final FinancialOperationType operationType;
  final String sourceCurrency;
  final String destinationCurrency;
  final double amount;
  final double feeAmount;
  final double exchangeRate;
  final double finalAmountReceived;
  final double totalDebit;
  final bool isCrossCurrency;
  final bool isValid;
  final String? validationError;

  const TransactionQuote({
    required this.operationType,
    required this.sourceCurrency,
    required this.destinationCurrency,
    required this.amount,
    required this.feeAmount,
    required this.exchangeRate,
    required this.finalAmountReceived,
    required this.totalDebit,
    required this.isCrossCurrency,
    required this.isValid,
    this.validationError,
  });

  String get currency => sourceCurrency;

  TransferScope get scope =>
      operationType == FinancialOperationType.transfer
          ? TransferScope.externalPerson
          : TransferScope.ownAccounts;
}

/// Registro histórico y comprobante de una operación bancaria en BankOS.
class TransactionRecord {
  final String id;
  final String referenceCode;
  final FinancialOperationType operationType;
  final TransferScope scope;
  final MovementDirection direction;
  final String title;
  final String description;
  final String tenantName;
  final String sourceBankName;
  final String destinationBankName;
  final String sourceAccountNumber;
  final String sourceAccountTitle;
  final String sourceCurrency;
  final String destinationAccountNumber;
  final String destinationHolderName;
  final String destinationCurrency;
  final double amount;
  final double feeCharged;
  final double exchangeRateApplied;
  final double finalAmountCredited;
  final String status;
  final String idempotencyKey;
  final String correlationId;
  final DateTime createdAt;

  TransactionRecord({
    required this.id,
    required this.referenceCode,
    this.operationType = FinancialOperationType.transfer,
    TransferScope? scope,
    required this.direction,
    required this.title,
    required this.description,
    required this.tenantName,
    String? sourceBankName,
    required this.sourceAccountNumber,
    required this.sourceAccountTitle,
    String? sourceCurrency,
    String? currency,
    String? destinationAccountNumber,
    String? destinationKeyOrAccount,
    String? destinationHolderName,
    String? destinationLabel,
    String? destinationBankName,
    String? destinationCurrency,
    required this.amount,
    this.feeCharged = 0,
    double? exchangeRateApplied,
    double? finalAmountCredited,
    required this.status,
    required this.idempotencyKey,
    String? correlationId,
    required this.createdAt,
  })  : scope = scope ??
            (direction == MovementDirection.internalTransfer
                ? TransferScope.ownAccounts
                : TransferScope.externalPerson),
         sourceBankName = sourceBankName ?? tenantName,
         destinationBankName = destinationBankName ?? tenantName,
        sourceCurrency = (sourceCurrency ?? currency ?? 'COP').toUpperCase(),
        destinationAccountNumber =
            destinationAccountNumber ?? destinationKeyOrAccount ?? '****',
        destinationHolderName =
            destinationHolderName ?? destinationLabel ?? 'Destinatario',
        destinationCurrency = (destinationCurrency ??
                sourceCurrency ??
                currency ??
                'COP')
            .toUpperCase(),
        exchangeRateApplied = exchangeRateApplied ?? 1.0,
        finalAmountCredited = finalAmountCredited ?? amount,
        correlationId = correlationId ?? idempotencyKey;

  bool get hadFee => feeCharged > 0;
  bool get isCrossCurrency =>
      sourceCurrency.toUpperCase() != destinationCurrency.toUpperCase();

  double get totalDebit => amount + feeCharged;
  double get totalAmount => totalDebit;
  String get currency => sourceCurrency;

  String get destinationLabel => destinationHolderName;
  String get destinationKeyOrAccount => destinationAccountNumber;

  bool involvesBank(String bankName) {
    final normalized = bankName.trim().toLowerCase();
    return sourceBankName.trim().toLowerCase() == normalized ||
        destinationBankName.trim().toLowerCase() == normalized;
  }

  String get bankRouteLabel => switch (operationType) {
        FinancialOperationType.transfer =>
          isCrossCurrency
              ? '$sourceCurrency → $destinationCurrency (FX: $exchangeRateApplied)'
              : '$tenantName · Transferencia',
        FinancialOperationType.deposit => '$tenantName · Depósito',
        FinancialOperationType.withdrawal => '$tenantName · Retiro',
      };

  String get formattedSourceAccount => CurrencyFormatter.formatAccountDisplay(
        bankName: sourceBankName,
        title: sourceAccountTitle,
        accountNumber: sourceAccountNumber,
      );

  String get formattedDestinationAccount {
    if (operationType == FinancialOperationType.transfer) {
      return '$destinationHolderName ($destinationAccountNumber)';
    }
    return formattedSourceAccount;
  }

  /// Texto limpio para compartir por WhatsApp, correo o portapapeles.
  String toShareableText() {
    final buffer = StringBuffer()
      ..writeln('BankOS · Comprobante de ${operationType.label}')
      ..writeln('Institución: $tenantName')
      ..writeln('Estado: $status')
      ..writeln('Referencia: $referenceCode')
      ..writeln('Fecha: ${CurrencyFormatter.formatDateTime(createdAt)}')
      ..writeln('Cuenta origen: $formattedSourceAccount');

    if (operationType == FinancialOperationType.transfer) {
      buffer.writeln('Destinatario: $destinationHolderName ($destinationAccountNumber)');
      if (isCrossCurrency) {
        buffer.writeln(
            'Tasa de cambio: 1 $sourceCurrency = $exchangeRateApplied $destinationCurrency');
        buffer.writeln(
            'Monto a recibir: ${CurrencyFormatter.format(finalAmountCredited, destinationCurrency)}');
      }
    }

    buffer.writeln('Monto: ${CurrencyFormatter.format(amount, sourceCurrency)}');
    buffer.writeln('Comisión: ${CurrencyFormatter.format(feeCharged, sourceCurrency)}');
    buffer.writeln('Total debitado: ${CurrencyFormatter.format(totalDebit, sourceCurrency)}');
    buffer.writeln('Idempotency-Key: $idempotencyKey');

    if (description.trim().isNotEmpty) {
      buffer.writeln('Descripción: $description');
    }

    return buffer.toString().trim();
  }
}

/// Utilidades de formato monetario y fecha en Dart puro.
class CurrencyFormatter {
  const CurrencyFormatter._();

  static const List<String> _months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  static String format(
    double amount,
    String currency, {
    bool showCurrencyCode = true,
  }) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final upperCurrency = currency.toUpperCase();

    final String formattedNumber;
    if (upperCurrency == 'COP') {
      final rounded = absAmount.round();
      formattedNumber = _addThousandsSeparator(rounded.toString(), '.');
    } else {
      final fixed = absAmount.toStringAsFixed(2);
      final parts = fixed.split('.');
      final intPart = _addThousandsSeparator(parts[0], ',');
      formattedNumber = '$intPart.${parts[1]}';
    }

    final symbol = upperCurrency == 'EUR' ? '€' : '\$';
    final sign = isNegative ? '-' : '';
    final suffix = showCurrencyCode ? ' $upperCurrency' : '';
    return '$sign$symbol$formattedNumber$suffix';
  }

  static String formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _months[date.month - 1];
    return '$day $month ${date.year}';
  }

  static String formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _months[date.month - 1];
    final hour24 = date.hour;
    final period = hour24 >= 12 ? 'p. m.' : 'a. m.';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day $month ${date.year} · $hour12:$minute $period';
  }

  /// Unifica banco, tipo de cuenta y últimos 4 dígitos: `Banco Andino - Local (**8821)`.
  static String formatAccountDisplay({
    required String bankName,
    required String title,
    required String accountNumber,
  }) {
    final cleanTitle = title
        .replaceAll(
          RegExp(
            r'^(Cuenta|Billetera|Mi Cuenta|Bolsillo)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final cleanDigits = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final masked = cleanDigits.length >= 4
        ? '**${cleanDigits.substring(cleanDigits.length - 4)}'
        : accountNumber.replaceAll('****', '**').replaceAll(' ', '');
    return '$bankName - $cleanTitle ($masked)';
  }

  static double? parseAmountInput(String raw, String currency) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\$\€\s]'), '');
    if (cleaned.isEmpty) return null;

    if (currency.toUpperCase() == 'COP') {
      final normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized);
    }

    final normalized = cleaned.replaceAll(',', '');
    return double.tryParse(normalized);
  }

  static String _addThousandsSeparator(String digits, String separator) {
    if (digits.length <= 3) return digits;
    final buffer = StringBuffer();
    final remainder = digits.length % 3;
    if (remainder > 0) {
      buffer.write(digits.substring(0, remainder));
      if (digits.length > remainder) {
        buffer.write(separator);
      }
    }
    for (var i = remainder; i < digits.length; i += 3) {
      buffer.write(digits.substring(i, i + 3));
      if (i + 3 < digits.length) {
        buffer.write(separator);
      }
    }
    return buffer.toString();
  }
}
