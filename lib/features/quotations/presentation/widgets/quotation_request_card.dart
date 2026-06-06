import 'package:flutter/material.dart';

import '../../domain/quotation.dart';

class QuotationRequestCard extends StatelessWidget {
  final QuotationRequestSummary request;
  final VoidCallback onTap;

  const QuotationRequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stateColor = _stateColor(request.estado);
    final workshopsPreview = request.compatibleWorkshops
        .take(2)
        .map((item) => item.workshopName ?? 'Taller')
        .join(' • ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    request.estado.replaceAll('_', ' '),
                    style: TextStyle(
                      color: stateColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  _formatDate(request.fechaCreacion),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.descripcion?.trim().isNotEmpty == true
                  ? request.descripcion!
                  : 'Solicitud sin descripcion',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              request.observaciones?.trim().isNotEmpty == true
                  ? request.observaciones!
                  : 'Sin observaciones adicionales',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(
                  label: 'Vehiculo',
                  value: request.vehicleLabel ?? 'Vehiculo sin detalle',
                ),
                const SizedBox(width: 8),
                _InfoChip(label: 'Prioridad', value: request.prioridad),
                const SizedBox(width: 8),
                _InfoChip(
                  label: 'Talleres',
                  value: workshopsPreview.isNotEmpty
                      ? workshopsPreview
                      : '${request.compatibleWorkshops.length} disponibles',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _stateColor(String state) {
    final normalized = state.toUpperCase();
    if (normalized.contains('CANCEL')) return Colors.redAccent;
    if (normalized.contains('SELECCION')) return Colors.greenAccent;
    if (normalized.contains('SIN')) return Colors.orangeAccent;
    return Colors.blueAccent;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
