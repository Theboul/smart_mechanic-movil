import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../data/scheduling_repository.dart';
import '../../domain/appointment.dart';
import '../providers/scheduling_provider.dart';
import '../../../emergencies/presentation/widgets/sos_screen/sos_bottom_nav.dart';

class CitasScreen extends ConsumerStatefulWidget {
  const CitasScreen({super.key});

  @override
  ConsumerState<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends ConsumerState<CitasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(myAppointmentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B).withValues(alpha: 0.8),
                    const Color(0xFF0F172A),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: appointmentsAsync.when(
                    data: (appointments) => _buildTabBarView(appointments),
                    loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
                    error: (err, _) => Center(
                      child: Text('Error al cargar citas: $err', style: const TextStyle(color: Colors.redAccent)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SosBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) context.go('/');
          if (index == 1) context.go('/garage');
          if (index == 3) context.go('/history');
        },
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MIS CITAS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Seguimiento y revisiones en taller',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange, width: 1.5),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'PENDIENTES'),
          Tab(text: 'CONFIRMADAS / HISTORIAL'),
        ],
      ),
    );
  }

  Widget _buildTabBarView(List<Appointment> appointments) {
    final pending = appointments
        .where((a) => a.estado == 'PENDIENTE_CONFIRMACION' || a.estado == 'REPROGRAMACION_SOLICITADA')
        .toList();
    final confirmedOrHistory = appointments
        .where((a) => a.estado != 'PENDIENTE_CONFIRMACION' && a.estado != 'REPROGRAMACION_SOLICITADA')
        .toList();

    return TabBarView(
      controller: _tabController,
      children: [
        _buildList(pending, isPending: true),
        _buildList(confirmedOrHistory, isPending: false),
      ],
    );
  }

  Widget _buildList(List<Appointment> list, {required bool isPending}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.calendar_today_rounded : Icons.history_rounded,
              size: 70,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'No tienes citas pendientes' : 'No tienes historial de citas',
              style: const TextStyle(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: () async {
        ref.invalidate(myAppointmentsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: list.length,
        itemBuilder: (context, index) {
          return _buildAppointmentCard(list[index]);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appt) {
    final formattedDate = DateFormat('EEEE dd MMM yyyy', 'es').format(appt.fechaHora);
    final formattedTime = DateFormat('HH:mm').format(appt.fechaHora);
    
    Color statusColor = Colors.orangeAccent;
    if (appt.estado == 'CONFIRMADA') {
      statusColor = Colors.greenAccent;
    } else if (appt.estado == 'CANCELADA') {
      statusColor = Colors.redAccent;
    } else if (appt.estado == 'COMPLETADA') {
      statusColor = Colors.blueAccent;
    } else if (appt.estado == 'REPROGRAMACION_SOLICITADA') {
      statusColor = Colors.purpleAccent;
    }

    Color priorityColor = Colors.grey;
    if (appt.prioridad == 'ALTA') {
      priorityColor = Colors.redAccent;
    } else if (appt.prioridad == 'MEDIA') {
      priorityColor = Colors.orangeAccent;
    } else if (appt.prioridad == 'BAJA') {
      priorityColor = Colors.blueAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row superior: Estado y Prioridad
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  appt.estado.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PRIORIDAD ${appt.prioridad}',
                  style: TextStyle(color: priorityColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Taller y Sucursal
          Text(
            appt.sucursalNombre ?? 'Sucursal de Taller',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          // Horario
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: Colors.orangeAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                '$formattedDate, a las $formattedTime (${appt.duracionMinutos} min)',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Vehículo
          Row(
            children: [
              const Icon(Icons.directions_car_rounded, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(
                '${appt.vehiculoMarca ?? ''} ${appt.vehiculoModelo ?? ''} (${appt.vehiculoMatricula ?? ''})',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),

          // Motivo
          const Text('MOTIVO DE SEGUIMIENTO', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            appt.motivo,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          if (appt.observaciones != null && appt.observaciones!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('OBSERVACIONES', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              appt.observaciones!,
              style: const TextStyle(color: Colors.white60, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],

          if (appt.idIncidenteOrigen != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.link_rounded, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Cita posterior derivada de auxilio vial',
                  style: TextStyle(color: Colors.blueAccent.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],

          // Acciones si está Pendiente
          if (appt.estado == 'PENDIENTE_CONFIRMACION') ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmAction(appt, 'cancelar'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('RECHAZAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRescheduleDialog(appt),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('REPROGRAMAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmAction(appt, 'confirmar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CONFIRMAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],

          if (appt.estado == 'REPROGRAMACION_SOLICITADA') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmAction(appt, 'cancelar'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CANCELAR CITA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Future<void> _confirmAction(Appointment appt, String action) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          action == 'confirmar' ? 'Confirmar Cita' : 'Rechazar Cita',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          action == 'confirmar'
              ? '¿Deseas confirmar la cita sugerida para el taller?'
              : '¿Estás seguro de que deseas rechazar/cancelar esta cita de seguimiento?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'confirmar' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(action == 'confirmar' ? 'CONFIRMAR' : 'RECHAZAR'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = ref.read(schedulingRepositoryProvider);
      if (action == 'confirmar') {
        await repo.confirmAppointment(appt.idCita);
      } else {
        await repo.cancelAppointment(appt.idCita);
      }
      ref.invalidate(myAppointmentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'confirmar' ? 'Cita confirmada correctamente' : 'Cita cancelada correctamente'),
          backgroundColor: action == 'confirmar' ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _showRescheduleDialog(Appointment appt) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      selectableDayPredicate: (date) => date.weekday != DateTime.sunday,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orange,
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null) return;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
        return Consumer(
          builder: (context, ref, _) {
            final slotsAsync = ref.watch(slotsAvailabilityProvider(
              SlotAvailabilityQuery(
                sucursalId: appt.idSucursal,
                dateStr: dateStr,
                tecnicoId: appt.idTecnico,
              ),
            ));

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slots para: ${DateFormat('EEEE d MMMM', 'es').format(selectedDate)}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: slotsAsync.when(
                      data: (slots) {
                        final available = slots.where((s) => s.disponible).toList();
                        if (available.isEmpty) {
                          return const Center(
                            child: Text(
                              'No hay horarios disponibles para este día.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        return GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2.2,
                          ),
                          itemCount: available.length,
                          itemBuilder: (context, idx) {
                            final slot = available[idx];
                            final timeStr = DateFormat('HH:mm').format(slot.fechaHora);
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange, width: 1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                Navigator.pop(sheetContext);
                                _submitReschedule(appt, slot.fechaHora);
                              },
                              child: Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
                      error: (err, _) => Center(
                        child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitReschedule(Appointment appt, DateTime newDatetime) async {
    try {
      final repo = ref.read(schedulingRepositoryProvider);
      await repo.rescheduleAppointment(
        id: appt.idCita,
        newDatetime: newDatetime,
        observaciones: 'Reprogramación solicitada por el cliente.',
      );
      ref.invalidate(myAppointmentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reprogramación solicitada. Queda en espera de confirmación.'),
          backgroundColor: Colors.purple,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reprogramar: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}
