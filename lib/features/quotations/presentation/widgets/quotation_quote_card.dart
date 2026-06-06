import 'package:flutter/material.dart';

import '../../domain/quotation.dart';

class QuotationQuoteCard extends StatelessWidget {
  final QuotationQuote quote;
  final VoidCallback onSelect;
  final bool isLoading;

  const QuotationQuoteCard({
    super.key,
    required this.quote,
    required this.onSelect,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final expired = DateTime.now().toUtc().isAfter(quote.vigenciaHasta.toUtc());
    final stateColor = _stateColor(quote.estado);
    final canSelect =
        !expired &&
        quote.idIncidenteGenerado == null &&
        !isLoading &&
        quote.estado.toUpperCase() == 'PENDIENTE';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: quote.idIncidenteGenerado != null
              ? Colors.greenAccent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  quote.estado.replaceAll('_', ' '),
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Vence ${_formatDate(quote.vigenciaHasta)}',
                style: TextStyle(
                  color: expired ? Colors.redAccent : Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            quote.workshopName ?? 'Taller',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${quote.branchName ?? 'Sucursal'}${quote.responderName != null ? ' - ${quote.responderName}' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _AmountTile(label: 'Mano de obra', value: quote.manoObraEstimado),
              const SizedBox(width: 8),
              _AmountTile(label: 'Repuestos', value: quote.repuestosEstimado),
              const SizedBox(width: 8),
              _AmountTile(
                label: 'Total',
                value: quote.totalEstimado,
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoPill(
                  label: 'Tiempo estimado',
                  value: '${quote.tiempoEstimadoMinutos} min',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoPill(
                  label: 'Estado',
                  value: quote.estado.replaceAll('_', ' '),
                ),
              ),
            ],
          ),
          if (quote.observaciones != null && quote.observaciones!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              quote.observaciones!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            quote.idIncidenteGenerado != null
                ? 'Incidente generado desde esta cotizacion'
                : expired
                    ? 'Cotizacion vencida'
                    : 'Esperando seleccion del cliente',
            style: TextStyle(
              color: quote.idIncidenteGenerado != null
                  ? Colors.greenAccent
                  : expired
                      ? Colors.redAccent
                      : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSelect ? onSelect : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'ACEPTAR PROPUESTA',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _stateColor(String state) {
    final normalized = state.toUpperCase();
    if (normalized.contains('ACEPT')) return Colors.greenAccent;
    if (normalized.contains('RECHAZ') || normalized.contains('CANCEL')) {
      return Colors.redAccent;
    }
    return Colors.orangeAccent;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;

  const _AmountTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.greenAccent.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight
                ? Colors.greenAccent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const SizedBox(height: 3),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                color: highlight ? Colors.greenAccent : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _InfoPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
