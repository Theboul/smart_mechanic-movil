import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../emergencies/presentation/providers/emergency_provider.dart';
import '../../domain/quotation.dart';
import '../providers/quotation_providers.dart';
import '../widgets/quotation_quote_card.dart';

class QuotationRequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  final QuotationRequestSummary? initialRequest;

  const QuotationRequestDetailScreen({
    super.key,
    required this.requestId,
    this.initialRequest,
  });

  @override
  ConsumerState<QuotationRequestDetailScreen> createState() =>
      _QuotationRequestDetailScreenState();
}

class _QuotationRequestDetailScreenState
    extends ConsumerState<QuotationRequestDetailScreen>
    with WidgetsBindingObserver {
  String? _selectedQuoteId;
  QuotationIncident? _selectedIncident;
  Timer? _quotesRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshData());
    });
    _quotesRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      ref.invalidate(quotationRequestQuotesProvider(widget.requestId));
      ref.invalidate(quotationMyRequestsProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quotesRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_refreshData());
    }
  }

  @override
  Widget build(BuildContext context) {
    final myRequestsAsync = ref.watch(quotationMyRequestsProvider);
    final quotesAsync = ref.watch(
      quotationRequestQuotesProvider(widget.requestId),
    );

    final liveRequest = myRequestsAsync.maybeWhen(
      data: (requests) => requests
          .where((item) => item.idSolicitudCotizacion == widget.requestId)
          .cast<QuotationRequestSummary?>()
          .firstOrNull,
      orElse: () => null,
    );

    final request = liveRequest ?? widget.initialRequest;
    final cancelableRequest =
        request != null && _canCancelRequest(request.estado) ? request : null;
    final isCancelling =
        ref.watch(quotationCancelRequestControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('DETALLE DE SOLICITUD'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          if (cancelableRequest != null)
            TextButton(
              onPressed:
                  isCancelling ? null : () => _cancelRequest(cancelableRequest),
              child: Text(
                isCancelling ? 'CANCELANDO...' : 'CANCELAR',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B).withValues(alpha: 0.85),
                    const Color(0xFF0F172A),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: Colors.blueAccent,
              onRefresh: _refreshData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  if (_selectedIncident != null) ...[
                    _buildIncidentCard(context, _selectedIncident!),
                    const SizedBox(height: 16),
                  ],
                  _buildRequestCard(request),
                  const SizedBox(height: 18),
                  const Text(
                    'Propuestas recibidas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  quotesAsync.when(
                    data: (quotes) {
                      if (request != null && request.estado == 'CANCELADA') {
                        return _buildEmptyNotice(
                          'La solicitud fue cancelada. Ya no se pueden seleccionar propuestas.',
                        );
                      }
                      if (quotes.isEmpty) {
                        return _buildEmptyNotice(
                          'Esperando propuestas de talleres cercanos.',
                        );
                      }
                      return Column(
                        children: quotes
                            .map(
                              (quote) => QuotationQuoteCard(
                                quote: quote,
                                isLoading:
                                    _selectedQuoteId == quote.idCotizacion &&
                                    ref
                                        .watch(
                                          quotationSelectionControllerProvider,
                                        )
                                        .isLoading,
                                onSelect: () => _selectQuote(quote),
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Error al cargar cotizaciones: $err',
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _refreshData,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(QuotationRequestSummary? request) {
    if (request == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Text(
          'No se encontro la solicitud.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Container(
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _stateColor(request.estado).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  request.estado.replaceAll('_', ' '),
                  style: TextStyle(
                    color: _stateColor(request.estado),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Vence ${_formatDate(request.fechaVencimiento)}',
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
                : 'Sin observaciones.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _fieldChip(
                  'Vehiculo',
                  request.vehicleLabel ?? 'Vehiculo sin detalle',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _fieldChip('Prioridad', request.prioridad)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Talleres compatibles',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (request.compatibleWorkshops.isEmpty)
            const Text(
              'No hay talleres compatibles disponibles.',
              style: TextStyle(color: Colors.white54),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: request.compatibleWorkshops
                  .map(
                    (workshop) => Chip(
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      label: Text(
                        '${workshop.workshopName ?? 'Taller'} - ${workshop.branchName ?? 'Sucursal'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _fieldChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white54)),
    );
  }

  Widget _buildIncidentCard(BuildContext context, QuotationIncident incident) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Incidente generado desde la cotizacion',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ID incidente: ${incident.idIncidente}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          Text(
            'Estado: ${incident.estadoIncidente}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            'Prioridad: ${incident.prioridadIncidente}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (incident.origen != null)
            Text(
              'Origen: ${incident.origen}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/'),
              child: const Text(
                'VOLVER AL INICIO',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectQuote(QuotationQuote quote) async {
    if (quote.idIncidenteGenerado != null) return;
    setState(() => _selectedQuoteId = quote.idCotizacion);
    try {
      final incident = await ref
          .read(quotationSelectionControllerProvider.notifier)
          .selectQuote(
            requestId: widget.requestId,
            quoteId: quote.idCotizacion,
          );
      if (!mounted) return;
      setState(() => _selectedIncident = incident);
      await _refreshData();
      ref.read(emergencyNotifierProvider.notifier).refreshStatus();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Cotizacion seleccionada',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Se genero el incidente ${incident.idIncidente}. El flujo normal continuara desde el inicio.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.go('/');
              },
              child: const Text(
                'IR AL INICIO',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar cotizacion: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _selectedQuoteId = null);
      }
    }
  }

  Future<void> _cancelRequest(QuotationRequestSummary request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Cancelar solicitud',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Se cancelaran las invitaciones activas y ya no podras seleccionar una cotizacion para esta solicitud.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'VOLVER',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'CANCELAR SOLICITUD',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(quotationCancelRequestControllerProvider.notifier)
          .cancelRequest(request.idSolicitudCotizacion);
      if (!mounted) return;
      await _refreshData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud cancelada correctamente.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cancelar la solicitud: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      ref.refresh(quotationMyRequestsProvider.future),
      ref.refresh(quotationRequestQuotesProvider(widget.requestId).future),
    ]);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'es').format(date);
  }

  bool _canCancelRequest(String estado) {
    const allowed = {'ABIERTA', 'SIN_PROPUESTAS'};
    return allowed.contains(estado.toUpperCase());
  }

  Color _stateColor(String estado) {
    final normalized = estado.toUpperCase();
    if (normalized.contains('CANCEL')) return Colors.redAccent;
    if (normalized.contains('SELECCION')) return Colors.greenAccent;
    if (normalized.contains('SIN')) return Colors.orangeAccent;
    return Colors.blueAccent;
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
