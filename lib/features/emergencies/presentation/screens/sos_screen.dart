import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';

import '../providers/emergency_provider.dart';
import '../../domain/incident.dart';
import '../../../identity/presentation/providers/auth_provider.dart';
import '../widgets/sos_screen/sos_header.dart';
import '../widgets/sos_screen/active_vehicle_card.dart';
import '../widgets/sos_screen/emergency_button.dart';
import '../widgets/sos_screen/sos_bottom_nav.dart';
import '../widgets/sos_screen/sos_visual_elements.dart';
import '../widgets/sos_screen/active_emergency_status.dart';
import '../../../garage/presentation/providers/vehicle_provider.dart';
import '../../../ai_assistant/presentation/providers/evidence_provider.dart';

import '../../../scheduling/presentation/providers/scheduling_provider.dart';
import '/core/services/socket_service.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with WidgetsBindingObserver {
  String? _selectedVehicleId;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  bool _minimizeEmergency = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) _requestPermissions();
    _startWebSocket();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socketSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Al volver a la app, forzar un refresco inmediato del estado
      ref.read(emergencyNotifierProvider.notifier).refreshStatus();
    }
  }

  void _startWebSocket() {
    // Conectar WebSocket y suscribirnos a las actualizaciones de estado
    ref.read(socketServiceProvider).connect();
    _socketSubscription = ref.read(socketServiceProvider).messages.listen((message) {
      debugPrint('🔔 SOS_SCREEN WebSocket event: $message');
      final type = message['type'];
      if (type == 'ANALYSIS_COMPLETED' || 
          type == 'EMERGENCY_ASSIGNED' || 
          type == 'SLOT_FILLING_REQUIRED' || 
          type == 'PAYMENT_CONFIRMED' || 
          type == 'NEW_INCIDENT' ||
          type == 'STATUS_UPDATED' ||
          type == 'STATUS_UPDATE' ||
          type == 'WS_CONNECTED') {
        ref.read(emergencyNotifierProvider.notifier).refreshStatus();
      }
      if (type == 'APPOINTMENT_UPDATED') {
        ref.invalidate(myAppointmentsProvider);
        ref.invalidate(workshopAppointmentsProvider);
      }
    });
  }

  Future<void> _requestPermissions() async {
    // Pedimos permisos de forma escalonada para no saturar el sistema
    await Permission.location.request();
    await Future.delayed(const Duration(milliseconds: 300));
    await Permission.microphone.request();
    await Future.delayed(const Duration(milliseconds: 300));
    await Permission.camera.request();
    
    if (!kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 300));
      await Permission.photos.request();
    }
  }

  void _handleSos() {
    if (_selectedVehicleId == null) {
      final vehiclesAsync = ref.read(vehicleListProvider);
      vehiclesAsync.whenData((vehicles) {
        if (vehicles.isNotEmpty) {
          setState(() => _selectedVehicleId = vehicles.first.id);
        }
      });
    }

    if (_selectedVehicleId == null) {
      _showSnackBar(
        'Por favor, selecciona un vehículo primero',
        Colors.orangeAccent,
      );
      return;
    }
    ref.read(emergencyNotifierProvider.notifier).sendSOS(_selectedVehicleId!);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final emergencyState = ref.watch(emergencyNotifierProvider);

    // Escuchar cambios en la emergencia
    ref.listen(emergencyNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) => _showSnackBar('Error: $error', Colors.redAccent),
        data: (incident) {
          // 1. Detección de nuevo SOS enviado
          if (incident != null &&
              previous is AsyncLoading &&
              (incident.estado == 'PENDIENTE' || incident.estado == 'BUSCANDO_TALLER')) {
            _showSnackBar('SOS iniciado. Agrega evidencias para completar el reporte.', Colors.blueAccent);
            context.push('/evidence', extra: {'incidentId': incident.id});
          }

          // 2. Detección de emergencia finalizada o cancelada (cuando desaparece del servidor o se completa localmente)
          if (incident == null && previous?.value != null) {
            ref.invalidate(evidenceProvider);
            setState(() => _minimizeEmergency = false);
            
            final oldIncident = previous!.value!;
            final oldStatus = oldIncident.estado;
            final obs = oldIncident.observaciones ?? '';
            final isEfectivo = obs.startsWith('[EFECTIVO]');
            
            if (isEfectivo) {
              _showEfectivoSuccessDialog(context);
            } else if (oldStatus == 'EN_PROGRESO' || oldStatus == 'EN_CAMINO' || oldStatus == 'ASIGNADO' || oldStatus == 'EN_ATENCION') {
              _showSuccessDialog(context, oldIncident.id);
            } else if (oldStatus == 'FINALIZADO') {
              // Si ya se pagó por stripe, StripePaymentScreen muestra su propio dialog de éxito, no hacemos nada aquí
            } else {
              _showSnackBar('La emergencia ha finalizado o fue cancelada.', Colors.orangeAccent);
            }
          }

          // 3. Notificaciones de cambio de estado (mientras sigue activa)
          if (incident != null && previous?.value != null) {
            final oldStatus = previous!.value!.estado;
            final newStatus = incident.estado;

            if (oldStatus != newStatus) {
              if (newStatus == 'TALLER_ASIGNADO') {
                _showSnackBar('🏢 ¡Taller asignado con éxito!', Colors.green);
              } else if (newStatus == 'EN_CAMINO') {
                _showSnackBar('🚀 ¡El técnico va en camino!', Colors.blue);
              } else if (newStatus == 'EN_PROGRESO') {
                _showSnackBar(
                  '🔧 El técnico ha llegado. Iniciando reparación.',
                  Colors.orange,
                );
              } else if (newStatus == 'FINALIZADO') {
                _showSnackBar(
                  '🔧 El técnico ha finalizado el servicio. Pendiente de pago.',
                  Colors.blue,
                );
              } else if (newStatus == 'COMPLETADO') {
                // Por si el servidor la devuelve explícitamente como completada
                _showSuccessDialog(context, incident.id);
              }
            }
          }
        },
      );
    });

    // Desconectar al cerrar sesión
    ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated) {
        _socketSubscription?.cancel();
        ref.read(socketServiceProvider).disconnect();
      }
    });

    // Lógica para usuarios nuevos (Solo SnackBar, el Router maneja la navegación)
    ref.listen(vehicleListProvider, (previous, next) {
      next.whenData((vehicles) {
        if (vehicles.isEmpty && authState.status == AuthStatus.authenticated) {
          _showSnackBar(
            '¡Bienvenido! Registra tu primer vehículo.',
            Colors.blueAccent,
          );
        }
      });
    });

    final activeIncident = emergencyState.value;
    if (activeIncident == null) {
      _minimizeEmergency = false;
    }

    if (activeIncident != null && !_minimizeEmergency) {
      return ActiveEmergencyStatus(
        incident: activeIncident,
        onRefresh: () => ref.read(emergencyNotifierProvider.notifier).refreshStatus(),
        onMinimize: () => setState(() => _minimizeEmergency = true),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          const SosBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SosHeader(
                          user: authState.user,
                          onProfileTap: () => context.push('/profile'),
                        ),
                        _buildSosHome(emergencyState),
                        const SizedBox(
                          height: 120,
                        ), // Espacio extra para scroll y evitar que el FAB tape botones
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (activeIncident != null && _minimizeEmergency)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => setState(() => _minimizeEmergency = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: Color(0xFF3B82F6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Servicio en progreso',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getMiniStatusMessage(activeIncident.estado),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _minimizeEmergency = false),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'VER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SosBottomNav(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            context.go('/garage');
          }
          if (index == 2) {
            context.go('/citas');
          }
          if (index == 3) {
            context.go('/history');
          }
        },
      ),
    );
  }

  Widget _buildSosHome(AsyncValue<IncidentResponse?> emergencyState) {
    return Column(
      children: [
        const SosTitles(),
        const SizedBox(height: 30),
        ActiveVehicleCard(
          selectedVehicleId: _selectedVehicleId,
          onVehicleChanged: (val) => setState(() => _selectedVehicleId = val),
        ),
        const SizedBox(height: 30),
        EmergencyButton(emergencyState: emergencyState, onTap: _handleSos),
        const SizedBox(height: 15),
        const Text(
          'Pulsa para reportar emergencia',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  void _showSuccessDialog(BuildContext context, String incidentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E293B),
        title: const Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green,
              size: 60,
            ),
            SizedBox(height: 10),
            Text(
              '¡Servicio Finalizado!',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'Servicio finalizado. Revisa el resumen para continuar con el pago.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                // Limpiar cualquier rastro de la emergencia anterior
                ref.invalidate(emergencyNotifierProvider);
                ref.invalidate(evidenceProvider);
                
                // 1. Cerrar el diálogo usando su propio contexto
                Navigator.of(dialogContext).pop();
                
                // 2. Navegar usando el contexto de la pantalla principal (que sigue vivo)
                context.push('/payment', extra: {'incidentId': incidentId});
              },
              child: const Text(
                'VER RESUMEN',
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEfectivoSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E293B),
        title: const Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF10B981),
              size: 60,
            ),
            SizedBox(height: 10),
            Text(
              '¡Servicio Completado!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'El pago en efectivo fue registrado con éxito. ¡Gracias por tu confianza!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'ENTENDIDO',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMiniStatusMessage(String state) {
    final status = state.toUpperCase();
    switch (status) {
      case 'PENDIENTE':
      case 'REPORTADO':
        return 'Emergencia registrada';
      case 'BUSCANDO_TALLER':
        return 'Buscando taller cercano...';
      case 'TALLER_ASIGNADO':
        return 'Taller asignado';
      case 'EN_CAMINO':
        return 'El técnico va en camino';
      case 'TECNICO_EN_SITIO':
        return 'Técnico en sitio, valide el PIN';
      case 'EN_ATENCION':
      case 'EN_PROGRESO':
        return 'Vehículo en reparación';
      case 'FINALIZADO':
        return 'Atención finalizada - Pendiente de pago';
      case 'COMPLETADO':
        return 'Servicio completado';
      default:
        return 'Gestionando emergencia';
    }
  }
}
