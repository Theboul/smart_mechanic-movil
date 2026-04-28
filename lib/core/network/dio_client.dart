import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../local_storage/secure_storage_provider.dart';
import '../../features/identity/presentation/providers/auth_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          log(
            '📡 DIO: Enviando petición a ${options.path} con token (puntos: ${token.length > 10 ? "${token.substring(0, 5)}..." : "corto"})',
          );
        } else {
          log('📡 DIO: Enviando petición a ${options.path} SIN TOKEN');
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        log(
          '❌ DIO ERROR: ${e.requestOptions.path} -> Status: ${e.response?.statusCode}',
        );
        if (e.response?.statusCode == 401) {
          // Solo forzar logout si no estamos intentando loguear o registrar
          final isAuthPath =
              e.requestOptions.path.contains('auth/login') ||
              e.requestOptions.path.contains('auth/register');

          if (!isAuthPath) {
            log('🚨 DIO: 401 detectado en ruta protegida. Forzando logout...');
            ref.read(authProvider.notifier).forceLogout();
          }
        }
        return handler.next(e);
      },
    ),
  );

  return dio;
});
