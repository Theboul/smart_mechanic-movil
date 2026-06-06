import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scheduling_repository.dart';
import '../../domain/appointment.dart';

class SlotAvailabilityQuery {
  final String sucursalId;
  final String dateStr;
  final String? tecnicoId;

  const SlotAvailabilityQuery({
    required this.sucursalId,
    required this.dateStr,
    this.tecnicoId,
  });

  @override
  bool operator ==(Object other) {
    return other is SlotAvailabilityQuery &&
        other.sucursalId == sucursalId &&
        other.dateStr == dateStr &&
        other.tecnicoId == tecnicoId;
  }

  @override
  int get hashCode => Object.hash(sucursalId, dateStr, tecnicoId);
}

final myAppointmentsProvider = FutureProvider.autoDispose<List<Appointment>>((ref) async {
  final repo = ref.watch(schedulingRepositoryProvider);
  return await repo.getMyAppointments();
});

final workshopAppointmentsProvider = FutureProvider.autoDispose<List<Appointment>>((ref) async {
  final repo = ref.watch(schedulingRepositoryProvider);
  return await repo.getWorkshopAppointments();
});

// A provider to fetch availability slots for a given sucursal and date
final slotsAvailabilityProvider = FutureProvider.family.autoDispose<List<SlotAvailability>, SlotAvailabilityQuery>((ref, params) async {
  final repo = ref.watch(schedulingRepositoryProvider);
  return await repo.getSlotsAvailability(
    sucursalId: params.sucursalId,
    dateStr: params.dateStr,
    tecnicoId: params.tecnicoId,
  );
});
