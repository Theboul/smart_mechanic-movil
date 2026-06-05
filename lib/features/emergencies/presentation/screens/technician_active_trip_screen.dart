import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/tracking_service.dart';
import '../providers/emergency_provider.dart';
import '../../domain/incident.dart';

class TechnicianActiveTripScreen extends ConsumerStatefulWidget {
  const TechnicianActiveTripScreen({super.key});

  @override
  ConsumerState<TechnicianActiveTripScreen> createState() => _TechnicianActiveTripScreenState();
}

class _TechnicianActiveTripScreenState extends ConsumerState<TechnicianActiveTripScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStreamSub;
  LatLng? _techLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final incident = ref.read(emergencyNotifierProvider).value;
      if (incident != null) {
        // 1. Iniciar el servicio de envío de tracking GPS al backend
        ref.read(trackingServiceProvider).startTracking(incident.id);
        
        // 2. Suscribirse a la ubicación local del dispositivo para actualizar el mapa en vivo
        _startLocalPositionStream();
      }
    });
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    // Detener tracking al salir de la pantalla
    ref.read(trackingServiceProvider).stopTracking();
    super.dispose();
  }

  Future<void> _startLocalPositionStream() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualizar cada 10 metros
    );
    
    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (mounted) {
        setState(() {
          _techLocation = LatLng(position.latitude, position.longitude);
        });
        
        // Mover cámara para encuadrar al técnico y al cliente
        _fitMapBounds();
      }
    });
  }

  void _fitMapBounds() {
    if (_mapController == null || _techLocation == null) return;
    
    final incident = ref.read(emergencyNotifierProvider).value;
    if (incident == null) return;
    
    final clientLatLng = LatLng(incident.latitud ?? -17.7833, incident.longitud ?? -63.1821);
    
    final bounds = LatLngBounds(
      southwest: LatLng(
        _techLocation!.latitude < clientLatLng.latitude ? _techLocation!.latitude : clientLatLng.latitude,
        _techLocation!.longitude < clientLatLng.longitude ? _techLocation!.longitude : clientLatLng.longitude,
      ),
      northeast: LatLng(
        _techLocation!.latitude > clientLatLng.latitude ? _techLocation!.latitude : clientLatLng.latitude,
        _techLocation!.longitude > clientLatLng.longitude ? _techLocation!.longitude : clientLatLng.longitude,
      ),
    );
    
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(emergencyNotifierProvider);

    // Escuchar cambios de estado para salir de la pantalla si se verifica o cancela
    ref.listen<AsyncValue<IncidentResponse?>>(emergencyNotifierProvider, (previous, next) {
      next.whenOrNull(
        data: (incident) {
          if (incident == null) {
            context.go('/');
          } else {
            final status = incident.estado.toUpperCase();
            if (status == 'EN_ATENCION' || status == 'EN_PROGRESO') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Verificación exitosa! Iniciando atención en sitio.'),
                  backgroundColor: Colors.green,
                ),
              );
              context.go('/');
            }
          }
        },
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: emergencyState.when(
        data: (incident) {
          if (incident == null) {
            return const Center(child: Text('No hay viaje activo', style: TextStyle(color: Colors.white)));
          }

          if (incident.estado.toUpperCase() == 'TECNICO_EN_SITIO') {
            return _buildVerificationPendingView(incident);
          }

          final clientLatLng = LatLng(incident.latitud ?? -17.7833, incident.longitud ?? -63.1821);
          final markers = <Marker>{
            Marker(
              markerId: const MarkerId('client_spot'),
              position: clientLatLng,
              infoWindow: const InfoWindow(title: 'Cliente Averiado'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          };

          if (_techLocation != null) {
            LatLng techMarkerPos = _techLocation!;
            if ((techMarkerPos.latitude - clientLatLng.latitude).abs() < 0.00015 &&
                (techMarkerPos.longitude - clientLatLng.longitude).abs() < 0.00015) {
              techMarkerPos = LatLng(
                techMarkerPos.latitude + 0.00015,
                techMarkerPos.longitude + 0.00015,
              );
            }
            markers.add(
              Marker(
                markerId: const MarkerId('tech_spot'),
                position: techMarkerPos,
                infoWindow: const InfoWindow(title: 'Mi Ubicación'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
            );
          }

          return Stack(
            children: [
              // 1. Mapa de Google
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: clientLatLng,
                  zoom: 14,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _fitMapBounds();
                },
                markers: markers,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
              ),

              // Botón Superior para volver al Dashboard
              Positioned(
                top: 50,
                left: 16,
                child: SafeArea(
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF1E293B),
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
              ),

              // 2. Tarjeta de información del viaje en tiempo real (Uber Style)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tiempo estimado de arribo (ETA)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EN RUTA DE AUXILIO',
                                style: TextStyle(
                                  color: Colors.blueAccent.shade100,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Navegando al cliente...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.timer_outlined, color: Color(0xFF3B82F6), size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'ETA ~20 min', // ETA simulado por GPS o recuperado en websocket
                                  style: TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 14),

                      // Datos rápidos de vehículo del cliente
                      Row(
                        children: [
                          Icon(Icons.directions_car_filled_rounded, color: Colors.grey.shade400, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${incident.vehicleBrand ?? "Vehículo"} ${incident.vehicleModel ?? ""}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Placa: ${incident.vehiclePlate ?? "N/A"} • Color: ${incident.vehicleColor ?? "N/A"}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Botón premium: LLEGUE AL SITIO
                      ElevatedButton(
                        onPressed: () => _arrivedAtSite(context, incident.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981), // Color esmeralda premium
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 58),
                          shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.black),
                            SizedBox(width: 8),
                            Text('LLEGUÉ AL SITIO'),
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

  Future<void> _arrivedAtSite(BuildContext context, String incidentId) async {
    try {
      // 1. Cambiar estado a TECNICO_EN_SITIO
      await ref.read(emergencyNotifierProvider.notifier).updateStatus(incidentId, 'TECNICO_EN_SITIO');
      
      // 2. Apagar el tracking GPS local
      ref.read(trackingServiceProvider).stopTracking();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Has llegado al sitio. Por favor, presenta el código PIN o QR al cliente.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar llegada: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Widget _buildVerificationPendingView(IncidentResponse incident) {
    // Generar el deep link seguro para la cámara QR del cliente
    final qrData = 'smartmechanic://verify-technician?incident_id=${incident.id}&code=${incident.verificationCode ?? ""}';
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'VERIFICACIÓN DE IDENTIDAD',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.blueAccent,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Llegaste al Sitio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Muestra el código o QR al cliente para iniciar la atención de forma segura.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 200.0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'CÓDIGO PIN MANUAL',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatPin(incident.verificationCode ?? '------'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Esperando confirmación del cliente...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPin(String pin) {
    if (pin.length != 6) return pin;
    return '${pin.substring(0, 3)} ${pin.substring(3)}';
  }
}
