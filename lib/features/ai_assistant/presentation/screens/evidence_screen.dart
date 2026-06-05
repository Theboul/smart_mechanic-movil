import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/evidence_provider.dart';
import '../../../../core/theme/app_theme.dart';

class EvidenceScreen extends ConsumerStatefulWidget {
  final String incidentId;
  const EvidenceScreen({super.key, required this.incidentId});

  @override
  ConsumerState<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends ConsumerState<EvidenceScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    
    // Sincronizar controlador con el provider si ya existiera descripción
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialDesc = ref.read(evidenceProvider).description;
      if (initialDesc != null) {
        _descriptionController.text = initialDesc;
      }
    });

    _descriptionController.addListener(() {
      ref.read(evidenceProvider.notifier).setDescription(_descriptionController.text);
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('STT status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (errorNotification) {
          debugPrint('STT error: $errorNotification');
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) {
        setState(() {
          _speechAvailable = available;
        });
      }
    } catch (e) {
      debugPrint('Speech to text not supported or error: $e');
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (_speechAvailable) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _descriptionController.text = result.recognizedWords;
                // Colocar cursor al final
                _descriptionController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _descriptionController.text.length),
                );
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            localeId: 'es_ES',
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconocimiento de voz no disponible en este dispositivo. Escribe manualmente.'),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      ref.read(evidenceProvider.notifier).setPhoto(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(evidenceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('EVIDENCIA S.O.S', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E293B).withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
            child: Column(
              children: [
                Expanded(child: _buildImageSection(state)),
                _buildVoiceTranscriptionPanel(state),
                _buildBottomAction(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(EvidenceState state) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.electricBlue.withValues(alpha: 0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.electricBlue.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (state.photo != null)
            kIsWeb 
              ? Image.network(state.photo!.path, fit: BoxFit.cover)
              : Image.file(File(state.photo!.path), fit: BoxFit.cover)
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: AppTheme.electricBlue.withValues(alpha: 0.4), size: 80),
                  const SizedBox(height: 16),
                  const Text('Añade una foto del incidente', style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            ),
          
          // Botones flotantes de imagen
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildImageActionButton(
                  icon: Icons.camera_alt,
                  label: 'CÁMARA',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 15),
                _buildImageActionButton(
                  icon: Icons.photo_library,
                  label: 'GALERÍA',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.electricBlue, size: 20),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceTranscriptionPanel(EvidenceState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'DESCRIPCIÓN DE LA EMERGENCIA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 12,
                  ),
                ),
              ),
              if (_isListening)
                const Row(
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'ESCUCHANDO...',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Describe lo que ocurre (ej. "Mi auto echa humo y no enciende...")',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.electricBlue.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.electricBlue),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors.redAccent.withValues(alpha: 0.2)
                          : AppTheme.electricBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isListening
                            ? Colors.redAccent
                            : AppTheme.electricBlue.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isListening
                              ? Colors.redAccent.withValues(alpha: 0.3)
                              : AppTheme.electricBlue.withValues(alpha: 0.2),
                          blurRadius: 15,
                        )
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.redAccent : AppTheme.electricBlue,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                if (_descriptionController.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _descriptionController.clear();
                      ref.read(evidenceProvider.notifier).clearDescription();
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28),
                    tooltip: 'Limpiar descripción',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(EvidenceState state) {
    final isUploading = state.isUploading;
    final hasEvidence = state.photo != null || (state.description != null && state.description!.isNotEmpty);
    final buttonText = hasEvidence ? 'INICIAR ANÁLISIS INTELIGENTE' : 'OMITIR Y CONTINUAR';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ElevatedButton(
        onPressed: isUploading 
            ? null 
            : () async {
                await ref.read(evidenceProvider.notifier).uploadAll(widget.incidentId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(hasEvidence 
                          ? '✅ Evidencias enviadas. Iniciando análisis...' 
                          : '🚀 Creando reporte sin evidencias... Estamos buscando un taller disponible.'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  context.go('/ai-analysis');
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.electricBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white10,
          minimumSize: const Size(double.infinity, 65),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          shadowColor: AppTheme.electricBlue.withValues(alpha: 0.5),
        ),
        child: isUploading 
            ? const SizedBox(
                height: 25,
                width: 25,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
      ),
    );
  }
}
