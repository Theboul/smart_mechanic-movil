import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../features/identity/data/auth_repository.dart';
import '../../features/identity/presentation/providers/auth_provider.dart';
import '../router/app_router.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Esta función DEBE ser global y de alto nivel
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log("📩 PUSH (Background): ${message.messageId}");
}

class NotificationService {
  final Ref _ref;
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin get _localNotifications => FlutterLocalNotificationsPlugin();
  GlobalKey<ScaffoldMessengerState>? _messengerKey;

  // Definición del canal para Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notificaciones de Emergencia',
    description: 'Este canal se usa para alertas críticas y actualizaciones de S.O.S.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  NotificationService(this._ref);

  Future<void> initialize(GlobalKey<ScaffoldMessengerState> key) async {
    _messengerKey = key;
    
    if (kIsWeb) {
      log('🔔 NOTIFICACIONES: Ignorando inicialización de notificaciones en Web.');
      return;
    }
    
    // 1. Configurar Local Notifications (Para Android/iOS)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Manejar toque en notificación local (foreground)
        // Aquí podríamos disparar la navegación similar a onMessageOpenedApp
      },
    );

    // 2. Crear el canal en Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Escuchar cambios de autenticación para sincronizar el token
    _ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated && previous?.status != AuthStatus.authenticated) {
        log('👤 NOTIFICACIONES: Usuario autenticado detectado. Sincronizando token...');
        _fcm.getToken().then((token) {
          if (token != null) syncToken(token);
        });
      }
    });

    // Registrar el manejador de segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Solicitar permisos (OS + FCM)
    log('🔔 NOTIFICACIONES: Solicitando permisos...');
    final osStatus = await Permission.notification.request();
    
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized || osStatus.isGranted) {
      log('✅ NOTIFICACIONES: Permisos autorizados');
      
      String? token = await _fcm.getToken();
      if (token != null) {
        log('🔑 FCM TOKEN: $token');
      }

      _setupNotificationListeners();
    } else {
      log('❌ NOTIFICACIONES: Permisos denegados');
    }
  }

  Future<void> syncToken(String token) async {
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.updateFcmToken(token);
      log('✅ NOTIFICACIONES: Token sincronizado con el servidor');
    } catch (e) {
      log('❌ NOTIFICACIONES: Error de sincronización: $e');
    }
  }

  void _setupNotificationListeners() {
    // 1. App en Primer Plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;

      log('📩 PUSH (Foreground): ${notification?.title}');

      // Si hay notificación, mostrarla usando LocalNotifications para que aparezca arriba
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          payload: message.data.toString(),
        );

        // También mostramos un SnackBar para redundancia visual y acción rápida
        _showForegroundSnackBar(message);
      }
    });

    // 2. App abierta desde Notificación (Background/Terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('🛤️ NAVEGACIÓN: App abierta desde notificación');
      _handleNotificationNavigation(message);
    });
  }

  void _showForegroundSnackBar(RemoteMessage message) {
    final title = message.notification?.title ?? 'Notificación';
    _messengerKey?.currentState?.showSnackBar(
      SnackBar(
        content: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'VER',
          onPressed: () => _handleNotificationNavigation(message),
        ),
      ),
    );
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    final type = message.data['type'];
    final router = _ref.read(appRouterProvider);

    log('🛤️ NAVEGACIÓN: Tipo detectado -> $type');

    switch (type) {
      case 'ANALYSIS_COMPLETED':
      case 'WORKSHOP_ASSIGNED':
      case 'AI_RESPONSE':
        // Usamos go en lugar de push para evitar duplicar la pantalla si ya estamos ahí
        router.go('/ai-analysis');
        break;
      default:
        router.go('/');
    }
  }
}

// Provider para acceder al servicio desde cualquier parte de la app
final notificationServiceProvider = Provider((ref) => NotificationService(ref));
