import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:smart_mechanic_app/core/utils/map_loader.dart' as map_loader;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../providers/emergency_provider.dart';
import '../../data/emergency_repository.dart';
import '../../domain/incident.dart';

class TechnicianIncidentDetailScreen extends ConsumerStatefulWidget {
  const TechnicianIncidentDetailScreen({super.key});

  @override
  ConsumerState<TechnicianIncidentDetailScreen> createState() => _TechnicianIncidentDetailScreenState();
}

class _TechnicianIncidentDetailScreenState extends ConsumerState<TechnicianIncidentDetailScreen> {
  IncidentResponse? _cachedIncident;

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(emergencyNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('DETALLE DE EMERGENCIA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: emergencyState.when(
        data: (incidentParam) {
          if (incidentParam != null) {
            _cachedIncident = incidentParam;
          }

          final incident = _cachedIncident;
          if (incident == null) {
            return const Center(child: Text('No hay incidente activo', style: TextStyle(color: Colors.white)));
          }

          final lat = incident.latitud ?? -17.7833;
          final lng = incident.longitud ?? -63.1821;
          final incidentLatLng = LatLng(lat, lng);
          final vehicleText = '${incident.vehicleBrand ?? ''} ${incident.vehicleModel ?? ''}';
          final status = incident.estado;

          return Stack(
            children: [
              // 1. Google Map de Fondo (Ocupando la mitad superior de la pantalla)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.4,
                child: (kIsWeb && !map_loader.isGoogleMapsInitialized())
                    ? Container(
                        color: const Color(0xFF1E293B),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          map_loader.hasGoogleMapsApiKey()
                              ? 'Cargando mapa...'
                              : 'No se pudo cargar el mapa. Configura GOOGLE_MAPS_API_KEY.',
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: incidentLatLng,
                          zoom: 15,
                        ),
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        markers: {
                          Marker(
                            markerId: const MarkerId('incident_loc'),
                            position: incidentLatLng,
                            infoWindow: const InfoWindow(title: 'Vehículo Avariado'),
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                          ),
                        },
                      ),
              ),

              // Botón flotante para abrir en app de mapas externa
              Positioned(
                top: MediaQuery.of(context).size.height * 0.4 - 70,
                right: 16,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF3B82F6),
                  mini: false,
                  child: const Icon(Icons.navigation_rounded, color: Colors.white),
                  onPressed: () => _openExternalMaps(lat, lng),
                ),
              ),

              // 2. Panel Inferior Desplazable con Detalles (Charcoal Premium con Glassmorphism)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.4 - 20,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 15,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera Cliente
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            child: const Icon(Icons.person, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  incident.clientName ?? 'Cliente',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  incident.clientPhone ?? 'Contacto',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Botón de llamada rápida
                          if (incident.clientPhone != null)
                            IconButton.filled(
                              icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                              ),
                              onPressed: () => launchUrl(Uri.parse('tel:${incident.clientPhone}')),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 16),

                      // Detalles del Vehículo
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow(
                                Icons.directions_car_filled_outlined,
                                'Vehículo',
                                vehicleText.trim().isEmpty ? 'Desconocido' : vehicleText,
                              ),
                              _buildDetailRow(
                                Icons.pin_rounded,
                                'Placa',
                                incident.vehiclePlate ?? 'Desconocida',
                              ),
                              _buildDetailRow(
                                Icons.color_lens_outlined,
                                'Color / Año',
                                '${incident.vehicleColor ?? "N/A"} • ${incident.vehicleYear ?? "N/A"}',
                              ),
                              _buildDetailRow(
                                Icons.location_on_outlined,
                                'Ubicación de avería',
                                'Coordenadas: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                              ),
                              _buildDetailRow(
                                Icons.chat_bubble_outline_rounded,
                                'Comentarios',
                                incident.descripcion ?? 'Sin descripción',
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Botón Principal Dinámico
                      if (status == 'EN_ATENCION' || status == 'EN_PROGRESO')
                        ElevatedButton(
                          onPressed: () => _showFinishConfirmation(context, incident),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981), // Esmeralda premium
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 58),
                            shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.black),
                              SizedBox(width: 8),
                              Text('FINALIZAR ATENCIÓN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                            ],
                          ),
                        )
                      else if (status == 'EN_CAMINO')
                        ElevatedButton(
                          onPressed: () => context.push('/technician/active-trip'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 58),
                            shadowColor: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text('VER MAPA DE VIAJE'),
                            ],
                          ),
                        )
                      else if (status == 'TALLER_ASIGNADO' || status == 'ACEPTADO')
                        ElevatedButton(
                          onPressed: () => _startJourney(context, incident.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 58),
                            shadowColor: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text('INICIAR VIAJE'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 2),
                Text(val, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalMaps(double lat, double lng) async {
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    final wazeUrl = 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(Uri.parse(wazeUrl))) {
      await launchUrl(Uri.parse(wazeUrl), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _startJourney(BuildContext context, String incidentId) async {
    try {
      await ref.read(emergencyNotifierProvider.notifier).updateStatus(incidentId, 'EN_CAMINO');
      if (!context.mounted) return;
      context.pushReplacement('/technician/active-trip');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar viaje: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showFinishConfirmation(BuildContext outerContext, IncidentResponse incident) {
    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: _BillingFormBottomSheet(
          incidentId: incident.id,
          onSubmit: ({
            required double labor,
            required double parts,
            required String diagnosis,
            required String observations,
            required String paymentMethod,
          }) async {
            final total = labor + parts;
            final observationsWithPrefix = '[$paymentMethod] Diagnóstico: $diagnosis. Observaciones: $observations';
            
            try {
              await ref.read(emergencyRepositoryProvider).registerBilling(
                id: incident.id,
                total: total,
                labor: labor,
                parts: parts,
                observations: observationsWithPrefix,
              );
              
              if (!sheetContext.mounted) return;
              Navigator.pop(sheetContext); // Cerrar bottom sheet
              
              ScaffoldMessenger.of(outerContext).showSnackBar(
                const SnackBar(
                  content: Text('¡Servicio finalizado y cobro registrado con éxito!'),
                  backgroundColor: Colors.green,
                ),
              );

              // Preguntar si requiere atención posterior
              if (!outerContext.mounted) return;
              final requireFollowUp = await showDialog<bool>(
                context: outerContext,
                barrierDismissible: false,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('¿Atención Posterior?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: const Text(
                    '¿El vehículo requiere una revisión, mantenimiento o seguimiento posterior en taller?',
                    style: TextStyle(color: Colors.grey),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('NO, VOLVER A INICIO', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('SÍ, AGENDAR CITA', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (requireFollowUp == true) {
                if (!outerContext.mounted) return;
                outerContext.push(
                  '/technician/schedule-followup',
                  extra: {
                    'incidentId': incident.id,
                    'vehicleId': incident.vehicleId,
                    'sucursalId': incident.sucursalId ?? '',
                    'tecnicoId': incident.technicianId,
                  },
                );
              } else {
                if (!outerContext.mounted) return;
                await ref.read(emergencyNotifierProvider.notifier).refreshStatus();
                if (!outerContext.mounted) return;
                outerContext.go('/');
              }
            } catch (e) {
              if (!sheetContext.mounted) return;
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  content: Text('Error al registrar cobro: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              rethrow;
            }
          },
        ),
      ),
    );
  }
}

class _BillingFormBottomSheet extends StatefulWidget {
  final String incidentId;
  final Future<void> Function({
    required double labor,
    required double parts,
    required String diagnosis,
    required String observations,
    required String paymentMethod,
  }) onSubmit;

  const _BillingFormBottomSheet({
    required this.incidentId,
    required this.onSubmit,
  });

  @override
  State<_BillingFormBottomSheet> createState() => _BillingFormBottomSheetState();
}

class _BillingFormBottomSheetState extends State<_BillingFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _observationsController = TextEditingController();
  final _laborController = TextEditingController(text: '0.00');
  final _partsController = TextEditingController(text: '0.00');
  
  String _paymentMethod = 'STRIPE'; // Default
  bool _isLoading = false;

  @override
  void dispose() {
    _diagnosisController.dispose();
    _observationsController.dispose();
    _laborController.dispose();
    _partsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CIERRE DE SERVICIO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Diagnóstico
                const Text('Diagnóstico Técnico', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _diagnosisController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ej. Falla de batería, neumático pinchado...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'El diagnóstico es obligatorio' : null,
                ),
                const SizedBox(height: 16),

                // Observaciones
                const Text('Observaciones / Recomendaciones', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _observationsController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ej. Se recomienda cambio de llanta en taller...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // Costos
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mano de obra (\$)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _laborController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Requerido';
                              final parsed = double.tryParse(val);
                              if (parsed == null || parsed < 0) return 'Inválido';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Repuestos (\$)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _partsController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Requerido';
                              final parsed = double.tryParse(val);
                              if (parsed == null || parsed < 0) return 'Inválido';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Método de Pago
                const Text('Método de Pago Solicitado', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _paymentMethod = 'STRIPE'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _paymentMethod == 'STRIPE' ? const Color(0xFF3B82F6).withValues(alpha: 0.2) : const Color(0xFF0F172A),
                            border: Border.all(
                              color: _paymentMethod == 'STRIPE' ? const Color(0xFF3B82F6) : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.credit_card, color: _paymentMethod == 'STRIPE' ? const Color(0xFF3B82F6) : Colors.grey),
                              const SizedBox(height: 4),
                              Text('Tarjeta / Stripe', style: TextStyle(color: _paymentMethod == 'STRIPE' ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _paymentMethod = 'EFECTIVO'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _paymentMethod == 'EFECTIVO' ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFF0F172A),
                            border: Border.all(
                              color: _paymentMethod == 'EFECTIVO' ? const Color(0xFF10B981) : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.money, color: _paymentMethod == 'EFECTIVO' ? const Color(0xFF10B981) : Colors.grey),
                              const SizedBox(height: 4),
                              Text('Efectivo', style: TextStyle(color: _paymentMethod == 'EFECTIVO' ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Total y Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL A COBRAR', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _laborController,
                          builder: (context, laborVal, _) {
                            return ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _partsController,
                              builder: (context, partsVal, _) {
                                final labor = double.tryParse(laborVal.text) ?? 0.0;
                                final parts = double.tryParse(partsVal.text) ?? 0.0;
                                final total = labor + parts;
                                return Text(
                                  '\$${total.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(120, 50),
                          ),
                          child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Text('CONFIRMAR', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final labor = double.tryParse(_laborController.text) ?? 0.0;
    final parts = double.tryParse(_partsController.text) ?? 0.0;
    final total = labor + parts;

    if (labor < 0 || parts < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los costos no pueden ser negativos'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El total a cobrar debe ser mayor a 0'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await widget.onSubmit(
        labor: labor,
        parts: parts,
        diagnosis: _diagnosisController.text.trim(),
        observations: _observationsController.text.trim(),
        paymentMethod: _paymentMethod,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
