import 'package:dio/dio.dart';

import '../../../auth/domain/models/auth_models.dart';
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
    return OperationQuote.fromJson(data);
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
  final message = body is Map ? body['message'] : null;
  if (message is String && message.trim().isNotEmpty) return message;
  return 'No se pudo consultar la operación. Intenta nuevamente.';
}
