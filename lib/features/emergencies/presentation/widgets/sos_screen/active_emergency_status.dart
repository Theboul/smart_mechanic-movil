import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:smart_mechanic_app/core/utils/map_loader.dart' as map_loader;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_mechanic_app/core/services/socket_service.dart';
import 'package:smart_mechanic_app/core/local_storage/secure_storage_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../domain/incident.dart';
import '../../providers/emergency_provider.dart';
import '../../../data/emergency_repository.dart';
import '../../../../finance/data/finance_repository.dart';

class ActiveEmergencyStatus extends ConsumerStatefulWidget {
  final IncidentResponse incident;
  final VoidCallback onRefresh;
  final VoidCallback? onMinimize;

  const ActiveEmergencyStatus({
    super.key,
    required this.incident,
    required this.onRefresh,
    this.onMinimize,
  });

  @override
  ConsumerState<ActiveEmergencyStatus> createState() => _ActiveEmergencyStatusState();
}

class _ActiveEmergencyStatusState extends ConsumerState<ActiveEmergencyStatus> {
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  LatLng? _techLocation;
  int? _etaMinutes;
  GoogleMapController? _mapController;
  bool _hasTracking = false;

  List<LatLng> _polylinePoints = [];
  double? _distanceKm;
  String? _lastUpdatedTime;
  BitmapDescriptor? _clientIcon;
  BitmapDescriptor? _techIcon;
  final ScrollController _stepperScrollController = ScrollController();
  final DraggableScrollableController _draggableController = DraggableScrollableController();
  double _bottomSheetSize = 0.38;
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _checkAndConnectWebSocket();
    _loadInitialTracking();
    _draggableController.addListener(_onBottomSheetSizeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveStep();
    });
  }

  @override
  void didUpdateWidget(covariant ActiveEmergencyStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.incident.estado != oldWidget.incident.estado ||
        widget.incident.id != oldWidget.incident.id) {
      _checkAndConnectWebSocket();
      _loadInitialTracking();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveStep();
      });
    }
  }

  @override
  void dispose() {
    _closeWebSocket();
    _stepperScrollController.dispose();
    _draggableController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onBottomSheetSizeChanged() {
    if (mounted) {
      setState(() {
        _bottomSheetSize = _draggableController.size;
      });
    }
  }

  void _scrollToActiveStep() {
    if (!_stepperScrollController.hasClients) return;
    final step = _getStepProgressIndex();
    double offset = 0.0;
    if (step > 2) {
      offset = (step - 2) * 109.0;
    }
    final maxScroll = _stepperScrollController.position.maxScrollExtent;
    if (offset > maxScroll) {
      offset = maxScroll;
    }
    _stepperScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _closeWebSocket() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _wsSubscription = null;
    _wsChannel = null;
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double r = 6371; // Earth's radius in km
    final double dLat = _degToRad(p2.latitude - p1.latitude);
    final double dLng = _degToRad(p2.longitude - p1.longitude);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(p1.latitude)) *
            math.cos(_degToRad(p2.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _degToRad(double deg) {
    return deg * (math.pi / 180);
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final clientIcon = await _createMarkerIcon(Icons.person_pin_circle, Colors.pinkAccent, 75, 75);
      final techIcon = await _createMarkerIcon(Icons.local_shipping, Colors.blueAccent, 75, 75);
      if (mounted) {
        setState(() {
          _clientIcon = clientIcon;
          _techIcon = techIcon;
        });
      }
    } catch (e) {
      debugPrint('Error loading custom marker icons: $e');
    }
  }

  Future<BitmapDescriptor> _createMarkerIcon(IconData iconData, Color color, int width, int height) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    // Draw outer circle shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(width / 2, height / 2 + 3), width / 2 - 4, shadowPaint);

    // Draw circular background
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(Offset(width / 2, height / 2), width / 2 - 4, paint);
    
    // Draw border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(width / 2, height / 2), width / 2 - 4, borderPaint);

    // Draw Icon
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: width * 0.5,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        (height - textPainter.height) / 2,
      ),
    );

    final img = await pictureRecorder.endRecording().toImage(width, height);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  Future<void> _loadInitialTracking() async {
    final status = widget.incident.estado.toUpperCase();
    if (['EN_CAMINO', 'TECNICO_EN_SITIO'].contains(status)) {
      try {
        final repo = ref.read(emergencyRepositoryProvider);
        final trackingData = await repo.getLatestTracking(widget.incident.id);
        if (trackingData != null && mounted) {
          final lat = trackingData['latitud'];
          final lng = trackingData['longitud'];
          final eta = trackingData['eta_minutos'] as int?;
          final polyline = trackingData['polyline_ruta'] as String?;
          final timestamp = trackingData['timestamp'] as String?;
          final hasTracking = trackingData['has_tracking'] as bool? ?? (lat != null && lng != null);
          
          final isRecent = timestamp != null && (() {
            try {
              final parsed = DateTime.parse(timestamp).toUtc();
              final now = DateTime.now().toUtc();
              return now.difference(parsed).inMinutes.abs() < 60;
            } catch (_) {
              return false;
            }
          })();

          setState(() {
            if (status == 'EN_CAMINO') {
              _hasTracking = hasTracking;
              if (lat != null && lng != null) {
                _techLocation = LatLng((lat as num).toDouble(), (lng as num).toDouble());
              } else {
                _techLocation = null;
              }
              _etaMinutes = eta;
              if (polyline != null && hasTracking) {
                _polylinePoints = _decodePolyline(polyline);
              } else {
                _polylinePoints = [];
              }
              if (_techLocation != null) {
                final clientLatLng = LatLng(
                  widget.incident.latitud ?? -17.7833,
                  widget.incident.longitud ?? -63.1821,
                );
                _distanceKm = _calculateDistance(clientLatLng, _techLocation!);
              } else {
                _distanceKm = null;
              }
            } else {
              // TECNICO_EN_SITIO
              _hasTracking = hasTracking && isRecent;
              if (isRecent && lat != null && lng != null) {
                _techLocation = LatLng((lat as num).toDouble(), (lng as num).toDouble());
              } else {
                _techLocation = null;
              }
              _etaMinutes = null;
              _polylinePoints = [];
              _distanceKm = null;
            }
            if (timestamp != null) {
              try {
                final dt = DateTime.parse(timestamp).toLocal();
                _lastUpdatedTime = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
              } catch (_) {
                _lastUpdatedTime = null;
              }
            } else {
              _lastUpdatedTime = null;
            }
          });
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _animateMapToTech();
          });
        } else if (mounted) {
          setState(() {
            _techLocation = null;
            _etaMinutes = null;
            _polylinePoints = [];
            _distanceKm = null;
            _lastUpdatedTime = null;
            _hasTracking = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading initial tracking: $e');
      }
    } else {
      if (mounted) {
        setState(() {
          _techLocation = null;
          _etaMinutes = null;
          _polylinePoints = [];
          _distanceKm = null;
          _lastUpdatedTime = null;
          _hasTracking = false;
        });
      }
    }
  }

  Future<void> _checkAndConnectWebSocket() async {
    final status = widget.incident.estado.toUpperCase();
    if (status == 'EN_CAMINO') {
      if (_wsChannel != null) return; // Ya conectado
      
      try {
        final storage = ref.read(secureStorageProvider);
        final token = await storage.read(key: 'jwt_token');
        if (token == null) return;

        _wsChannel = ref.read(socketServiceProvider).connectToIncident(
          widget.incident.id,
          token,
        );

        _wsSubscription = _wsChannel!.stream.listen(
          (data) {
            try {
              final Map<String, dynamic> event = jsonDecode(data);
              debugPrint('🔔 Client tracking WebSocket event: $event');
              if (event['type'] == 'TRACKING_UPDATE') {
                final tracking = event['data'];
                final lat = tracking['latitud'] != null ? (tracking['latitud'] as num).toDouble() : null;
                final lng = tracking['longitud'] != null ? (tracking['longitud'] as num).toDouble() : null;
                final eta = tracking['eta_minutos'] as int?;
                final polyline = tracking['polyline_ruta'] as String?;
                final timestamp = tracking['timestamp'] as String?;
                final hasTracking = tracking['has_tracking'] as bool? ?? (lat != null && lng != null);
                
                if (mounted && widget.incident.estado.toUpperCase() == 'EN_CAMINO') {
                  setState(() {
                    _hasTracking = hasTracking;
                    if (lat != null && lng != null) {
                      _techLocation = LatLng(lat, lng);
                    } else {
                      _techLocation = null;
                    }
                    _etaMinutes = eta;
                    if (polyline != null && hasTracking) {
                      _polylinePoints = _decodePolyline(polyline);
                    } else {
                      _polylinePoints = [];
                    }
                    if (_techLocation != null) {
                      final clientLatLng = LatLng(
                        widget.incident.latitud ?? -17.7833,
                        widget.incident.longitud ?? -63.1821,
                      );
                      _distanceKm = _calculateDistance(clientLatLng, _techLocation!);
                    } else {
                      _distanceKm = null;
                    }
                    if (timestamp != null) {
                      try {
                        final dt = DateTime.parse(timestamp).toLocal();
                        _lastUpdatedTime = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                      } catch (_) {
                        final now = DateTime.now();
                        _lastUpdatedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                      }
                    } else {
                      final now = DateTime.now();
                      _lastUpdatedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                    }
                  });
                  _animateMapToTech();
                }
              } else if (event['type'] == 'STATUS_UPDATED' || event['type'] == 'STATUS_UPDATE') {
                debugPrint('🚨 Client active emergency state updated via WS');
                widget.onRefresh();
              }
            } catch (e) {
              debugPrint('❌ Error parsing WebSocket tracking: $e');
            }
          },
          onError: (err) {
            debugPrint('❌ Error in tracking WebSocket: $err');
            _closeWebSocket();
          },
          onDone: () {
            debugPrint('🔌 Tracking WebSocket closed');
            _closeWebSocket();
          },
        );
      } catch (e) {
        debugPrint('❌ Error connecting tracking WebSocket: $e');
      }
    } else {
      _closeWebSocket();
      if (mounted) {
        setState(() {
          _techLocation = null;
          _etaMinutes = null;
          _polylinePoints = [];
          _distanceKm = null;
          _lastUpdatedTime = null;
          _hasTracking = false;
        });
      }
    }
  }

  void _animateMapToTech() {
    if (_mapController == null) return;
    
    final clientLatLng = LatLng(
      widget.incident.latitud ?? -17.7833,
      widget.incident.longitud ?? -63.1821,
    );
    
    final status = widget.incident.estado.toUpperCase();
    if (status != 'EN_CAMINO') {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(clientLatLng, 16.0));
      return;
    }
    
    if (!_hasTracking || _techLocation == null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(clientLatLng, 15));
      return;
    }
    
    final dist = _calculateDistance(clientLatLng, _techLocation!);
    
    if (dist < 0.05) {
      final midLat = (clientLatLng.latitude + _techLocation!.latitude) / 2;
      final midLng = (clientLatLng.longitude + _techLocation!.longitude) / 2;
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(midLat, midLng), 16.5));
    } else {
      final southwest = LatLng(
        math.min(clientLatLng.latitude, _techLocation!.latitude),
        math.min(clientLatLng.longitude, _techLocation!.longitude),
      );
      final northeast = LatLng(
        math.max(clientLatLng.latitude, _techLocation!.latitude),
        math.max(clientLatLng.longitude, _techLocation!.longitude),
      );
      final bounds = LatLngBounds(southwest: southwest, northeast: northeast);
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }
  }

  String _getTechStatusLabel() {
    final status = widget.incident.estado.toUpperCase();
    if (status == 'EN_ATENCION' || status == 'EN_PROGRESO') {
      return 'En atención';
    }
    if (_distanceKm != null && _distanceKm! < 0.05) {
      return 'Llegó al sitio';
    }
    return 'En camino';
  }

  Widget _buildTrackingStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF3B82F6), size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final onRefresh = widget.onRefresh;

    final clientLatLng = LatLng(
      incident.latitud ?? -17.7833,
      incident.longitud ?? -63.1821,
    );

    final displayDistance = _distanceKm == null
        ? 'Calculando...'
        : (_distanceKm! < 1.0
            ? '${(_distanceKm! * 1000).round()} m'
            : '${_distanceKm!.toStringAsFixed(1)} km');

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('client_marker'),
        position: clientLatLng,
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
        anchor: const Offset(0.5, 0.5),
        icon: _clientIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    if (_hasTracking && _techLocation != null) {
      LatLng techMarkerPos = _techLocation!;
      if (_calculateDistance(clientLatLng, techMarkerPos) < 0.015) {
        techMarkerPos = LatLng(
          techMarkerPos.latitude + 0.00012,
          techMarkerPos.longitude + 0.00012,
        );
      }
      markers.add(
        Marker(
          markerId: const MarkerId('tech_marker'),
          position: techMarkerPos,
          infoWindow: const InfoWindow(title: 'Técnico en camino'),
          anchor: const Offset(0.5, 0.5),
          icon: _techIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: Stack(
        children: [
          // 1. Google Map as Background
          (kIsWeb && !map_loader.isGoogleMapsInitialized())
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
                    target: clientLatLng,
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _animateMapToTech();
                  },
                  markers: markers,
                  polylines: {
                    if (_hasTracking && _polylinePoints.isNotEmpty)
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: _polylinePoints,
                        color: const Color(0xFF3B82F6),
                        width: 5,
                        startCap: Cap.roundCap,
                        endCap: Cap.roundCap,
                      ),
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),

          // 2. Custom App Bar Floating on top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 50, bottom: 10, left: 8, right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        final status = widget.incident.estado.toUpperCase();
                        if (status == 'CANCELADO' || status == 'COMPLETADO') {
                          ref.read(emergencyNotifierProvider.notifier).refreshStatus();
                        }
                        if (widget.onMinimize != null) {
                          widget.onMinimize!();
                        } else {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            context.go('/');
                          }
                        }
                      },
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Tracking de emergencia',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none, color: Colors.white),
                        onPressed: () {},
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Status Badge Floating below App Bar
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF131824).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_car_filled, color: Color(0xFFEF4444), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergencia #${incident.id.length > 8 ? incident.id.substring(0, 8).toUpperCase() : incident.id.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          incident.vehicleBrand != null 
                              ? '${incident.vehicleBrand} ${incident.vehicleModel ?? ""}' 
                              : 'Auxilio Vial • ${incident.prioridad}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusTitle(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3.5 Floating AI Action Button (Anclado al borde superior derecho del panel inferior, se desvanece al expandir)
          Positioned(
            bottom: MediaQuery.of(context).size.height * _bottomSheetSize + 12,
            right: 28,
            child: IgnorePointer(
              ignoring: _bottomSheetSize > 0.45,
              child: AnimatedOpacity(
                opacity: _bottomSheetSize > 0.45 ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: FloatingActionButton(
                    heroTag: 'client_ai_fab',
                    onPressed: () => context.push('/ai-analysis'),
                    backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.95),
                    foregroundColor: const Color(0xFF3B82F6),
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.auto_awesome_rounded, size: 22),
                  ),
                ),
              ),
            ),
          ),

          // 4. Scrollable Bottom Panel Card
          Align(
            alignment: Alignment.bottomCenter,
            child: DraggableScrollableSheet(
              controller: _draggableController,
              initialChildSize: 0.38,
              minChildSize: 0.15,
              maxChildSize: 0.85,
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131824).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Live status header
                          if (incident.estado.toUpperCase() == 'EN_CAMINO' || incident.estado.toUpperCase() == 'ACEPTADO') ...[
                            if (!_hasTracking)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Esperando ubicación del técnico...',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.greenAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Seguimiento en tiempo real',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_lastUpdatedTime != null)
                                      Text(
                                        'Act: $_lastUpdatedTime',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildTrackingStat(
                                      icon: Icons.timer_outlined,
                                      label: 'ETA Estimado',
                                      value: _etaMinutes != null ? '$_etaMinutes min' : 'Calculando...',
                                    ),
                                    _buildTrackingStat(
                                      icon: Icons.directions_run_outlined,
                                      label: 'Distancia',
                                      value: displayDistance,
                                    ),
                                    _buildTrackingStat(
                                      icon: Icons.update_outlined,
                                      label: 'Estado',
                                      value: _getTechStatusLabel(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ] else ...[
                            // Para otros estados, mostrar un banner o status estático
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _getStatusMessage(incident.estado),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Panel de Verificación si el técnico está en sitio
                          if (incident.estado.toUpperCase() == 'TECNICO_EN_SITIO') ...[
                            _buildVerificationPanel(context, incident),
                            const SizedBox(height: 16),
                          ],

                          // Card: Tu Ubicación
                          _buildCard(
                            icon: Icons.my_location,
                            iconColor: const Color(0xFF3B82F6),
                            title: 'Tu ubicación',
                            subtitle: incident.descripcion ?? 'Incidente reportado en el mapa',
                          ),
                          const SizedBox(height: 12),

                          // Card: Técnico Asignado (si aplica)
                          if (incident.technicianName != null) ...[
                            _buildTechCard(incident),
                            const SizedBox(height: 12),
                          ],

                          // Solicitud Info Row
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hora de solicitud',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getFormattedReportTime(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Estado actual',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getStatusTitle(),
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          color: Color(0xFF3B82F6),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Diagnóstico IA (si está disponible)
                          if (incident.resumenIa != null && incident.resumenIa!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildAiAnalysis(),
                          ],
                          const SizedBox(height: 20),

                          // Progreso del servicio Stepper
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Progreso del servicio',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_getStepProgressIndex()}/6',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildVisualStepper(),
                          const SizedBox(height: 20),

                          // Bottom banner text
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.blueAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getBottomInfoText(incident.estado),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Resumen de Cobro y Pago (NUEVO)
                          if (incident.estado.toUpperCase() == 'FINALIZADO') ...[
                            if (incident.montoTotal != null) ...[
                              Builder(
                                builder: (context) {
                                  final obs = incident.observaciones ?? '';
                                  final isEfectivo = obs.startsWith('[EFECTIVO]');
                                  
                                  // Limpiar el prefijo de la observación para mostrarla al cliente
                                  final cleanObs = obs
                                      .replaceFirst('[EFECTIVO]', '')
                                      .replaceFirst('[STRIPE]', '')
                                      .trim();

                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isEfectivo 
                                            ? const Color(0xFF10B981).withValues(alpha: 0.3) 
                                            : const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'RESUMEN DE SERVICIO',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.6),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.1,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isEfectivo 
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.1) 
                                                    : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                isEfectivo ? 'EFECTIVO' : 'TARJETA',
                                                style: TextStyle(
                                                  color: isEfectivo ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        if (cleanObs.isNotEmpty) ...[
                                          Text(
                                            cleanObs,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const Divider(color: Colors.white10),
                                          const SizedBox(height: 16),
                                        ],
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Mano de Obra', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                            Text('\$${(incident.manoDeObra ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Repuestos / Materiales', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                            Text('\$${(incident.repuestos ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(color: Colors.white10),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('TOTAL A PAGAR', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                            Text(
                                              '\$${incident.montoTotal!.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: isEfectivo ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (isEfectivo) ...[
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.info_outline, color: Color(0xFF10B981), size: 18),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Pago en efectivo registrado por el técnico. Por favor, entrega el dinero en sitio.',
                                                    style: TextStyle(
                                                      color: Colors.green.shade200,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }
                              ),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final obs = incident.observaciones ?? '';
                                  final isEfectivo = obs.startsWith('[EFECTIVO]');
                                  
                                  if (isEfectivo) {
                                    return ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          // Notificar al backend de que se completó el pago simulado (efectivo) exitosamente
                                          await ref.read(financeRepositoryProvider).confirmMockPayment(incident.id);
                                        } catch (e) {
                                          debugPrint('Error al confirmar pago mock: $e');
                                        }
                                        // Finalizar localmente y volver a Home
                                        await ref.read(emergencyNotifierProvider.notifier).completeIncidentLocally(incident.id);
                                      },
                                      icon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.black),
                                      label: const Text(
                                        'ENTENDIDO (FINALIZAR)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        minimumSize: const Size(double.infinity, 52),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return ElevatedButton.icon(
                                      onPressed: () {
                                        context.push('/payment', extra: {'incidentId': incident.id});
                                      },
                                      icon: const Icon(Icons.payment, size: 20, color: Colors.white),
                                      label: Text(
                                        'PAGAR SERVICIO (\$${incident.montoTotal!.toStringAsFixed(2)} USD)',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3B82F6), // Blue premium for Stripe
                                        minimumSize: const Size(double.infinity, 52),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 3,
                                      ),
                                    );
                                  }
                                }
                              ),
                            ] else
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'El taller está preparando tu resumen de cobro...',
                                        style: TextStyle(
                                          color: Colors.amber.shade200,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                          ],

                          // Cancelar / Reintentar Buttons
                          Column(
                            children: [
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: onRefresh,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text(
                                  'ACTUALIZAR ESTADO',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF3B82F6),
                                  side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              if (_isCancelable(incident.estado)) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => _showCancelDialog(context),
                                  icon: const Icon(Icons.cancel_outlined, size: 16),
                                  label: const Text(
                                    'CANCELAR SOLICITUD',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent.withValues(alpha: 0.8),
                                    minimumSize: const Size(double.infinity, 36),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24), // Extra bottom padding for Safe Area
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechCard(IncidentResponse incident) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping, color: Color(0xFF3B82F6), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Técnico asignado',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  incident.technicianName ?? 'Carlos Méndez',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '4.8',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (incident.technicianPhone != null) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.phone, color: Colors.greenAccent, size: 18),
                onPressed: () {
                  launchUrl(Uri.parse('tel:${incident.technicianPhone}'));
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent, size: 18),
                onPressed: () {
                  launchUrl(Uri.parse('sms:${incident.technicianPhone}'));
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getFormattedReportTime() {
    if (widget.incident.fecha == null) return '--:--';
    try {
      final dt = DateTime.parse(widget.incident.fecha!).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return '--:--';
    }
  }

  int _getStepProgressIndex() {
    final status = widget.incident.estado.toUpperCase();
    final hasTech = widget.incident.technicianId != null;

    if (status == 'PENDIENTE' || status == 'REPORTADO') {
      return 1;
    } else if (status == 'BUSCANDO_TALLER') {
      return 2;
    } else if (status == 'TALLER_ASIGNADO' || status == 'ANALIZADO') {
      return hasTech ? 3 : 2;
    } else if (status == 'ACEPTADO' || status == 'EN_CAMINO' || status == 'TECNICO_EN_SITIO' || status == 'TECNICO_RECHAZADO') {
      return 4;
    } else if (status == 'EN_ATENCION' || status == 'EN_PROGRESO') {
      return 5;
    } else if (status == 'FINALIZADO' || status == 'COMPLETADO') {
      return 6;
    }
    return 1;
  }

  bool _isCancelable(String state) {
    final status = state.toUpperCase();
    return ['PENDIENTE', 'REPORTADO', 'BUSCANDO_TALLER', 'TALLER_ASIGNADO', 'ANALIZADO', 'ACEPTADO', 'EN_CAMINO'].contains(status);
  }

  Widget _buildVisualStepper() {
    final currentStep = _getStepProgressIndex();
    
    final t1 = _getStateTime('REGISTRADA', '--:--');
    final t2 = _getStateTime('BUSCANDO', '--:--');
    final t3 = _getStateTime('ASIGNADO', '--:--');
    final t4 = _getStateTime('CAMINO', '--:--');
    final t5 = _getStateTime('ATENCION', '--:--');
    final t6 = _getStateTime('FINALIZADO', '--:--');

    return SingleChildScrollView(
      controller: _stepperScrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepperStep(1, 'Registrada', t1, currentStep >= 1),
            _buildStepperLine(currentStep >= 2),
            _buildStepperStep(2, 'Buscando taller', t2, currentStep >= 2),
            _buildStepperLine(currentStep >= 3),
            _buildStepperStep(3, 'Taller asignado', t3, currentStep >= 3),
            _buildStepperLine(currentStep >= 4),
            _buildStepperStep(4, 'En camino', t4, currentStep >= 4),
            _buildStepperLine(currentStep >= 5),
            _buildStepperStep(5, 'En atención', t5, currentStep >= 5),
            _buildStepperLine(currentStep >= 6),
            _buildStepperStep(6, 'Finalizado', t6, currentStep >= 6),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperStep(int step, String label, String time, bool completed) {
    final isCurrent = _getStepProgressIndex() == step;
    
    return SizedBox(
      width: 85,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: completed ? const Color(0xFF3B82F6) : const Color(0xFF1F2937),
              shape: BoxShape.circle,
              border: isCurrent 
                  ? Border.all(color: Colors.white, width: 2)
                  : (completed ? null : Border.all(color: Colors.white24)),
              boxShadow: isCurrent ? [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ] : null,
            ),
            child: Center(
              child: completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        color: completed ? Colors.white70 : Colors.white24,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: completed ? Colors.white : Colors.white38,
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              color: completed ? Colors.white54 : Colors.white24,
              fontSize: 10,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperLine(bool completed) {
    return Padding(
      padding: const EdgeInsets.only(top: 14.5),
      child: Container(
        width: 24,
        height: 3,
        color: completed ? const Color(0xFF3B82F6) : const Color(0xFF1F2937),
      ),
    );
  }

  String _getStateTime(String targetState, String defaultTime) {
    if (widget.incident.historial == null) {
      if (targetState == 'REGISTRADA' && widget.incident.fecha != null) {
        try {
          final dt = DateTime.parse(widget.incident.fecha!).toLocal();
          return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        } catch (_) {}
      }
      return defaultTime;
    }
    for (var item in widget.incident.historial!) {
      if (item is Map<String, dynamic>) {
        final state = item['incidente_estado_nuevo'] as String?;
        final fechaStr = item['fecha'] as String?;
        if (state != null && fechaStr != null) {
          bool matches = false;
          if (targetState == 'REGISTRADA' && (state == 'PENDIENTE' || state == 'REPORTADO')) {
            matches = true;
          } else if (targetState == 'BUSCANDO' && state == 'BUSCANDO_TALLER') {
            matches = true;
          } else if (targetState == 'ASIGNADO' && state == 'TALLER_ASIGNADO') {
            matches = true;
          } else if (targetState == 'CAMINO' && (state == 'EN_CAMINO' || state == 'TECNICO_EN_SITIO' || state == 'TECNICO_RECHAZADO')) {
            matches = true;
          } else if (targetState == 'ATENCION' && (state == 'EN_ATENCION' || state == 'EN_PROGRESO')) {
            matches = true;
          } else if (targetState == 'FINALIZADO' && (state == 'FINALIZADO' || state == 'COMPLETADO')) {
            matches = true;
          }
          
          if (matches) {
            try {
              final dt = DateTime.parse(fechaStr).toLocal();
              return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
            } catch (_) {}
          }
        }
      }
    }
    
    if (targetState == 'REGISTRADA' && widget.incident.fecha != null) {
      try {
        final dt = DateTime.parse(widget.incident.fecha!).toLocal();
        return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      } catch (_) {}
    }
    
    return '--:--';
  }

  Widget _buildAiAnalysis() {
    final hasHighGravity = widget.incident.analisisConsolidado?.toUpperCase().contains('ALTA') ?? false;
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
              if (hasHighGravity) ...[
                const SizedBox(width: 12),
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
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.incident.resumenIa ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (widget.incident.analisisConsolidado != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white10, height: 1),
            ),
            Text(
              widget.incident.analisisConsolidado!,
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

  void _showCancelDialog(BuildContext context) {
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
              ref.read(emergencyNotifierProvider.notifier).cancelSOS(widget.incident.id);
              Navigator.pop(context);
            },
            child: const Text('SÍ, CANCELAR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  String _getStatusTitle() {
    switch (widget.incident.estado.toUpperCase()) {
      case 'PENDIENTE':
      case 'REPORTADO':
      case 'BUSCANDO_TALLER':
        return 'Buscando taller';
      case 'SIN_TALLER_DISPONIBLE':
        return 'Sin taller disponible';
      case 'ANALIZADO':
      case 'TALLER_ASIGNADO':
        return 'Taller Notificado';
      case 'ACEPTADO':
      case 'EN_CAMINO':
        return 'Mecánico en Camino';
      case 'EN_PROGRESO':
      case 'EN_ATENCION':
        return 'En Reparación';
      case 'FINALIZADO':
        return 'Atención Finalizada (Esperando Pago)';
      case 'COMPLETADO':
        return 'Servicio Completado';
      case 'TECNICO_EN_SITIO':
        return 'Mecánico en Sitio';
      case 'TECNICO_RECHAZADO':
        return 'Mecánico Rechazado';
      default:
        return 'Procesando...';
    }
  }

  String _getStatusMessage(String estado) {
    switch (estado.toUpperCase()) {
      case 'PENDIENTE':
      case 'REPORTADO':
      case 'BUSCANDO_TALLER':
        return 'Buscando el taller más cercano para tu atención...';
      case 'TALLER_ASIGNADO':
      case 'ANALIZADO':
        return 'Taller asignado. Esperando que el taller confirme al técnico.';
      case 'TECNICO_EN_SITIO':
        return 'El técnico ya está en el sitio. Por favor verifica su identidad.';
      case 'EN_ATENCION':
      case 'EN_PROGRESO':
        return 'El técnico está atendiendo tu vehículo en este momento.';
      case 'FINALIZADO':
        return widget.incident.montoTotal == null
            ? 'Atención finalizada. El taller está preparando el resumen de cobro.'
            : 'Resumen de cobro disponible. Por favor, procede al pago.';
      case 'COMPLETADO':
        return 'Servicio completado con éxito. ¡Gracias por tu preferencia!';
      case 'CANCELADO':
        return 'La emergencia ha sido cancelada.';
      case 'TECNICO_RECHAZADO':
        return 'Has rechazado la verificación del técnico. Esperando reasignación.';
      default:
        return 'Procesando tu solicitud de emergencia...';
    }
  }

  String _getBottomInfoText(String estado) {
    switch (estado.toUpperCase()) {
      case 'PENDIENTE':
      case 'REPORTADO':
      case 'BUSCANDO_TALLER':
        return 'Buscando el mejor taller disponible para asistirte.';
      case 'TALLER_ASIGNADO':
      case 'ANALIZADO':
        return 'Se ha notificado al taller. Pronto se asignará un técnico.';
      case 'EN_CAMINO':
      case 'ACEPTADO':
        return 'Te notificaremos cuando el técnico llegue al lugar del incidente.';
      case 'TECNICO_EN_SITIO':
        return 'Ingresa el PIN de 6 dígitos que te proporcione el técnico para iniciar la reparación.';
      case 'EN_ATENCION':
      case 'EN_PROGRESO':
        return 'El técnico se encuentra realizando la reparación de tu vehículo.';
      case 'FINALIZADO':
        return 'Por seguridad, revisa los detalles del cobro y realiza el pago digital.';
      case 'COMPLETADO':
        return 'Muchas gracias por confiar en Smart Mechanic.';
      default:
        return 'Mantente al tanto de las notificaciones de tu servicio.';
    }
  }

  Widget _buildVerificationPanel(BuildContext context, IncidentResponse incident) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.05),
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
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'VERIFICACIÓN SEGURA DE IDENTIDAD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '⚠️ MENSAJE DE SEGURIDAD',
            style: TextStyle(
              color: Colors.orangeAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Por tu seguridad, antes de permitir que el técnico inicie el servicio, compara los datos que se muestran a continuación con la persona en sitio:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          
          // Technician Data
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  child: const Icon(Icons.engineering_rounded, color: Color(0xFF3B82F6), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.technicianName ?? 'Técnico Asignado',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        incident.workshopName ?? 'Taller Asignado',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      if (incident.branchName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Sucursal: ${incident.branchName}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 12),
                      SizedBox(width: 4),
                      Text(
                        '4.8',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // PIN Input & QR Scan buttons
          const Text(
            'INGRESAR PIN DE VERIFICACIÓN (6 DÍGITOS)',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Ej. 123456',
                      hintStyle: TextStyle(color: Colors.white24, letterSpacing: 0.0),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.02),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final pin = _pinController.text.trim();
                  if (pin.length == 6) {
                    _validateCode(pin);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa un PIN de 6 dígitos')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('VERIFICAR', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // QR Scan Button
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => const QrScannerScreen(),
                ),
              );
              if (result != null && mounted) {
                String pin = result.trim();
                if (pin.startsWith('smartmechanic://verify-technician')) {
                  try {
                    final uri = Uri.parse(pin);
                    final code = uri.queryParameters['code'];
                    if (code != null) {
                      pin = code;
                    }
                  } catch (_) {}
                }
                _pinController.text = pin;
                _validateCode(pin);
              }
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('ESCANEAR CÓDIGO QR', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          
          // Report Mismatch button
          Center(
            child: TextButton.icon(
              onPressed: () => _showMismatchDialog(context),
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
              label: const Text(
                'EL TÉCNICO NO COINCIDE',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMismatchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Reportar que no coincide?', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que la persona en sitio no coincide con el técnico asignado? Se registrará un rechazo y el taller/administrador será notificado para reasignar la emergencia.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectTechnician();
            },
            child: const Text('REPORTAR RECHAZO', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _validateCode(String code) async {
    try {
      await ref.read(emergencyNotifierProvider.notifier).validateVerificationCode(widget.incident.id, code);
      if (mounted) {
        _pinController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Técnico verificado con éxito. Iniciando servicio.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _rejectTechnician() async {
    try {
      await ref.read(emergencyNotifierProvider.notifier).rejectTechnicianVerification(widget.incident.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se ha reportado que el técnico no coincide. El incidente queda pendiente de intervención.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reportar: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('ESCANEAR QR DEL TÉCNICO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_scanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null) {
                  setState(() {
                    _scanned = true;
                  });
                  Navigator.pop(context, rawValue);
                  break;
                }
              }
            },
          ),
          // Custom scanner overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 3),
                borderRadius: BorderRadius.circular(20),
                color: Colors.transparent,
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Text(
              'Apunta la cámara al código QR en la app del técnico',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        ],
      ),
    );
  }
}
