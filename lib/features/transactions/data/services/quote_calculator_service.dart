import '../../domain/models/transaction_models.dart';

/// Motor de validación y pre-cotización de transferencias.
/// Mantiene la arquitectura preparada para aplicar comisiones configurables
/// desde backend sin modificar las pantallas.
class QuoteCalculatorService {
  const QuoteCalculatorService();

  TransactionQuote calculate({
    required TransferScope scope,
    required ManagedBankAccount sourceAccount,
    ManagedBankAccount? destinationOwnAccount,
    required String destinationKey,
    required double? amount,
    required FeePolicy feePolicy,
  }) {
    final safeAmount = amount ?? 0;
    final feeAmount = feePolicy.calculateFee(safeAmount);
    final totalDebit = safeAmount + feeAmount;

    if (!sourceAccount.isActive) {
      return TransactionQuote(
        scope: scope,
        currency: sourceAccount.currency,
        amount: safeAmount,
        feeAmount: feeAmount,
        totalDebit: totalDebit,
        isValid: false,
        validationError:
            'La cuenta origen (${sourceAccount.bankName}) está inactiva.',
      );
    }

    if (scope == TransferScope.ownAccounts) {
      if (destinationOwnAccount == null) {
        return TransactionQuote(
          scope: scope,
          currency: sourceAccount.currency,
          amount: safeAmount,
          feeAmount: feeAmount,
          totalDebit: totalDebit,
          isValid: false,
          validationError: 'Selecciona una cuenta destino propia.',
        );
      }
      if (!destinationOwnAccount.isActive) {
        return TransactionQuote(
          scope: scope,
          currency: sourceAccount.currency,
          amount: safeAmount,
          feeAmount: feeAmount,
          totalDebit: totalDebit,
          isValid: false,
          validationError:
              'La cuenta destino (${destinationOwnAccount.bankName}) está inactiva.',
        );
      }
      if (destinationOwnAccount.accountNumber == sourceAccount.accountNumber) {
        return TransactionQuote(
          scope: scope,
          currency: sourceAccount.currency,
          amount: safeAmount,
          feeAmount: feeAmount,
          totalDebit: totalDebit,
          isValid: false,
          validationError: 'Elige una cuenta destino diferente a la de origen.',
        );
      }
      if (destinationOwnAccount.currency.toUpperCase() !=
          sourceAccount.currency.toUpperCase()) {
        return TransactionQuote(
          scope: scope,
          currency: sourceAccount.currency,
          amount: safeAmount,
          feeAmount: feeAmount,
          totalDebit: totalDebit,
          isValid: false,
          validationError:
              'Ambas cuentas deben estar en la misma moneda (${sourceAccount.currency}).',
        );
      }
    } else {
      if (destinationKey.trim().length < 3) {
        return TransactionQuote(
          scope: scope,
          currency: sourceAccount.currency,
          amount: safeAmount,
          feeAmount: feeAmount,
          totalDebit: totalDebit,
          isValid: false,
          validationError:
              'Ingresa una llave válida (celular, correo, documento o cuenta).',
        );
      }
    }

    if (amount == null || amount <= 0) {
      return TransactionQuote(
        scope: scope,
        currency: sourceAccount.currency,
        amount: 0,
        feeAmount: 0,
        totalDebit: 0,
        isValid: false,
        validationError: 'Ingresa un monto mayor a cero.',
      );
    }

    if (totalDebit > sourceAccount.balance) {
      return TransactionQuote(
        scope: scope,
        currency: sourceAccount.currency,
        amount: safeAmount,
        feeAmount: feeAmount,
        totalDebit: totalDebit,
        isValid: false,
        validationError:
            'Saldo insuficiente en ${sourceAccount.bankName}. Disponible: ${CurrencyFormatter.format(sourceAccount.balance, sourceAccount.currency)}.',
      );
    }

    return TransactionQuote(
      scope: scope,
      currency: sourceAccount.currency,
      amount: safeAmount,
      feeAmount: feeAmount,
      totalDebit: totalDebit,
      isValid: true,
    );
  }
}
