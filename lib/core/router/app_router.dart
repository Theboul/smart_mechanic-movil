import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/identity/presentation/providers/auth_provider.dart';
import '../../features/garage/presentation/providers/vehicle_provider.dart';

import '../../features/garage/presentation/screens/garage_screen.dart';
import '../../features/identity/presentation/screens/profile_screen.dart';
import '../../features/identity/presentation/screens/login_screen.dart';
import '../../features/identity/presentation/screens/register_screen.dart';
import '../../features/garage/presentation/screens/register_vehicle_screen.dart';
import '../../features/emergencies/presentation/screens/sos_screen.dart';
import '../../features/emergencies/presentation/screens/history_screen.dart';
import '../../features/emergencies/presentation/screens/technician_dashboard_screen.dart';
import '../../features/emergencies/presentation/screens/technician_incident_detail_screen.dart';
import '../../features/emergencies/presentation/screens/technician_active_trip_screen.dart';
import '../../features/ai_assistant/presentation/screens/evidence_screen.dart';
import '../../features/ai_assistant/presentation/screens/ai_chat_screen.dart';
import '../../features/finance/presentation/screens/stripe_payment_screen.dart';
import '../../features/scheduling/presentation/screens/citas_screen.dart';
import '../../features/scheduling/presentation/screens/schedule_followup_screen.dart';


final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final vehicleState = ref.read(vehicleListProvider);

      log('🛤️ ROUTER: Redirecting... Location: ${state.uri.path}, Status: ${authState.status}');

      // 0. Si está cargando el token inicial, no redirigir aún
      if (authState.status == AuthStatus.initial) return null;

      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isLoggingIn =
          state.uri.path == '/login' ||
          state.uri.path == '/register';
      final isRegisterVehicle = state.uri.path == '/register-vehicle';

      // 1. Si NO está logueado, forzar login (siempre que no esté ya en una pantalla de auth)
      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      // 2. Si está logueado pero está en pantallas de auth, mandarlo al Home
      if (isLoggedIn && isLoggingIn) return '/';

      // Si el usuario es un técnico, omitimos la comprobación de vehículos
      final isTechnician = authState.user?.rol == 'tecnico';
      if (isTechnician) return null;

      // 3. Lógica de vehículos para usuarios logueados (clientes)
      return vehicleState.when(
        data: (vehicles) {
          // Si no tiene vehículos y no está en login/register/register-vehicle, obligarlo a registrar
          if (vehicles.isEmpty && !isRegisterVehicle) {
            return '/register-vehicle';
          }
          return null;
        },
        loading: () => null,
        error: (_, _) => null,
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/garage',
        builder: (context, state) => const GarageScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/register-vehicle',
        builder: (context, state) => const RegisterVehicleScreen(),
      ),
      GoRoute(
        path: '/evidence',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return EvidenceScreen(incidentId: extra?['incidentId'] ?? '');
        },
      ),
      GoRoute(
        path: '/ai-analysis',
        builder: (context, state) => const AIChatScreen(),
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return StripePaymentScreen(incidentId: extra?['incidentId'] ?? '');
        },
      ),
      GoRoute(
        path: '/technician/incident-detail',
        builder: (context, state) => const TechnicianIncidentDetailScreen(),
      ),
      GoRoute(
        path: '/technician/active-trip',
        builder: (context, state) => const TechnicianActiveTripScreen(),
      ),
      GoRoute(
        path: '/citas',
        builder: (context, state) => const CitasScreen(),
      ),
      GoRoute(
        path: '/technician/schedule-followup',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ScheduleFollowUpScreen(
            incidentId: extra['incidentId']!,
            vehicleId: extra['vehicleId']!,
            sucursalId: extra['sucursalId']!,
            tecnicoId: extra['tecnicoId'],
          );
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final user = ref.read(authProvider).user;
          if (user != null && user.rol == 'tecnico') {
            return const TechnicianDashboardScreen();
          }
          return const SosScreen();
        },
      ),
    ],
  );
});

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authProvider, (_, _) => notifyListeners());
    _ref.listen(vehicleListProvider, (_, _) => notifyListeners());
  }
}
