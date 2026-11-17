import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class BankAccount {
  final String title;
  final String accountNumber;
  final String currency;
  final double balance;
  final String status;

  const BankAccount({
    required this.title,
    required this.accountNumber,
    required this.currency,
    required this.balance,
    required this.status,
  });
}

final accountsMockProvider = Provider<List<BankAccount>>((ref) {
  return const [
    BankAccount(
      title: 'Cuenta Principal',
      accountNumber: '**** 4589',
      currency: 'USD',
      balance: 14850.00,
      status: 'ACTIVA',
    ),
    BankAccount(
      title: 'Billetera Local',
      accountNumber: '**** 8821',
      currency: 'COP',
      balance: 5200000.00,
      status: 'ACTIVA',
    ),
    BankAccount(
      title: 'Cuenta Ahorro',
      accountNumber: '**** 1204',
      currency: 'EUR',
      balance: 750.00,
      status: 'INACTIVA',
    ),
  ];
});

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);
