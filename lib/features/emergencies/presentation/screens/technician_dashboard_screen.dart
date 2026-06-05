import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../identity/domain/user.dart';
import '../../../identity/presentation/providers/auth_provider.dart';
import '../../domain/incident.dart';
import '../providers/emergency_provider.dart';

class TechnicianDashboardScreen extends ConsumerStatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  ConsumerState<TechnicianDashboardScreen> createState() => _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState extends ConsumerState<TechnicianDashboardScreen> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Polling de seguridad para refrescar el estado de la emergencia asignada cada 10 segundos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(emergencyNotifierProvider.notifier).refreshStatus();
    });
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        ref.read(emergencyNotifierProvider.notifier).refreshStatus();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final emergencyState = ref.watch(emergencyNotifierProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('CENTRO DE AUXILIO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(emergencyNotifierProvider.notifier).refreshStatus(),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Cabecera del Técnico
              _buildHeader(user),
              const SizedBox(height: 30),

              // Contenido Principal
              emergencyState.when(
                data: (incident) {
                  if (incident == null) {
                    return _buildNoAssignmentCard();
                  }
                  return _buildAssignmentCard(context, incident);
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  ),
                ),
                error: (error, _) => _buildErrorCard(error.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(User? user) {
    final nombre = user?.nombre ?? 'Técnico';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            child: const Icon(Icons.engineering_rounded, color: Color(0xFF3B82F6), size: 35),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Hola!',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Text(
                  nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                // Badge de Estado Disponible
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.green, size: 8),
                      SizedBox(width: 6),
                      Text(
                        'DISPONIBLE',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAssignmentCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_paused_rounded,
            color: Colors.white.withValues(alpha: 0.3),
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Sin emergencias asignadas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mantente alerta, recibirás una notificación cuando se asigne un incidente a tu taller.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(BuildContext context, IncidentResponse incident) {
    final status = incident.estado.toUpperCase();
    final vehicleText = '${incident.vehicleBrand ?? ''} ${incident.vehicleModel ?? ''}';
    final hasHighPriority = incident.prioridad.toUpperCase() == 'CRITICA';
    final accentColor = hasHighPriority ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.15),
            const Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_amber_rounded, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EMERGENCIA ASIGNADA',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Estado: $status',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.person_outline, 'Cliente', incident.clientName ?? 'Desconocido'),
          _buildInfoRow(Icons.directions_car_filled_outlined, 'Vehículo', vehicleText.trim().isEmpty ? 'Vehículo' : vehicleText),
          _buildInfoRow(Icons.description_outlined, 'Descripción', incident.descripcion ?? 'Sin descripción'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (status == 'EN_CAMINO' || status == 'TECNICO_EN_SITIO') {
                context.push('/technician/active-trip');
              } else {
                context.push('/technician/incident-detail');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shadowColor: const Color(0xFF3B82F6).withValues(alpha: 0.4),
            ),
            child: const Text('VER DETALLES'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: '$label: ',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text(
            'Error al cargar: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
