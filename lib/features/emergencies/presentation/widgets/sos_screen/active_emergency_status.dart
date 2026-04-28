import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/incident.dart';
import '../../providers/emergency_provider.dart';

class ActiveEmergencyStatus extends ConsumerWidget {
  final IncidentResponse incident;
  final VoidCallback onRefresh;

  const ActiveEmergencyStatus({
    super.key,
    required this.incident,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildStatusIcon(),
          const SizedBox(height: 20),
          Text(
            _getStatusTitle().toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusDescription(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 30),
          _buildProgressStepper(),
          if (incident.resumenIa != null) ...[
            const SizedBox(height: 24),
            _buildAiAnalysis(),
          ],
          const SizedBox(height: 30),
          if (incident.workshopId != null) _buildWorkshopInfo(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('REINTENTAR', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showCancelDialog(context, ref),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('CANCELAR', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // Pequeño margen extra al final de la tarjeta
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon = Icons.hourglass_empty_rounded;
    Color color = Colors.orangeAccent;

    final status = incident.estado.toUpperCase();
    if (status == 'TALLER_ASIGNADO' || status == 'ANALIZADO') {
      icon = Icons.home_work_rounded;
      color = Colors.blueAccent;
    } else if (status == 'EN_CAMINO' || status == 'ACEPTADO') {
      icon = Icons.local_shipping_rounded;
      color = Colors.greenAccent;
    } else if (status == 'EN_PROGRESO') {
      icon = Icons.build_circle_rounded;
      color = Colors.purpleAccent;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 40),
    );
  }

  String _getStatusTitle() {
    switch (incident.estado.toUpperCase()) {
      case 'PENDIENTE':
      case 'REPORTADO':
        return 'Buscando Ayuda';
      case 'ANALIZADO':
      case 'TALLER_ASIGNADO':
        return 'Taller Notificado';
      case 'ACEPTADO':
      case 'EN_CAMINO':
        return 'Mecánico en Camino';
      case 'EN_PROGRESO':
        return 'En Reparación';
      default:
        return 'Procesando...';
    }
  }

  String _getStatusDescription() {
    switch (incident.estado.toUpperCase()) {
      case 'PENDIENTE':
      case 'REPORTADO':
        return 'Estamos localizando el taller más cercano a tu ubicación.';
      case 'ANALIZADO':
      case 'TALLER_ASIGNADO':
        return 'Hemos encontrado un taller. Esperando confirmación del mecánico.';
      case 'ACEPTADO':
      case 'EN_CAMINO':
        return '¡Buenas noticias! El técnico ya salió hacia tu ubicación.';
      case 'EN_PROGRESO':
        return 'El mecánico está trabajando en tu vehículo ahora mismo.';
      default:
        return 'Estamos trabajando en tu solicitud.';
    }
  }

  Widget _buildProgressStepper() {
    final status = incident.estado.toUpperCase();
    int step = 1;
    if (status == 'TALLER_ASIGNADO' || status == 'ANALIZADO') {
      step = 2;
    }
    if (status == 'EN_CAMINO' ||
        status == 'ACEPTADO' ||
        status == 'EN_PROGRESO') {
      step = 3;
    }

    return Row(
      children: [
        _buildStep(1, step >= 1),
        _buildLine(step >= 2),
        _buildStep(2, step >= 2),
        _buildLine(step >= 3),
        _buildStep(3, step >= 3),
      ],
    );
  }

  Widget _buildStep(int number, bool active) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? Colors.blueAccent : Colors.white10,
        shape: BoxShape.circle,
        border: active ? null : Border.all(color: Colors.white24),
      ),
      child: Center(
        child: active
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                '$number',
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              ),
      ),
    );
  }

  Widget _buildLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? Colors.blueAccent : Colors.white10,
      ),
    );
  }

  Widget _buildWorkshopInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.home_work_rounded,
                color: Colors.blueAccent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TALLER SELECCIONADO',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      incident.workshopName ?? 'Buscando taller...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (incident.technicianId != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.greenAccent.withValues(alpha: 0.1),
                  Colors.blueAccent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person,
                    color: Colors.greenAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.technicianName ?? 'Técnico asignado',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        incident.technicianPhone ?? 'Mecánico en ruta',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.phone,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: () {
                      // Implementar llamada si es necesario
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAiAnalysis() {
    final hasHighGravity = incident.analisisConsolidado?.toUpperCase().contains('ALTA') ?? false;
    final accentColor = hasHighGravity ? Colors.redAccent : Colors.blueAccent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
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
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: const Text(
                  'DIAGNÓSTICO IA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              if (hasHighGravity)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'CRÍTICO',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            incident.resumenIa ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (incident.analisisConsolidado != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white10, height: 1),
            ),
            Text(
              incident.analisisConsolidado!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Cancelar Emergencia?', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas cancelar esta solicitud de auxilio? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NO, VOLVER', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(emergencyNotifierProvider.notifier).cancelSOS(incident.id);
              Navigator.pop(context);
            },
            child: const Text('SÍ, CANCELAR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
