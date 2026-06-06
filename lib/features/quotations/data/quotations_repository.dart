import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../domain/quotation.dart';

final quotationsRepositoryProvider = Provider<QuotationsRepository>((ref) {
  return QuotationsRepository(dio: ref.watch(dioProvider));
});

class QuotationsRepository {
  final Dio _dio;

  QuotationsRepository({required Dio dio}) : _dio = dio;

  Future<List<QuotationWorkshopOption>> searchCompatibleWorkshops({
    required double latitud,
    required double longitud,
    String? categoriaServicio,
    double radiusKm = 10.0,
  }) async {
    final params = <String, dynamic>{
      'latitud': latitud,
      'longitud': longitud,
      'radius_km': radiusKm,
    };
    if (categoriaServicio != null && categoriaServicio.trim().isNotEmpty) {
      params['categoria_servicio'] = categoriaServicio.trim();
    }

    final response = await _dio.get(
      '/api/v1/quotations/compatibility/search',
      queryParameters: params,
    );
    final List list = response.data as List;
    return list.map((json) => QuotationWorkshopOption.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<QuotationRequest> createRequest(QuotationRequestCreate create) async {
    final response = await _dio.post(
      '/api/v1/quotations/requests',
      data: create.toJson(),
    );
    return QuotationRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<QuotationRequestSummary>> getMyRequests() async {
    final response = await _dio.get('/api/v1/quotations/requests/me');
    final List list = response.data as List;
    return list.map((json) => QuotationRequestSummary.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<QuotationRequest> cancelRequest(String requestId) async {
    final response = await _dio.post('/api/v1/quotations/requests/$requestId/cancel');
    return QuotationRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<QuotationQuote>> getRequestQuotes(String requestId) async {
    final response = await _dio.get('/api/v1/quotations/requests/$requestId/quotes');
    final List list = response.data as List;
    return list.map((json) => QuotationQuote.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<QuotationIncident> selectQuote({
    required String requestId,
    required String quoteId,
  }) async {
    final response = await _dio.post(
      '/api/v1/quotations/requests/$requestId/select',
      data: {'id_cotizacion': quoteId},
    );
    return QuotationIncident.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<QuotationWorkshopInboxItemResponse>> getWorkshopInbox() async {
    final response = await _dio.get('/api/v1/quotations/workshop/inbox');
    final List list = response.data as List;
    return list.map((json) => QuotationWorkshopInboxItemResponse.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<QuotationQuote> createWorkshopQuote({
    required String requestId,
    required double manoObraEstimado,
    required double repuestosEstimado,
    required double totalEstimado,
    required int tiempoEstimadoMinutos,
    String? observaciones,
    int vigenciaHoras = 48,
  }) async {
    final response = await _dio.post(
      '/api/v1/quotations/workshop/$requestId/quote',
      data: {
        'mano_obra_estimado': manoObraEstimado,
        'repuestos_estimado': repuestosEstimado,
        'total_estimado': totalEstimado,
        'tiempo_estimado_minutos': tiempoEstimadoMinutos,
        'observaciones': observaciones,
        'vigencia_horas': vigenciaHoras,
      },
    );
    return QuotationQuote.fromJson(response.data as Map<String, dynamic>);
  }

  Future<QuotationWorkshopInboxItemResponse> rejectWorkshopRequest({
    required String requestId,
    String? motivo,
  }) async {
    final response = await _dio.post(
      '/api/v1/quotations/workshop/$requestId/reject',
      data: {
        'motivo': motivo,
      },
    );
    return QuotationWorkshopInboxItemResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
