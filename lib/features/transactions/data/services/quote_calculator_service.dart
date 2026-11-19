import '../../domain/models/transaction_models.dart';

/// Motor de validación y pre-cotización del Core Bancario BankOS.
/// Implementa reglas de negocio ACID de la hackatón:
/// 1. Validación de cuenta activa.
/// 2. Monto estrictamente positivo (> 0).
/// 3. Límite máximo por transacción parametrizado por Tenant ($5M COP o $1.250 USD).
/// 4. Validación de saldo suficiente (en retiro y transferencia con comisión).
/// 5. Conversión de divisas con tabla de tasas estáticas del Tenant.
/// 6. Comisión fija o porcentual del Tenant.
class QuoteCalculatorService {
  const QuoteCalculatorService();

  TransactionQuote calculate({
    FinancialOperationType? operationType,
    TransferScope? scope,
    required ManagedBankAccount sourceAccount,
    ManagedBankAccount? destinationOwnAccount,
    String? destinationKey,
    String? destinationAccountNumber,
    String? destinationCurrency,
    required double? amount,
    required FeePolicy feePolicy,
  }) {
    final effectiveOperation = operationType ??
        (scope == TransferScope.ownAccounts
            ? FinancialOperationType.transfer
            : FinancialOperationType.transfer);

    final safeAmount = amount ?? 0;
    final sourceCurrency = sourceAccount.currency;
    final resolvedDestNumber = destinationOwnAccount?.accountNumber ??
        destinationAccountNumber ??
        destinationKey ??
        '';
    final resolvedDestCurrency = destinationOwnAccount?.currency ??
        destinationCurrency ??
        sourceCurrency;
    final maxLimit = TenantLimits.maxLimitFor(sourceCurrency);

    // 1. Estado de la cuenta origen
    if (!sourceAccount.isActive) {
      return TransactionQuote(
        operationType: effectiveOperation,
        sourceCurrency: sourceCurrency,
        destinationCurrency: resolvedDestCurrency,
        amount: safeAmount,
        feeAmount: 0,
        exchangeRate: 1.0,
        finalAmountReceived: safeAmount,
        totalDebit: safeAmount,
        isCrossCurrency: false,
        isValid: false,
        validationError:
            'La cuenta seleccionada (${sourceAccount.title}) está inactiva y no puede operar.',
      );
    }

    // 2. Validación de monto positivo (> 0)
    if (amount == null || amount <= 0) {
      return TransactionQuote(
        operationType: effectiveOperation,
        sourceCurrency: sourceCurrency,
        destinationCurrency: resolvedDestCurrency,
        amount: 0,
        feeAmount: 0,
        exchangeRate: 1.0,
        finalAmountReceived: 0,
        totalDebit: 0,
        isCrossCurrency: false,
        isValid: false,
        validationError: 'Ingresa un monto mayor a cero.',
      );
    }

    // 3. Validación de límite máximo por transacción ($5M COP / $1.250 USD)
    if (safeAmount > maxLimit) {
      final formattedLimit = CurrencyFormatter.format(maxLimit, sourceCurrency);
      return TransactionQuote(
        operationType: effectiveOperation,
        sourceCurrency: sourceCurrency,
        destinationCurrency: resolvedDestCurrency,
        amount: safeAmount,
        feeAmount: 0,
        exchangeRate: 1.0,
        finalAmountReceived: safeAmount,
        totalDebit: safeAmount,
        isCrossCurrency: false,
        isValid: false,
        validationError:
            'El monto supera el límite máximo por transacción permitido ($formattedLimit).',
      );
    }

    // 4. Lógica según el tipo de operación financiera
    switch (effectiveOperation) {
      case FinancialOperationType.deposit:
        return TransactionQuote(
          operationType: effectiveOperation,
          sourceCurrency: sourceCurrency,
          destinationCurrency: sourceCurrency,
          amount: safeAmount,
          feeAmount: 0,
          exchangeRate: 1.0,
          finalAmountReceived: safeAmount,
          totalDebit: safeAmount,
          isCrossCurrency: false,
          isValid: true,
        );

      case FinancialOperationType.withdrawal:
        if (safeAmount > sourceAccount.balance) {
          final formattedBal =
              CurrencyFormatter.format(sourceAccount.balance, sourceCurrency);
          return TransactionQuote(
            operationType: effectiveOperation,
            sourceCurrency: sourceCurrency,
            destinationCurrency: sourceCurrency,
            amount: safeAmount,
            feeAmount: 0,
            exchangeRate: 1.0,
            finalAmountReceived: safeAmount,
            totalDebit: safeAmount,
            isCrossCurrency: false,
            isValid: false,
            validationError:
                'Saldo insuficiente en ${sourceAccount.title}. Disponible: $formattedBal.',
          );
        }
        return TransactionQuote(
          operationType: effectiveOperation,
          sourceCurrency: sourceCurrency,
          destinationCurrency: sourceCurrency,
          amount: safeAmount,
          feeAmount: 0,
          exchangeRate: 1.0,
          finalAmountReceived: safeAmount,
          totalDebit: safeAmount,
          isCrossCurrency: false,
          isValid: true,
        );

      case FinancialOperationType.transfer:
        final cleanDest = resolvedDestNumber.trim();
        if (cleanDest.length < 3) {
          return TransactionQuote(
            operationType: effectiveOperation,
            sourceCurrency: sourceCurrency,
            destinationCurrency: resolvedDestCurrency,
            amount: safeAmount,
            feeAmount: 0,
            exchangeRate: 1.0,
            finalAmountReceived: safeAmount,
            totalDebit: safeAmount,
            isCrossCurrency: false,
            isValid: false,
            validationError:
                'Ingresa un número de cuenta o destinatario válido.',
          );
        }

        if (cleanDest == sourceAccount.accountNumber ||
            cleanDest ==
                sourceAccount.accountNumber.replaceAll(RegExp(r'[^0-9]'), '')) {
          return TransactionQuote(
            operationType: effectiveOperation,
            sourceCurrency: sourceCurrency,
            destinationCurrency: resolvedDestCurrency,
            amount: safeAmount,
            feeAmount: 0,
            exchangeRate: 1.0,
            finalAmountReceived: safeAmount,
            totalDebit: safeAmount,
            isCrossCurrency: false,
            isValid: false,
            validationError:
                'La cuenta destino no puede ser la misma cuenta de origen.',
          );
        }

        // Tasa de cambio multimoneda y comisión parametrizada del Tenant
        final isCross = sourceCurrency.toUpperCase() !=
            resolvedDestCurrency.toUpperCase();
        final rate =
            TenantExchangeRates.getRate(sourceCurrency, resolvedDestCurrency);
        final fee = feePolicy.calculateFee(safeAmount);
        final totalDebit = safeAmount + fee;
        final finalReceived = safeAmount * rate;

        if (totalDebit > sourceAccount.balance) {
          final formattedBal =
              CurrencyFormatter.format(sourceAccount.balance, sourceCurrency);
          final feeInfo = fee > 0
              ? ' (incluyendo ${CurrencyFormatter.format(fee, sourceCurrency)} de comisión)'
              : '';
          return TransactionQuote(
            operationType: effectiveOperation,
            sourceCurrency: sourceCurrency,
            destinationCurrency: resolvedDestCurrency,
            amount: safeAmount,
            feeAmount: fee,
            exchangeRate: rate,
            finalAmountReceived: finalReceived,
            totalDebit: totalDebit,
            isCrossCurrency: isCross,
            isValid: false,
            validationError:
                'Saldo insuficiente$feeInfo. Disponible: $formattedBal.',
          );
        }

        return TransactionQuote(
          operationType: effectiveOperation,
          sourceCurrency: sourceCurrency,
          destinationCurrency: resolvedDestCurrency,
          amount: safeAmount,
          feeAmount: fee,
          exchangeRate: rate,
          finalAmountReceived: finalReceived,
          totalDebit: totalDebit,
          isCrossCurrency: isCross,
          isValid: true,
        );
    }
  }
}
