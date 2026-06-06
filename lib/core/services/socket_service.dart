import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/local_storage/secure_storage_provider.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService(ref);
});

class SocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  bool _isConnecting = false;
  bool _isDisconnected = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  SocketService(this._ref);

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connect() async {
    if (_isConnecting) return;
    if (_channel != null) return;

    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: 'jwt_token');
    
    if (token == null) return;

    // Obtener URL base de .env
    final wsBase = dotenv.env['WS_URL'] ?? 'ws://127.0.0.1:8000';
    final baseUrl = '$wsBase/ws?token=$token';
    
    debugPrint('Conectando a WebSocket: $baseUrl');

    _isConnecting = true;
    _isDisconnected = false;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(baseUrl));
      _reconnectAttempt = 0;
      _messageController.add({'type': 'WS_CONNECTED'});

      _channel!.stream.listen(
        (data) {
          final Map<String, dynamic> message = jsonDecode(data);
          _messageController.add(message);
          debugPrint('Mensaje WS recibido: $message');
        },
        onError: (err) {
          debugPrint('Error en WS: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('Conexión WS cerrada');
          _scheduleReconnect();
        },
      );
    } catch (err) {
      debugPrint('Error al conectar WS: $err');
      _channel = null;
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _scheduleReconnect() {
    if (_isDisconnected) return;
    _channel = null;
    _reconnectTimer?.cancel();
    final delaySeconds = (_reconnectAttempt < 5)
        ? 5 * (_reconnectAttempt + 1)
        : 30;
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connect();
    });
  }

  void disconnect() {
    _isDisconnected = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
  }

  WebSocketChannel connectToIncident(String incidentId, String token) {
    final wsBase = dotenv.env['WS_URL'] ?? 'ws://127.0.0.1:8000';
    final url = '$wsBase/api/v1/emergencies/ws/incidents/$incidentId?token=$token';
    debugPrint('🔌 Connecting to Incident WS: $url');
    return WebSocketChannel.connect(Uri.parse(url));
  }
}
