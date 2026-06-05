import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(dio: ref.watch(dioProvider));
});

class FinanceRepository {
  final Dio _dio;

  FinanceRepository({required Dio dio}) : _dio = dio;

  Future<String> createPaymentIntent(String incidentId, double amount) async {
    final response = await _dio.post(
      '/api/v1/finance/emergencies/$incidentId/payment-intent',
      data: {
        'monto_total': amount,
      },
    );
    return response.data['clientSecret'] as String;
  }

  Future<void> confirmMockPayment(String incidentId) async {
    await _dio.post(
      '/api/v1/finance/emergencies/$incidentId/mock-payment-success',
    );
  }
}
