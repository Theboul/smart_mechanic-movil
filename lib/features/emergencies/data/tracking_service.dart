import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'emergency_repository.dart';

final trackingServiceProvider = Provider<TrackingService>((ref) {
  return TrackingService(ref);
});

class TrackingService {
  final Ref _ref;
  Timer? _timer;
  bool _isTracking = false;

  TrackingService(this._ref);

  bool get isTracking => _isTracking;

  Future<void> startTracking(String incidentId) async {
    if (_isTracking) return;
    _isTracking = true;
    debugPrint('🛰️ GPS: Iniciando tracking para incidente: $incidentId');

    // 1. Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _isTracking = false;
        return;
      }
    }

    // 2. Transmisión inmediata inicial
    await _sendCurrentLocation(incidentId);

    // 3. Temporizador cada 20 segundos
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      await _sendCurrentLocation(incidentId);
    });
  }

  Future<void> _sendCurrentLocation(String incidentId) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      
      debugPrint('🛰️ GPS: Transmitiendo ubicación: ${position.latitude}, ${position.longitude}');
      await _ref.read(emergencyRepositoryProvider).postTrackingLocation(
        incidentId,
        position.latitude,
        position.longitude,
        position.speed,
      );
    } catch (e) {
      debugPrint('❌ GPS: Error al transmitir: $e');
    }
  }

  void stopTracking() {
    debugPrint('🛰️ GPS: Deteniendo servicio de tracking.');
    _isTracking = false;
    _timer?.cancel();
    _timer = null;
  }
}
