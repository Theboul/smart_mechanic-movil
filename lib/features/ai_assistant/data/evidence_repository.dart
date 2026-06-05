import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

final evidenceRepositoryProvider = Provider<EvidenceRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return EvidenceRepository(dio);
});

class EvidenceRepository {
  final Dio _dio;

  EvidenceRepository(this._dio);

  Future<Map<String, dynamic>> uploadEvidence({
    required String incidentId,
    required String filePath,
    required String type, // 'foto' o 'audio'
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'evidencia_tipo': type,
    });

    final response = await _dio.post('/api/v1/emergencies/$incidentId/evidence', data: formData);
    return response.data;
  }

  Future<void> processIncident(String incidentId, {String? description}) async {
    await _dio.post(
      '/api/v1/emergencies/$incidentId/process',
      data: description != null ? {'descripcion': description} : null,
    );
  }
}
