import '../../../accounts/domain/models/session_account.dart';

class FinancialCurrencySummary {
  const FinancialCurrencySummary({
    required this.currency,
    required this.availableBalance,
    required this.income,
    required this.expenses,
  });

  final String currency;
  final BigInt availableBalance;
  final BigInt income;
  final BigInt expenses;

  factory FinancialCurrencySummary.fromJson(Map<String, dynamic> json) {
    final currency = json['currency'];
    if (currency is! String || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const FormatException('Moneda inválida en el resumen financiero.');
    }
    return FinancialCurrencySummary(
      currency: currency,
      availableBalance: parseMoneyUnits(json['available_balance']),
      income: parseMoneyUnits(json['income']),
      expenses: parseMoneyUnits(json['expenses']),
    );
  }
}
