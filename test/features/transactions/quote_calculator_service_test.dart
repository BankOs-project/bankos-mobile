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

    test('ignora una llave anterior si falta la cuenta propia de destino', () {
      final quote = service.calculate(
        scope: TransferScope.ownAccounts,
        sourceAccount: activeBancolombia,
        destinationKey: '3004567890',
        amount: 20000,
        feePolicy: const FeePolicy.zero(),
      );

      expect(quote.isValid, isFalse);
      expect(quote.validationError, contains('cuenta destino propia'));
    });

    test('rechaza una cuenta de destino inactiva', () {
      final quote = service.calculate(
        scope: TransferScope.ownAccounts,
        sourceAccount: activeBancolombia,
        destinationOwnAccount: inactiveAccount,
        amount: 20000,
        feePolicy: const FeePolicy.zero(),
      );

      expect(quote.isValid, isFalse);
      expect(quote.validationError, contains('destino está inactiva'));
    });

    test('rechaza monto menor o igual a cero', () {
      final zeroQuote = service.calculate(
        operationType: FinancialOperationType.transfer,
        sourceAccount: activeBancolombia,
        destinationAccountNumber: '**** 9845',
        amount: 0,
        feePolicy: const FeePolicy.zero(),
      );
      expect(zeroQuote.isValid, isFalse);
      expect(zeroQuote.validationError, contains('mayor a cero'));

      final negQuote = service.calculate(
        operationType: FinancialOperationType.transfer,
        sourceAccount: activeBancolombia,
        destinationAccountNumber: '**** 9845',
        amount: -50000,
        feePolicy: const FeePolicy.zero(),
      );
      expect(negQuote.isValid, isFalse);
    });

    test('rechaza montos que superan el límite máximo por transacción (\$5M COP)', () {
      final overLimitQuote = service.calculate(
        operationType: FinancialOperationType.transfer,
        sourceAccount: activeBancolombia,
        destinationAccountNumber: '**** 9845',
        amount: 5000001,
        feePolicy: const FeePolicy.zero(),
      );
      expect(overLimitQuote.isValid, isFalse);
      expect(overLimitQuote.validationError, contains('supera el límite'));
    });

    test('valida operación de depósito con comisión cero y tasa 1.0', () {
      final depositQuote = service.calculate(
        operationType: FinancialOperationType.deposit,
        sourceAccount: activeBancolombia,
        amount: 300000,
        feePolicy: const FeePolicy.percentage(2.0), // Depósitos sin cobro
      );
      expect(depositQuote.isValid, isTrue);
      expect(depositQuote.feeAmount, 0);
      expect(depositQuote.finalAmountReceived, 300000);
      expect(depositQuote.exchangeRate, 1.0);
    });

    test('valida retiro según saldo disponible', () {
      final validWithdrawal = service.calculate(
        operationType: FinancialOperationType.withdrawal,
        sourceAccount: activeBancolombia,
        amount: 500000,
        feePolicy: const FeePolicy.zero(),
      );
      expect(validWithdrawal.isValid, isTrue);

      final excessWithdrawal = service.calculate(
        operationType: FinancialOperationType.withdrawal,
        sourceAccount: activeBancolombia,
        amount: 1500000,
        feePolicy: const FeePolicy.zero(),
      );
      expect(excessWithdrawal.isValid, isFalse);
      expect(excessWithdrawal.validationError, contains('Saldo insuficiente'));
    });

    test('aplica conversión multimoneda con tasas estáticas del Tenant (USD -> COP)', () {
      const usdAccount = ManagedBankAccount(
        bankName: 'Banco Andino',
        title: 'Cuenta Principal',
        accountNumber: '**** 4589',
        currency: 'USD',
        balance: 2000,
        status: 'ACTIVA',
        accentColor: AppTheme.secondaryColor,
      );

      final crossQuote = service.calculate(
        operationType: FinancialOperationType.transfer,
        sourceAccount: usdAccount,
        destinationAccountNumber: '**** 8821',
        destinationCurrency: 'COP',
        amount: 100, // 100 USD
        feePolicy: const FeePolicy.zero(),
      );

      expect(crossQuote.isValid, isTrue);
      expect(crossQuote.isCrossCurrency, isTrue);
      expect(crossQuote.exchangeRate, 4000.0);
      expect(crossQuote.finalAmountReceived, 400000.0); // 100 * 4000
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
