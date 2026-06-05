import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/evidence_repository.dart';

class EvidenceState {
  final XFile? photo;
  final String? description;
  final bool isUploading;
  final String? error;
  final bool isSuccess;

  EvidenceState({
    this.photo,
    this.description,
    this.isUploading = false,
    this.error,
    this.isSuccess = false,
  });

  EvidenceState copyWith({
    XFile? photo,
    String? description,
    bool? isUploading,
    String? error,
    bool? isSuccess,
  }) {
    return EvidenceState(
      photo: photo ?? this.photo,
      description: description ?? this.description,
      isUploading: isUploading ?? this.isUploading,
      error: error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

final evidenceProvider = NotifierProvider<EvidenceNotifier, EvidenceState>(() {
  return EvidenceNotifier();
});

class EvidenceNotifier extends Notifier<EvidenceState> {
  @override
  EvidenceState build() {
    return EvidenceState();
  }

  void setPhoto(XFile file) {
    state = state.copyWith(photo: file);
  }

  void clearPhoto() {
    state = EvidenceState(
      photo: null,
      description: state.description,
      isUploading: state.isUploading,
      error: state.error,
      isSuccess: state.isSuccess,
    );
  }

  void setDescription(String text) {
    state = state.copyWith(description: text);
  }

  void clearDescription() {
    state = EvidenceState(
      photo: state.photo,
      description: null,
      isUploading: state.isUploading,
      error: state.error,
      isSuccess: state.isSuccess,
    );
  }

  Future<void> uploadAll(String incidentId) async {
    state = state.copyWith(isUploading: true, error: null, isSuccess: false);

    try {
      final repository = ref.read(evidenceRepositoryProvider);

      // Subir foto si existe
      if (state.photo != null) {
        await repository.uploadEvidence(
          incidentId: incidentId,
          filePath: state.photo!.path,
          type: 'foto',
        );
      }

      // Gatillar el análisis de IA y asignación de taller pasándole la descripción
      await repository.processIncident(incidentId, description: state.description);

      state = state.copyWith(isSuccess: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(isUploading: false);
    }
  }
}
