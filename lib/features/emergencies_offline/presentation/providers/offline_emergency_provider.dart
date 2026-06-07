import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../emergencies/data/emergency_repository.dart';
import '../../../emergencies/domain/incident.dart';
import '../../../identity/presentation/providers/auth_provider.dart';
import '../../data/offline_connectivity_service.dart';
import '../../data/offline_emergency_local_repository.dart';
import '../../domain/offline_emergency_draft.dart';

final offlineEmergencyLocalRepositoryProvider =
    Provider<OfflineEmergencyLocalRepository>((ref) {
      return OfflineEmergencyLocalRepository();
    });

final offlineConnectivityServiceProvider = Provider<OfflineConnectivityService>(
  (ref) {
    return OfflineConnectivityService(ref.watch(emergencyRepositoryProvider));
  },
);

final offlineEmergencyDraftsProvider =
    AsyncNotifierProvider<
      OfflineEmergencyDraftsNotifier,
      List<OfflineEmergencyDraft>
    >(() {
      return OfflineEmergencyDraftsNotifier();
    });

class OfflineEmergencyDraftsNotifier
    extends AsyncNotifier<List<OfflineEmergencyDraft>> {
  bool _syncInProgress = false;

  @override
  FutureOr<List<OfflineEmergencyDraft>> build() async {
    return _loadVisibleDrafts();
  }

  Future<List<OfflineEmergencyDraft>> _loadVisibleDrafts() async {
    final drafts = await ref
        .read(offlineEmergencyLocalRepositoryProvider)
        .getAllDrafts();
    return drafts.where((draft) => draft.syncStatus != 'SYNCED').toList();
  }

  Future<void> refreshDrafts() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadVisibleDrafts);
  }

  Future<OfflineEmergencyDraft> createOfflineDraft({
    required IncidentCreate incident,
    String? locationReference,
  }) async {
    final draft = OfflineEmergencyDraft(
      localId: _generateLocalId(),
      vehicleId: incident.vehicleId,
      description: (incident.descripcion?.trim().isNotEmpty ?? false)
          ? incident.descripcion!.trim()
          : 'S.O.S generado desde la app movil',
      phone: incident.telefono,
      latitude: incident.latitud ?? 0,
      longitude: incident.longitud ?? 0,
      locationReference: locationReference,
      priority: incident.prioridad,
      createdAt: DateTime.now(),
      syncAttempts: 0,
      syncStatus: 'PENDING_SYNC',
    );

    await ref.read(offlineEmergencyLocalRepositoryProvider).upsertDraft(draft);
    await refreshDrafts();
    return draft;
  }

  Future<void> syncPendingDrafts() async {
    if (_syncInProgress) return;
    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated) return;

    final connectivity = ref.read(offlineConnectivityServiceProvider);
    final canReachBackend = await connectivity.canReachBackend();
    if (!canReachBackend) return;

    _syncInProgress = true;
    try {
      final repo = ref.read(offlineEmergencyLocalRepositoryProvider);
      final remoteRepo = ref.read(emergencyRepositoryProvider);
      final drafts = await repo.getPendingDrafts();

      for (final draft in drafts) {
        final syncingDraft = draft.copyWith(
          syncStatus: 'SYNCING',
          syncAttempts: draft.syncAttempts + 1,
          lastSyncAttemptAt: DateTime.now(),
          lastError: null,
        );
        await repo.updateDraft(syncingDraft);

        try {
          final response = await remoteRepo.syncOfflineIncident(
            identificadorLocal: draft.localId,
            vehicleId: draft.vehicleId,
            descripcion: draft.description,
            telefono: draft.phone,
            latitud: draft.latitude,
            longitud: draft.longitude,
            ubicacionReferencial: draft.locationReference,
            prioridad: draft.priority,
            fechaRegistroLocal: draft.createdAt,
          );

          final syncedDraft = syncingDraft.copyWith(
            syncStatus: 'SYNCED',
            backendIncidentId: response.incidentId,
            lastError: null,
          );
          await repo.updateDraft(syncedDraft);
        } catch (error) {
          final failedDraft = syncingDraft.copyWith(
            syncStatus: 'FAILED',
            lastError: error.toString(),
          );
          await repo.updateDraft(failedDraft);
        }
      }

      await refreshDrafts();
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> retrySync(String localId) async {
    final repo = ref.read(offlineEmergencyLocalRepositoryProvider);
    final drafts = await repo.getAllDrafts();
    OfflineEmergencyDraft? draft;
    for (final item in drafts) {
      if (item.localId == localId) {
        draft = item;
        break;
      }
    }
    if (draft == null) return;

    await repo.updateDraft(
      draft.copyWith(syncStatus: 'PENDING_SYNC', lastError: null),
    );
    await syncPendingDrafts();
  }

  Future<void> deleteDraft(String localId) async {
    await ref
        .read(offlineEmergencyLocalRepositoryProvider)
        .deleteDraft(localId);
    await refreshDrafts();
  }

  String _generateLocalId() {
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'offline_${DateTime.now().millisecondsSinceEpoch}_$random';
  }
}
