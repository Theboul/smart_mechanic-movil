import 'package:dio/dio.dart';

import '../../emergencies/data/emergency_repository.dart';

class OfflineConnectivityService {
  final EmergencyRepository _repository;

  OfflineConnectivityService(this._repository);

  Future<bool> canReachBackend() async {
    try {
      return await _repository.ping();
    } on DioException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
