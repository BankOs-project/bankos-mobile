import 'package:flutter/material.dart';

/// Alcance de la transferencia iniciada desde el banco activo.
enum TransferScope {
  externalPerson,
  ownAccounts;

  String get label => switch (this) {
        TransferScope.externalPerson => 'A otra persona',
        TransferScope.ownAccounts => 'Entre mis cuentas',
      };

  String get shortBadgeLabel => switch (this) {
        TransferScope.externalPerson => 'A otra persona',
        TransferScope.ownAccounts => 'Entre mis cuentas',
      };

  IconData get icon => switch (this) {
        TransferScope.externalPerson => Icons.person_outline_rounded,
        TransferScope.ownAccounts => Icons.swap_horiz_rounded,
      };
}

/// Dirección contable del movimiento para la presentación visual en historial.
enum MovementDirection {
  outgoing,
  incoming,
  internalTransfer;

  bool get isIncoming => this == MovementDirection.incoming;
  bool get isInternal => this == MovementDirection.internalTransfer;
}

/// Política configurable de comisiones.
/// Actualmente opera con [FeePolicy.zero] (sin comisión), dejando lista la
/// lógica de comisión fija o porcentual para futuras reglas desde backend.
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

/// Cuenta bancaria enriquecida con identidad de banco dentro de BankOs.
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

  String get displayLabel => '$bankName · $accountNumber';

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

/// Destinatario frecuente de prueba para agilizar transferencias por Llave.
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

/// Resultado de la pre-cotización / validación antes de autorizar el envío.
class TransactionQuote {
  final TransferScope scope;
  final String currency;
  final double amount;
  final double feeAmount;
  final double totalDebit;
  final bool isValid;
  final String? validationError;

  const TransactionQuote({
    required this.scope,
    required this.currency,
    required this.amount,
    required this.feeAmount,
    required this.totalDebit,
    required this.isValid,
    this.validationError,
  });
}

/// Registro histórico y comprobante de una transacción.
class TransactionRecord {
  final String id;
  final String referenceCode;
  final TransferScope scope;
  final MovementDirection direction;
  final String title;
  final String description;
  final String sourceBankName;
  final String sourceAccountNumber;
  final String sourceAccountTitle;
  final String destinationBankName;
  final String destinationKeyOrAccount;
  final String destinationLabel;
  final double amount;
  final String currency;
  final double feeCharged;
  final String status;
  final String idempotencyKey;
  final DateTime createdAt;

  const TransactionRecord({
    required this.id,
    required this.referenceCode,
    required this.scope,
    required this.direction,
    required this.title,
    required this.description,
    required this.sourceBankName,
    required this.sourceAccountNumber,
    required this.sourceAccountTitle,
    required this.destinationBankName,
    required this.destinationKeyOrAccount,
    required this.destinationLabel,
    required this.amount,
    required this.currency,
    required this.feeCharged,
    required this.status,
    required this.idempotencyKey,
    required this.createdAt,
  });

  double get totalAmount => amount + feeCharged;

  String get bankRouteLabel => '$sourceBankName → $destinationBankName';

  bool involvesBank(String bankName) {
    final normalized = bankName.toLowerCase();
    return sourceBankName.toLowerCase() == normalized ||
        destinationBankName.toLowerCase() == normalized;
  }

  /// Texto limpio para compartir por WhatsApp, correo o portapapeles.
  String toShareableText() {
    final buffer = StringBuffer()
      ..writeln('BankOs · Comprobante de Transferencia')
      ..writeln('Estado: $status')
      ..writeln('Tipo: ${scope.label}')
      ..writeln('Ruta: $bankRouteLabel')
      ..writeln('Monto: ${CurrencyFormatter.format(amount, currency)}')
      ..writeln('Comisión: ${CurrencyFormatter.format(feeCharged, currency)}')
      ..writeln('Total: ${CurrencyFormatter.format(totalAmount, currency)}')
      ..writeln('Origen: $sourceBankName ($sourceAccountNumber)')
      ..writeln('Destino: $destinationLabel ($destinationKeyOrAccount)')
      ..writeln('Banco destino: $destinationBankName')
      ..writeln('Referencia: $referenceCode')
      ..writeln('Fecha: ${CurrencyFormatter.formatDateTime(createdAt)}');

    if (description.trim().isNotEmpty) {
      buffer.writeln('Descripción: $description');
    }

    return buffer.toString().trim();
  }
}

/// Utilidades de formato monetario y fecha en Dart puro (sin paquete intl).
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

  static double? parseAmountInput(String raw, String currency) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\$\€\s]'), '');
    if (cleaned.isEmpty) return null;

    if (currency.toUpperCase() == 'COP') {
      // En COP los puntos suelen ser separadores de miles (ej. 50.000).
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
