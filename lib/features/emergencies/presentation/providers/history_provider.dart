import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/emergency_repository.dart';
import '../../domain/incident.dart';

import '../../../identity/presentation/providers/auth_provider.dart';

final historyProvider = FutureProvider.autoDispose<List<IncidentResponse>>((ref) async {
  // Observamos el estado de auth para que se invalide si cambia el usuario
  final authState = ref.watch(authProvider);
  if (authState.status != AuthStatus.authenticated) return [];
  
  return ref.watch(emergencyRepositoryProvider).getIncidentHistory();
});
