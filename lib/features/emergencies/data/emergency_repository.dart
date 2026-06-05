import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../domain/incident.dart';

final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  return EmergencyRepository(dio: ref.watch(dioProvider));
});

class EmergencyRepository {
  final Dio _dio;

  EmergencyRepository({required Dio dio}) : _dio = dio;

  Future<IncidentResponse> reportIncident(IncidentCreate create) async {
    final response = await _dio.post(
      '/api/v1/emergencies/',
      data: create.toJson(),
    );
    return IncidentResponse.fromJson(response.data);
  }

  Future<IncidentResponse?> getActiveIncident() async {
    try {
      final response = await _dio.get('/api/v1/emergencies/me/active');
      if (response.data == null) return null;
      return IncidentResponse.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<IncidentResponse> getIncident(String id) async {
    final response = await _dio.get('/api/v1/emergencies/$id');
    return IncidentResponse.fromJson(response.data);
  }

  Future<List<IncidentResponse>> getIncidentHistory() async {
    final response = await _dio.get('/api/v1/emergencies/me/history');
    final List list = response.data;
    return list.map((json) => IncidentResponse.fromJson(json)).toList();
  }

  Future<IncidentResponse> cancelIncident(String id) async {
    final response = await _dio.post('/api/v1/emergencies/$id/cancel');
    return IncidentResponse.fromJson(response.data);
  }

  Future<IncidentResponse> updateIncidentStatus(String id, String nuevoEstado) async {
    final response = await _dio.patch(
      '/api/v1/emergencies/$id/status',
      data: {'nuevo_estado': nuevoEstado},
    );
    return IncidentResponse.fromJson(response.data);
  }

  Future<IncidentResponse> registerBilling({
    required String id,
    required double total,
    required double labor,
    required double parts,
    required String observations,
  }) async {
    final response = await _dio.post(
      '/api/v1/finance/emergencies/$id/billing',
      data: {
        'monto_total': total,
        'mano_de_obra': labor,
        'repuestos': parts,
        'observaciones': observations,
      },
    );
    return IncidentResponse.fromJson(response.data);
  }

  Future<IncidentResponse> verifyTechnician(String id, String verificationCode) async {
    final response = await _dio.post(
      '/api/v1/emergencies/$id/verify-technician',
      data: {'verification_code': verificationCode},
    );
    return IncidentResponse.fromJson(response.data);
  }

  Future<IncidentResponse> validateVerificationCode(String id, String verificationCode) async {
    return verifyTechnician(id, verificationCode);
  }

  Future<IncidentResponse> rejectTechnician(String id) async {
    final response = await _dio.post(
      '/api/v1/emergencies/$id/reject-technician',
    );
    return IncidentResponse.fromJson(response.data);
  }

  Future<IncidentResponse> rejectTechnicianVerification(String id) async {
    return rejectTechnician(id);
  }

  Future<void> postTrackingLocation(String id, double lat, double lng, double? speed) async {
    await _dio.post(
      '/api/v1/emergencies/incidents/$id/tracking',
      data: {
        'latitud': lat,
        'longitud': lng,
        'velocidad': speed,
      },
    );
  }

  Future<Map<String, dynamic>?> getLatestTracking(String id) async {
    try {
      final response = await _dio.get('/api/v1/emergencies/incidents/$id/tracking/latest');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }
}
