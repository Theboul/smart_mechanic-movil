import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../domain/appointment.dart';

final schedulingRepositoryProvider = Provider<SchedulingRepository>((ref) {
  return SchedulingRepository(dio: ref.watch(dioProvider));
});

class SchedulingRepository {
  final Dio _dio;

  SchedulingRepository({required Dio dio}) : _dio = dio;

  Future<List<SlotAvailability>> getSlotsAvailability({
    required String sucursalId,
    required String dateStr, // YYYY-MM-DD
    String? tecnicoId,
  }) async {
    final params = <String, dynamic>{
      'id_sucursal': sucursalId,
      'date': dateStr,
    };
    if (tecnicoId != null && tecnicoId.isNotEmpty) {
      params['id_tecnico'] = tecnicoId;
    }

    final response = await _dio.get(
      '/api/v1/scheduling/slots/availability',
      queryParameters: params,
    );
    final List list = response.data;
    return list.map((json) => SlotAvailability.fromJson(json)).toList();
  }

  Future<Appointment> createAppointment({
    required String? incidentId,
    required String vehicleId,
    required DateTime datetime,
    required String motivo,
    String? observaciones,
    String prioridad = 'MEDIA',
    String? tecnicoId,
  }) async {
    final data = <String, dynamic>{
      'id_vehiculo': vehicleId,
      'fecha_hora': datetime.toUtc().toIso8601String(),
      'motivo': motivo,
      'prioridad': prioridad,
    };
    if (incidentId != null && incidentId.isNotEmpty) {
      data['id_incidente_origen'] = incidentId;
    }
    if (observaciones != null && observaciones.trim().isNotEmpty) {
      data['observaciones'] = observaciones;
    }
    if (tecnicoId != null && tecnicoId.isNotEmpty) {
      data['id_tecnico'] = tecnicoId;
    }

    final response = await _dio.post(
      '/api/v1/scheduling/appointments',
      data: data,
    );
    return Appointment.fromJson(response.data);
  }

  Future<List<Appointment>> getMyAppointments() async {
    final response = await _dio.get('/api/v1/scheduling/appointments/me');
    final List list = response.data;
    return list.map((json) => Appointment.fromJson(json)).toList();
  }

  Future<List<Appointment>> getWorkshopAppointments({String? sucursalId}) async {
    final params = <String, dynamic>{};
    if (sucursalId != null && sucursalId.isNotEmpty) {
      params['id_sucursal'] = sucursalId;
    }

    final response = await _dio.get(
      '/api/v1/scheduling/appointments/workshop',
      queryParameters: params,
    );
    final List list = response.data;
    return list.map((json) => Appointment.fromJson(json)).toList();
  }

  Future<Appointment> confirmAppointment(String id) async {
    final response = await _dio.put('/api/v1/scheduling/appointments/$id/confirm');
    return Appointment.fromJson(response.data);
  }

  Future<Appointment> rescheduleAppointment({
    required String id,
    required DateTime newDatetime,
    String? observaciones,
  }) async {
    final response = await _dio.put(
      '/api/v1/scheduling/appointments/$id/reschedule',
      data: {
        'fecha_hora': newDatetime.toUtc().toIso8601String(),
        'observaciones': observaciones,
      },
    );
    return Appointment.fromJson(response.data);
  }

  Future<Appointment> cancelAppointment(String id) async {
    final response = await _dio.put('/api/v1/scheduling/appointments/$id/cancel');
    return Appointment.fromJson(response.data);
  }

  Future<Appointment> completeAppointment(String id) async {
    final response = await _dio.put('/api/v1/scheduling/appointments/$id/complete');
    return Appointment.fromJson(response.data);
  }
}
