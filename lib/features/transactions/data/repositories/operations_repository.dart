import 'package:dio/dio.dart';

import '../../../accounts/domain/models/session_account.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../domain/models/financial_summary.dart';
import '../../domain/models/transaction_models.dart';

class OperationsRepository {
  const OperationsRepository(this._dio);

  final Dio _dio;

  Future<TransferDestination> findDestination(
    AuthSession session,
    String accountNumber,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/accounts/${Uri.encodeComponent(accountNumber)}/destination',
      options: _options(session),
    );
    final destination = TransferDestination.fromJson(_data(response));
    if (destination.accountNumber != accountNumber) {
      throw const FormatException('La cuenta destino no coincide.');
    }
    return destination;
  }

  Future<OperationQuote> quote(
    AuthSession session,
    OperationDraft draft,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/transactions/quote',
      data: draft.quoteBody,
      options: _options(session),
    );
    final data = _data(response);
    if (data['operation_type'] != draft.type.apiValue) {
      throw const FormatException('La cotización no coincide.');
    }
    final quote = OperationQuote.fromJson(data);
    if (quote.amount != parseMoneyUnits(draft.amount)) {
      throw const FormatException('El monto de la cotización no coincide.');
    }
    if (draft.type == FinancialOperationType.transfer &&
        (quote.id == null ||
            quote.id!.isEmpty ||
            quote.expiresAt == null ||
            quote.transferMode != draft.transferMode ||
            (draft.transferMode == TransferMode.otherBank &&
                (quote.recipient == null ||
                    quote.recipient!.lastFour.length != 4 ||
                    draft.destinationNumber?.endsWith(
                          quote.recipient!.lastFour,
                        ) !=
                        true)))) {
      throw const FormatException(
        'Los datos de la transferencia no coinciden.',
      );
    }
    return quote;
  }

  Future<({List<OperationReceipt> items, int? nextSkip})> fetchHistory(
    AuthSession session, {
    required int skip,
    int limit = 30,
    FinancialOperationType? type,
    String? accountNumber,
    required CancelToken cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/transactions',
      queryParameters: {
        'skip': skip,
        'limit': limit,
        'operation_type': ?type?.apiValue,
        'account_number': ?accountNumber,
      },
      options: _options(session),
      cancelToken: cancelToken,
    );
    final page = _data(response);
    final items = page['items'];
    final total = page['total'];
    if (items is! List || total is! int || total < 0 || page['skip'] != skip) {
      throw const FormatException('Paginación de movimientos inválida.');
    }

    final receipts = <OperationReceipt>[];
    for (final item in items) {
      if (item is! Map<String, dynamic> ||
          item['tenant_id'] != session.tenantId) {
        throw const FormatException('Movimiento ajeno a la sesión.');
      }
      final movementType = FinancialOperationType.values.firstWhere(
        (type) => type.apiValue == item['operation_type'],
        orElse: () =>
            throw const FormatException('Tipo de movimiento desconocido.'),
      );
      receipts.add(OperationReceipt.fromJson(item, movementType));
    }
    final next = skip + items.length;
    return (
      items: receipts,
      nextSkip: items.isNotEmpty && next < total ? next : null,
    );
  }

  Future<List<FinancialCurrencySummary>> fetchFinancialSummary(
    AuthSession session, {
    required DateTime start,
    required DateTime end,
    required String? accountNumber,
    required CancelToken cancelToken,
  }) async {
    final startUtc = start.toUtc();
    final endUtc = end.toUtc();
    final response = await _dio.get<Map<String, dynamic>>(
      '/transactions/summary',
      queryParameters: {
        'start_date': startUtc.toIso8601String(),
        'end_date': endUtc.toIso8601String(),
        'account_number': ?accountNumber,
      },
      options: _options(session),
      cancelToken: cancelToken,
    );
    final data = _data(response);
    final currencies = data['currencies'];
    if (currencies is! List ||
        !data.containsKey('account_number') ||
        data['account_number'] != accountNumber ||
        DateTime.tryParse('${data['start_date']}') != startUtc ||
        DateTime.tryParse('${data['end_date']}') != endUtc) {
      throw const FormatException(
        'El resumen financiero no coincide con la consulta.',
      );
    }

    final totals = <FinancialCurrencySummary>[];
    final seen = <String>{};
    for (final item in currencies) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Importes inválidos en el resumen financiero.',
        );
      }
      final total = FinancialCurrencySummary.fromJson(item);
      if (!seen.add(total.currency)) {
        throw const FormatException(
          'Moneda repetida en el resumen financiero.',
        );
      }
      totals.add(total);
    }
    return totals;
  }

  Future<OperationReceipt> execute(
    AuthSession session,
    ConfirmedOperation operation,
  ) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        '/transactions/${operation.type.endpoint}',
        data: operation.body,
        options: _options(session, operation: operation),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final body = error.response?.data;
      if (status != null &&
          status >= 400 &&
          status < 500 &&
          !const {401, 408, 425, 429}.contains(status) &&
          body is Map &&
          body['success'] == false &&
          body['internal_code'] is String &&
          body['internal_code'] != 'IDEMPOTENCY_IN_PROGRESS') {
        throw OperationRejected(operationErrorMessage(error));
      }
      rethrow;
    }

    final data = _data(response);
    if (data['status'] != 'SUCCESS' ||
        data['tenant_id'] != session.tenantId ||
        data['operation_type'] != operation.type.apiValue ||
        data['idempotency_key'] != operation.idempotencyKey ||
        data['correlation_id'] != operation.correlationId) {
      throw const FormatException(
        'El comprobante no coincide con la operación.',
      );
    }
    final receipt = OperationReceipt.fromJson(data, operation.type);
    if (operation.type == FinancialOperationType.transfer &&
        operation.body.containsKey('quote_id')) {
      // La cotización identifica las cuentas sin repetirlas en la confirmación.
      if (receipt.sourceAccount == null ||
          receipt.transferMode == null ||
          (receipt.transferMode == TransferMode.otherBank
              ? receipt.destinationAccount != null ||
                    receipt.transferReference == null
              : receipt.destinationAccount == null)) {
        throw const FormatException(
          'El comprobante de transferencia está incompleto.',
        );
      }
      return receipt;
    }
    final expectedSource = switch (operation.type) {
      FinancialOperationType.transfer =>
        operation.body['source_account_number'],
      FinancialOperationType.withdrawal => operation.body['account_number'],
      FinancialOperationType.deposit => null,
    };
    final expectedDestination = switch (operation.type) {
      FinancialOperationType.transfer =>
        operation.body['destination_account_number'],
      FinancialOperationType.deposit => operation.body['account_number'],
      FinancialOperationType.withdrawal => null,
    };
    if (receipt.sourceAccount != expectedSource ||
        receipt.destinationAccount != expectedDestination) {
      throw const FormatException('Las cuentas del comprobante no coinciden.');
    }
    return receipt;
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    final body = response.data;
    final data = body?['data'];
    if (body?['success'] != true || data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de operaciones inválida.');
    }
    return data;
  }

  Options _options(AuthSession session, {ConfirmedOperation? operation}) =>
      Options(
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          if (operation != null) ...{
            'Idempotency-Key': operation.idempotencyKey,
            'X-Correlation-ID': operation.correlationId,
          },
        },
      );
}

class OperationRejected implements Exception {
  const OperationRejected(this.message);
  final String message;
}

String operationErrorMessage(Object error) {
  final body = error is DioException ? error.response?.data : null;
  switch (body is Map ? body['internal_code'] : null) {
    case 'QUOTE_EXPIRED':
      return 'La cotización venció. Vuelve a cotizar y confirma las nuevas condiciones.';
    case 'QUOTE_STALE':
      return 'La cotización cambió. Vuelve a cotizar y confirma las nuevas condiciones.';
    case 'QUOTE_UNAVAILABLE':
      return 'La cotización ya no está disponible. Solicita una nueva.';
    case 'QUOTE_ALREADY_USED':
      return 'La cotización ya se utilizó. Consulta Movimientos antes de repetir la transferencia.';
    case 'DESTINATION_UNAVAILABLE':
      return 'El destino no está disponible.';
    case 'INTERBANK_DISABLED':
      return 'La transferencia simulada a otro banco está deshabilitada en este entorno.';
    case 'TRANSFER_QUOTE_UNAVAILABLE':
      return 'La cotización está temporalmente indisponible. Intenta de nuevo.';
  }
  final message = body is Map ? body['message'] : null;
  if (message is String && message.trim().isNotEmpty) return message;
  return 'No se pudo consultar la operación. Intenta nuevamente.';
}
