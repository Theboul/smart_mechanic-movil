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

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with WidgetsBindingObserver {
  String? _selectedVehicleId;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) _requestPermissions();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Al volver a la app, forzar un refresco inmediato del estado
      ref.read(emergencyNotifierProvider.notifier).refreshStatus();
    }
  }

  void _startPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Bloqueo de seguridad: si no hay sesión, paramos el reloj
      if (ref.read(authProvider).status != AuthStatus.authenticated) {
        _statusTimer?.cancel();
        return;
      }
      ref.read(emergencyNotifierProvider.notifier).refreshStatus();
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
              incident.estado == 'PENDIENTE') {
            _showSnackBar('¡S.O.S enviado! Ayuda en camino.', Colors.green);
            context.push('/evidence', extra: {'incidentId': incident.id});
          }

          // 2. Detección de emergencia finalizada o cancelada (cuando desaparece del servidor)
          if (incident == null && previous?.value != null) {
            ref.invalidate(evidenceProvider);
            
            final oldStatus = previous!.value!.estado;
            // Si estaba siendo atendida y de repente desaparece, significa que el técnico la finalizó
            if (oldStatus == 'EN_PROGRESO' || oldStatus == 'EN_CAMINO' || oldStatus == 'ASIGNADO') {
              _showSuccessDialog(context);
            } else {
              _showSnackBar('La emergencia ha finalizado o fue cancelada.', Colors.orangeAccent);
            }
          }

          // 3. Notificaciones de cambio de estado (mientras sigue activa)
          if (incident != null && previous?.value != null) {
            final oldStatus = previous!.value!.estado;
            final newStatus = incident.estado;

            if (oldStatus != newStatus) {
              if (newStatus == 'EN_CAMINO') {
                _showSnackBar('🚀 ¡El técnico va en camino!', Colors.blue);
              } else if (newStatus == 'EN_PROGRESO') {
                _showSnackBar(
                  '🔧 El técnico ha llegado. Iniciando reparación.',
                  Colors.orange,
                );
              } else if (newStatus == 'COMPLETADO') {
                // Por si el servidor la devuelve explícitamente como completada
                _showSuccessDialog(context);
              }
            }
          }
        },
      );
    });

    // Detener polling al cerrar sesión
    ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated) {
        _statusTimer?.cancel();
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

                        emergencyState.when(
                          data: (incident) {
                            if (incident == null) {
                              return _buildSosHome(emergencyState);
                            }
                            return ActiveEmergencyStatus(
                              incident: incident,
                              onRefresh: () => ref
                                  .read(emergencyNotifierProvider.notifier)
                                  .refreshStatus(),
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (e, _) => _buildSosHome(emergencyState),
                        ),
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
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 75), // Elevar el botón para no tapar la nav bar
        child: emergencyState.when(
          data: (incident) => FloatingActionButton.extended(
            onPressed: () => context.push('/ai-analysis'),
            backgroundColor: const Color(0xFF3B82F6),
            elevation: 4,
            icon: const Icon(Icons.smart_toy_rounded, color: Colors.white),
            label: const Text(
              'IA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          loading: () => null,
          error: (_, _) => null,
        ),
      ),
      bottomNavigationBar: SosBottomNav(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            context.go('/garage');
          }
          if (index == 2) {
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

  void _showSuccessDialog(BuildContext context) {
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
          'Tu emergencia ha sido atendida con éxito. Esperamos que todo esté bien con tu vehículo.',
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
                context.push('/payment');
              },
              child: const Text(
                'IR AL PAGO',
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
}
