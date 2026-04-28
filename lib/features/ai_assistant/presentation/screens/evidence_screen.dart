import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/evidence_provider.dart';
import '../../../../core/theme/app_theme.dart';

class EvidenceScreen extends ConsumerStatefulWidget {
  final String incidentId;
  const EvidenceScreen({super.key, required this.incidentId});

  @override
  ConsumerState<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends ConsumerState<EvidenceScreen> {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  Timer? _timer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    // Ya no disparamos la cámara automáticamente para evitar confusión al entrar desde notificaciones
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor().toString().padLeft(2, '0');
    final secs = (seconds % 60).floor().toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      ref.read(evidenceProvider.notifier).setPhoto(image);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? path;
        if (!kIsWeb) {
          final dir = await getTemporaryDirectory();
          path = '${dir.path}/sos_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        
        await _audioRecorder.start(const RecordConfig(), path: path ?? '');
        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordDuration = 0;
        });
        _startTimer();
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _pauseRecording() async {
    await _audioRecorder.pause();
    _timer?.cancel();
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    await _audioRecorder.resume();
    _startTimer();
    setState(() => _isPaused = false);
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
    if (path != null) {
      ref.read(evidenceProvider.notifier).setAudio(path);
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordDuration = 0;
    });
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
        child: Column(
          children: [
            Expanded(child: _buildImageSection(state)),
            _buildAudioControlPanel(state),
            _buildBottomAction(state),
          ],
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

  Widget _buildAudioControlPanel(EvidenceState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isRecording ? 'GRABANDO' : (state.audioPath != null ? 'AUDIO LISTO' : 'EXPLICACIÓN'),
                style: TextStyle(
                  color: _isRecording ? Colors.redAccent : Colors.white70,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
              if (_isRecording)
                Text(
                  _formatDuration(_recordDuration),
                  style: const TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_isRecording) ...[
                // Botón Cancelar
                _buildRoundControl(
                  icon: Icons.close,
                  color: Colors.white24,
                  onTap: _cancelRecording,
                ),
                // Botón Pausar/Reanudar
                _buildRoundControl(
                  icon: _isPaused ? Icons.play_arrow : Icons.pause,
                  color: AppTheme.electricBlue,
                  size: 70,
                  onTap: _isPaused ? _resumeRecording : _pauseRecording,
                ),
                // Botón Detener/Guardar
                _buildRoundControl(
                  icon: Icons.stop,
                  color: Colors.redAccent,
                  onTap: _stopRecording,
                ),
              ] else if (state.audioPath != null) ...[
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.greenAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AUDIO LISTO',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              'Audio grabado correctamente',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => ref.read(evidenceProvider.notifier).clearAudio(),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        tooltip: 'Eliminar audio',
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Botón Iniciar Grabación
                GestureDetector(
                  onTap: _startRecording,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.electricBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.electricBlue.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(color: AppTheme.electricBlue.withValues(alpha: 0.2), blurRadius: 15)
                      ]
                    ),
                    child: const Icon(Icons.mic, color: AppTheme.electricBlue, size: 40),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoundControl({required IconData icon, required Color color, double size = 55, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }

  Widget _buildBottomAction(EvidenceState state) {
    final canUpload = (state.photo != null || state.audioPath != null) && !state.isUploading;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ElevatedButton(
        onPressed: canUpload 
            ? () async {
                await ref.read(evidenceProvider.notifier).uploadAll(widget.incidentId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Evidencias enviadas. Iniciando análisis...'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  // Usamos .go para reemplazar la pantalla actual y que no se pueda volver atrás
                  context.go('/ai-analysis');
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.electricBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white10,
          minimumSize: const Size(double.infinity, 65),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          shadowColor: AppTheme.electricBlue.withValues(alpha: 0.5),
        ),
        child: state.isUploading 
            ? const SizedBox(
                height: 25,
                width: 25,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : const Text(
                'INICIAR ANÁLISIS INTELIGENTE',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
      ),
    );
  }
}
