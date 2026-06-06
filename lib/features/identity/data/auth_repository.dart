import 'package:dio/dio.dart';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/local_storage/secure_storage_provider.dart';
import '../../../core/network/dio_client.dart';
import '../domain/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthRepository({required Dio dio, required FlutterSecureStorage storage}) 
      : _dio = dio, _storage = storage;

  Future<TokenSchema> login(String email, String password) async {
    log('LOGIN REQUEST: ${_dio.options.baseUrl}/api/v1/identity/auth/login');
    final response = await _dio.post(
      '/api/v1/identity/auth/login',
      data: {
        'correo': email,
        'contrasena': password,
      },
    );

    log('LOGIN RESPONSE: ${response.statusCode}');
    final tokenSchema = TokenSchema.fromJson(response.data);
    await _storage.write(key: 'jwt_token', value: tokenSchema.accessToken);
    return tokenSchema;
  }

  Future<User> register(UserCreate userCreate) async {
    final response = await _dio.post(
      '/api/v1/identity/auth/register/cliente',
      data: userCreate.toJson(),
    );
    return User.fromJson(response.data);
  }

  Future<User> getMe() async {
    final response = await _dio.get('/api/v1/identity/users/me');
    return User.fromJson(response.data);
  }

  Future<User> updateMe(UserProfileUpdate update) async {
    final response = await _dio.put(
      '/api/v1/identity/users/me',
      data: update.toJson(),
    );
    return User.fromJson(response.data);
  }

  Future<void> logout() async {
    try {
      // Avisar al servidor para limpiar el token de notificaciones
      await updateFcmToken('');
    } catch (_) {
      // Ignoramos errores aquí para asegurar que el logout local ocurra
    }
    await _storage.delete(key: 'jwt_token');
  }

  Future<void> updateFcmToken(String token) async {
    await _dio.post(
      '/api/v1/identity/auth/fcm-token',
      data: {'fcm_token': token},
    );
  }
}
