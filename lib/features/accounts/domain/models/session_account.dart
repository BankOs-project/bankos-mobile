enum AccountStatus {
  active('ACTIVA'),
  inactive('INACTIVA'),
  blocked('BLOQUEADA');

  const AccountStatus(this.label);

  final String label;
}

final _balanceScale = BigInt.from(10000);
final _decimalBalance = RegExp(r'^(-?)(\d+)(?:\.(\d{1,4}))?$');

class SessionAccount {
  const SessionAccount({
    required this.accountNumber,
    required this.currency,
    required this.balanceUnits,
    required this.status,
  });

  final String accountNumber;
  final String currency;
  // FastAPI serializa Decimal con hasta cuatro decimales.
  final BigInt balanceUnits;
  final AccountStatus status;

  String get maskedNumber =>
      '•••• ${accountNumber.substring(accountNumber.length - 4)}';

  factory SessionAccount.fromJson(Map<String, dynamic> json) {
    final number = json['account_number'];
    final currency = json['currency'];
    final status = switch (json['status']) {
      'ACTIVE' => AccountStatus.active,
      'INACTIVE' => AccountStatus.inactive,
      'BLOCKED' => AccountStatus.blocked,
      _ => throw const FormatException('Estado de cuenta desconocido.'),
    };
    if (number is! String ||
        number.length < 4 ||
        currency is! String ||
        currency.length != 3) {
      throw const FormatException('Datos de cuenta inválidos.');
    }

    return SessionAccount(
      accountNumber: number,
      currency: currency,
      balanceUnits: parseMoneyUnits(json['balance']),
      status: status,
    );
  }
}

BigInt parseMoneyUnits(Object? value) {
  final balance = _decimalBalance.firstMatch(value.toString());
  if (balance == null) throw const FormatException('Importe inválido.');
  final whole = BigInt.parse(balance[2]!);
  final fraction = BigInt.parse((balance[3] ?? '').padRight(4, '0'));
  final units = whole * _balanceScale + fraction;
  return balance[1] == '-' ? -units : units;
}

String formatAccountBalance(BigInt balanceUnits, String currency) {
  final isCop = currency == 'COP';
  final amount = balanceUnits.abs();
  final whole = (amount ~/ _balanceScale).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => isCop ? '.' : ',',
  );
  final precision = isCop ? 0 : 2;
  final fraction = (amount % _balanceScale)
      .toString()
      .padLeft(4, '0')
      .replaceFirst(RegExp(r'0+$'), '')
      .padRight(precision, '0');
  final decimal = fraction.isEmpty ? '' : '${isCop ? ',' : '.'}$fraction';
  final symbol = currency == 'EUR' ? '€' : r'$';
  final sign = balanceUnits.isNegative ? '-' : '';
  return '$sign$symbol$whole$decimal $currency';
}
