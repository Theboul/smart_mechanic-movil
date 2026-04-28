import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/evidence_repository.dart';
//import 'chat_provider.dart';

class EvidenceState {
  final XFile? photo;
  final String? audioPath;
  final bool isUploading;
  final String? error;
  final bool isSuccess;

  EvidenceState({
    this.photo,
    this.audioPath,
    this.isUploading = false,
    this.error,
    this.isSuccess = false,
  });

  EvidenceState copyWith({
    XFile? photo,
    String? audioPath,
    bool? isUploading,
    String? error,
    bool? isSuccess,
  }) {
    return EvidenceState(
      photo: photo ?? this.photo,
      audioPath: audioPath ?? this.audioPath,
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
      audioPath: state.audioPath,
      isUploading: state.isUploading,
      error: state.error,
      isSuccess: state.isSuccess,
    );
  }

  void setAudio(String path) {
    state = state.copyWith(audioPath: path);
  }

  void clearAudio() {
    state = EvidenceState(
      photo: state.photo,
      audioPath: null,
      isUploading: state.isUploading,
      error: state.error,
      isSuccess: state.isSuccess,
    );
  }

  Future<void> uploadAll(String incidentId) async {
    if (state.photo == null && state.audioPath == null) return;

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

      // Subir audio si existe
      if (state.audioPath != null) {
        await repository.uploadEvidence(
          incidentId: incidentId,
          filePath: state.audioPath!,
          type: 'audio',
        );
      }
      
      // Gatillar el análisis de IA y asignación de taller una sola vez
      await repository.processIncident(incidentId);

      state = state.copyWith(isSuccess: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isUploading: false);
    }
  }
}
