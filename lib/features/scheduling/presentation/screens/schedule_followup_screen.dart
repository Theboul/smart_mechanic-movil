import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../data/scheduling_repository.dart';
import '../providers/scheduling_provider.dart';
import '../../../emergencies/presentation/providers/emergency_provider.dart';

class ScheduleFollowUpScreen extends ConsumerStatefulWidget {
  final String incidentId;
  final String vehicleId;
  final String sucursalId;
  final String? tecnicoId;

  const ScheduleFollowUpScreen({
    super.key,
    required this.incidentId,
    required this.vehicleId,
    required this.sucursalId,
    this.tecnicoId,
  });

  @override
  ConsumerState<ScheduleFollowUpScreen> createState() => _ScheduleFollowUpScreenState();
}

class _ScheduleFollowUpScreenState extends ConsumerState<ScheduleFollowUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motivoController = TextEditingController();
  final _observacionesController = TextEditingController();
  
  DateTime? _selectedDate;
  DateTime? _selectedTimeSlot;
  String _prioridad = 'MEDIA'; // default
  bool _assignToMe = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _motivoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('AGENDAR CITA POSTERIOR'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detalles del Seguimiento',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Proponga un horario para la revisión del vehículo en el taller.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Motivo
                const Text('Motivo del Seguimiento *', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _motivoController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ej. Cambio de pastillas de freno en taller, revisión general...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'El motivo es requerido' : null,
                ),
                const SizedBox(height: 20),

                // Observaciones
                const Text('Observaciones / Instrucciones', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _observacionesController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ej. Traer repuesto comprado por el cliente, ruidos persistentes...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // Prioridad
                const Text('Prioridad de Cita', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: ['BAJA', 'MEDIA', 'ALTA'].map((p) {
                    final bool isSelected = _prioridad == p;
                    Color pColor = Colors.blueAccent;
                    if (p == 'ALTA') pColor = Colors.redAccent;
                    if (p == 'MEDIA') pColor = Colors.orangeAccent;
                    
                    return Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _prioridad = p),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? pColor.withValues(alpha: 0.15) : const Color(0xFF1E293B),
                            border: Border.all(
                              color: isSelected ? pColor : Colors.transparent,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Seleccionar Fecha
                const Text('Fecha Solicitada *', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_month, color: Colors.black),
                  label: Text(
                    _selectedDate == null 
                        ? 'SELECCIONAR FECHA' 
                        : DateFormat('EEEE dd MMMM', 'es').format(_selectedDate!).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // Seleccionar Hora (Slots)
                if (_selectedDate != null) ...[
                  const Text('Hora Solicitada (Slots de 60 mins) *', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  _buildSlotsSectionV2(),
                  const SizedBox(height: 20),
                ],

                // Auto-asignación
                if (widget.tecnicoId != null) ...[
                  CheckboxListTile(
                    title: const Text('Asignar esta cita a mí', style: TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: const Text('Será el técnico encargado de recibir el vehículo.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    value: _assignToMe,
                    activeColor: Colors.orange,
                    checkColor: Colors.black,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _assignToMe = val ?? true),
                  ),
                  const SizedBox(height: 20),
                ],

                // Botón Guardar
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: (_isSaving || _selectedDate == null || _selectedTimeSlot == null) ? null : _saveAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981), // green accent
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : const Text('PROPONER CITA AL CLIENTE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSlotsSection() {
    if (widget.sucursalId.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No se pudo determinar la sucursal del taller.\nVuelve al incidente e intenta nuevamente.',
            style: TextStyle(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final slotsAsync = ref.watch(slotsAvailabilityProvider(
      SlotAvailabilityQuery(
        sucursalId: widget.sucursalId,
        dateStr: dateStr,
        tecnicoId: _assignToMe ? widget.tecnicoId : null,
      ),
    ));

    return slotsAsync.when(
      data: (slots) {
        final available = slots.where((s) => s.disponible).toList();
        if (available.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No hay horarios disponibles para esta fecha. Intente con otro día.',
                style: TextStyle(color: Colors.redAccent, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.3,
          ),
          itemCount: available.length,
          itemBuilder: (context, idx) {
            final slot = available[idx];
            final timeStr = DateFormat('HH:mm').format(slot.fechaHora);
            final bool isSelected = _selectedTimeSlot == slot.fechaHora;
            
            return InkWell(
              onTap: () => setState(() => _selectedTimeSlot = slot.fechaHora),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.withValues(alpha: 0.15) : const Color(0xFF1E293B),
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.transparent,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  timeStr,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(color: Colors.orange),
      )),
      error: (err, _) => Center(
        child: Text('Error al cargar disponibilidad: $err', style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  Widget _buildSlotsSectionV2() {
    if (widget.sucursalId.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No se pudo determinar la sucursal del taller.\nVuelve al incidente e intenta nuevamente.',
            style: TextStyle(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final date = _selectedDate;
    if (date == null) {
      return const SizedBox.shrink();
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final query = SlotAvailabilityQuery(
      sucursalId: widget.sucursalId,
      dateStr: dateStr,
      tecnicoId: _assignToMe ? widget.tecnicoId : null,
    );

    final slotsAsync = ref.watch(slotsAvailabilityProvider(query));

    return slotsAsync.when(
      data: (slots) {
        if (slots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const Text(
                  'No hay horarios disponibles para esta fecha.\nSelecciona otro día.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _selectDate,
                  child: const Text('CAMBIAR FECHA', style: TextStyle(color: Colors.orange)),
                ),
              ],
            ),
          );
        }

        final available = slots.where((s) => s.disponible).toList();
        if (available.isEmpty) {
          final reason = slots.first.motivo ?? 'No hay horarios disponibles para esta fecha.';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Text(
                  '$reason\nSelecciona otro día.',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _selectDate,
                  child: const Text('CAMBIAR FECHA', style: TextStyle(color: Colors.orange)),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.3,
          ),
          itemCount: available.length,
          itemBuilder: (context, idx) {
            final slot = available[idx];
            final timeStr = DateFormat('HH:mm').format(slot.fechaHora);
            final bool isSelected = _selectedTimeSlot == slot.fechaHora;

            return InkWell(
              onTap: () => setState(() => _selectedTimeSlot = slot.fechaHora),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.withValues(alpha: 0.15) : const Color(0xFF1E293B),
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.transparent,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  timeStr,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(
              'Error al cargar disponibilidad:\n$err',
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (_selectedDate != null) {
                  ref.invalidate(slotsAvailabilityProvider(query));
                }
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
              ),
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
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

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlot = null; // reset slot selection
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar fecha y hora de la cita'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(schedulingRepositoryProvider);
      await repo.createAppointment(
        incidentId: widget.incidentId,
        vehicleId: widget.vehicleId,
        datetime: _selectedTimeSlot!,
        motivo: _motivoController.text.trim(),
        observaciones: _observacionesController.text.trim(),
        prioridad: _prioridad,
        tecnicoId: (_assignToMe && widget.tecnicoId != null) ? widget.tecnicoId : null,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Cita de seguimiento propuesta al cliente con éxito!'), backgroundColor: Colors.green),
      );
      
      await ref.read(emergencyNotifierProvider.notifier).refreshStatus();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agendar cita: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}
