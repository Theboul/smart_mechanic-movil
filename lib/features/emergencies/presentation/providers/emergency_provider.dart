import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_mechanic_app/core/local_storage/secure_storage_provider.dart';
import '../../data/emergency_repository.dart';
import '../../domain/incident.dart';
import '../../../identity/presentation/providers/auth_provider.dart';
import '../../../ai_assistant/presentation/providers/evidence_provider.dart';

final emergencyNotifierProvider = AsyncNotifierProvider<EmergencyNotifier, IncidentResponse?>(() {
  return EmergencyNotifier();
});

class EmergencyNotifier extends AsyncNotifier<IncidentResponse?> {
  @override
  FutureOr<IncidentResponse?> build() async {
    // Al iniciar o cambiar de cuenta, verificamos si hay un incidente activo
    final authState = ref.watch(authProvider);
    if (authState.status != AuthStatus.authenticated) return null;
    
    return await _checkActiveIncident();
  }

  Future<IncidentResponse?> _checkActiveIncident() async {
    try {
      final active = await ref.read(emergencyRepositoryProvider).getActiveIncident();
      if (active == null) return null;

      final storage = ref.read(secureStorageProvider);
      final isCompleted = await storage.read(key: 'locally_completed_${active.id}');
      if (isCompleted == 'true') {
        return null;
      }
      return active;
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshStatus() async {
    if (ref.read(authProvider).status != AuthStatus.authenticated) return;
    
    if (state.value == null) {
      // Si no hay nada en el estado, intentamos buscar si hay uno activo (polling de seguridad)
      final active = await _checkActiveIncident();
      if (active != null) state = AsyncValue.data(active);
      return;
    }
    
    try {
      final updated = await ref.read(emergencyRepositoryProvider).getActiveIncident();
      
      // Si el incidente ya no está activo (null), reseteamos el estado para permitir nuevos SOS
      if (updated == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final storage = ref.read(secureStorageProvider);
      final isCompleted = await storage.read(key: 'locally_completed_${updated.id}');
      if (isCompleted == 'true') {
        state = const AsyncValue.data(null);
        return;
      }

      state = AsyncValue.data(updated);
    } catch (e) {
      // Ignoramos errores de red en el polling silencioso
    }
  }

  Future<void> completeIncidentLocally(String incidentId) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: 'locally_completed_$incidentId', value: 'true');
    state = const AsyncValue.data(null);
  }

  Future<void> sendSOS(String vehicleId, {String? description}) async {
    state = const AsyncValue.loading();
    
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition() ?? 
          Position(
            latitude: -17.7833, 
            longitude: -63.1821, 
            timestamp: DateTime.now(), 
            accuracy: 0, 
            altitude: 0, 
            heading: 0, 
            speed: 0, 
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
      }

      final create = IncidentCreate(
        vehicleId: vehicleId,
        descripcion: description ?? 'S.O.S generado desde la app móvil',
        latitud: position.latitude,
        longitud: position.longitude,
        prioridad: 'CRITICA',
      );

      final response = await ref.read(emergencyRepositoryProvider).reportIncident(create);
      state = AsyncValue.data(response);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> cancelSOS(String incidentId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(emergencyRepositoryProvider).cancelIncident(incidentId);
      ref.invalidate(evidenceProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateStatus(String incidentId, String nuevoEstado) async {
    state = const AsyncValue.loading();
    try {
      final updated = await ref.read(emergencyRepositoryProvider).updateIncidentStatus(incidentId, nuevoEstado);
      state = AsyncValue.data(updated);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> verifyTechnician(String incidentId, String code) async {
    state = const AsyncValue.loading();
    try {
      final updated = await ref.read(emergencyRepositoryProvider).verifyTechnician(incidentId, code);
      state = AsyncValue.data(updated);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> validateVerificationCode(String incidentId, String code) async {
    state = const AsyncValue.loading();
    try {
      final updated = await ref.read(emergencyRepositoryProvider).validateVerificationCode(incidentId, code);
      state = AsyncValue.data(updated);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> rejectTechnician(String incidentId) async {
    state = const AsyncValue.loading();
    try {
      final updated = await ref.read(emergencyRepositoryProvider).rejectTechnician(incidentId);
      state = AsyncValue.data(updated);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> rejectTechnicianVerification(String incidentId) async {
    state = const AsyncValue.loading();
    try {
      final updated = await ref.read(emergencyRepositoryProvider).rejectTechnicianVerification(incidentId);
      state = AsyncValue.data(updated);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}
