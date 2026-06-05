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

  SocketService(this._ref);

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connect() async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: 'jwt_token');
    
    if (token == null) return;

    // Obtener URL base de .env
    final wsBase = dotenv.env['WS_URL'] ?? 'ws://127.0.0.1:8000';
    final baseUrl = '$wsBase/ws?token=$token';
    
    debugPrint('Conectando a WebSocket: $baseUrl');
    
    _channel = WebSocketChannel.connect(Uri.parse(baseUrl));
    _messageController.add({'type': 'WS_CONNECTED'});

    _channel!.stream.listen(
      (data) {
        final Map<String, dynamic> message = jsonDecode(data);
        _messageController.add(message);
        debugPrint('Mensaje WS recibido: $message');
      },
      onError: (err) {
        debugPrint('Error en WS: $err');
        _reconnect();
      },
      onDone: () {
        debugPrint('Conexión WS cerrada');
        _reconnect();
      },
    );
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () => connect());
  }

  void disconnect() {
    _channel?.sink.close();
  }

  WebSocketChannel connectToIncident(String incidentId, String token) {
    final wsBase = dotenv.env['WS_URL'] ?? 'ws://127.0.0.1:8000';
    final url = '$wsBase/api/v1/emergencies/ws/incidents/$incidentId?token=$token';
    debugPrint('🔌 Connecting to Incident WS: $url');
    return WebSocketChannel.connect(Uri.parse(url));
  }
}
