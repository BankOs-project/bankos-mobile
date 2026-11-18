import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/features/transactions/data/services/quote_calculator_service.dart';
import 'package:bankos_mobile/features/transactions/domain/models/transaction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = QuoteCalculatorService();

  const activeBancolombia = ManagedBankAccount(
    bankName: 'Bancolombia',
    title: 'Billetera Local',
    accountNumber: '**** 8821',
    currency: 'COP',
    balance: 1000000,
    status: 'ACTIVA',
    accentColor: AppTheme.primaryColor,
  );

  const activeDavivienda = ManagedBankAccount(
    bankName: 'Davivienda',
    title: 'Cuenta Ahorros',
    accountNumber: '**** 3310',
    currency: 'COP',
    balance: 500000,
    status: 'ACTIVA',
    accentColor: AppTheme.errorColor,
  );

  const inactiveAccount = ManagedBankAccount(
    bankName: 'Banco de Bogotá',
    title: 'Cuenta Ahorro',
    accountNumber: '**** 1204',
    currency: 'COP',
    balance: 750000,
    status: 'INACTIVA',
    accentColor: AppTheme.tertiaryColor,
  );

  group('QuoteCalculatorService', () {
    test('calcula transferencia externa con comisión \$0 por defecto', () {
      final quote = service.calculate(
        scope: TransferScope.externalPerson,
        sourceAccount: activeBancolombia,
        destinationKey: '@maria.gomez',
        amount: 50000,
        feePolicy: const FeePolicy.zero(),
      );

      expect(quote.isValid, isTrue);
      expect(quote.feeAmount, 0);
      expect(quote.totalDebit, 50000);
      expect(quote.currency, 'COP');
    });

    test('soporta lógica interna de comisión fija y porcentual para futuro', () {
      final fixedQuote = service.calculate(
        scope: TransferScope.externalPerson,
        sourceAccount: activeBancolombia,
        destinationKey: '@maria.gomez',
        amount: 100000,
        feePolicy: const FeePolicy.fixed(2000),
      );
      expect(fixedQuote.isValid, isTrue);
      expect(fixedQuote.feeAmount, 2000);
      expect(fixedQuote.totalDebit, 102000);

      final percentQuote = service.calculate(
        scope: TransferScope.externalPerson,
        sourceAccount: activeBancolombia,
        destinationKey: '@maria.gomez',
        amount: 100000,
        feePolicy: const FeePolicy.percentage(1.5),
      );
      expect(percentQuote.isValid, isTrue);
      expect(percentQuote.feeAmount, 1500);
      expect(percentQuote.totalDebit, 101500);
    });

    test('rechaza saldo insuficiente considerando monto más comisión', () {
      final quote = service.calculate(
        scope: TransferScope.externalPerson,
        sourceAccount: activeBancolombia,
        destinationKey: '3004567890',
        amount: 1000001,
        feePolicy: const FeePolicy.zero(),
      );

      expect(quote.isValid, isFalse);
      expect(quote.validationError, contains('Saldo insuficiente'));
    });

    test('rechaza cuenta origen inactiva', () {
      final quote = service.calculate(
        scope: TransferScope.externalPerson,
        sourceAccount: inactiveAccount,
        destinationKey: '@maria.gomez',
        amount: 20000,
        feePolicy: const FeePolicy.zero(),
      );

      expect(quote.isValid, isFalse);
      expect(quote.validationError, contains('inactiva'));
    });

    test('valida transferencia entre cuentas propias distintas', () {
      final validOwn = service.calculate(
        scope: TransferScope.ownAccounts,
        sourceAccount: activeBancolombia,
        destinationOwnAccount: activeDavivienda,
        destinationKey: '',
        amount: 200000,
        feePolicy: const FeePolicy.zero(),
      );
      expect(validOwn.isValid, isTrue);

      final sameAccount = service.calculate(
        scope: TransferScope.ownAccounts,
        sourceAccount: activeBancolombia,
        destinationOwnAccount: activeBancolombia,
        destinationKey: '',
        amount: 200000,
        feePolicy: const FeePolicy.zero(),
      );
      expect(sameAccount.isValid, isFalse);
    });
  });

  group('CurrencyFormatter', () {
    test('formatea y parsea montos en COP y USD', () {
      expect(CurrencyFormatter.format(50000, 'COP'), '\$50.000 COP');
      expect(CurrencyFormatter.format(0, 'COP'), '\$0 COP');
      expect(CurrencyFormatter.format(120.5, 'USD'), '\$120.50 USD');
      expect(CurrencyFormatter.parseAmountInput('50.000', 'COP'), 50000);
      expect(CurrencyFormatter.parseAmountInput('125.50', 'USD'), 125.5);
    });
  });
}
