import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/local_storage/secure_storage_provider.dart';
import '../../data/auth_repository.dart';
import '../../domain/user.dart';

enum AuthStatus { authenticated, unauthenticated, initial }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  AuthState({this.status = AuthStatus.initial, this.user, this.errorMessage});

  AuthState copyWith({AuthStatus? status, User? user, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(() => _checkToken());
    return AuthState();
  }

  Future<void> _checkToken() async {
    try {
      final user = await ref.read(authRepositoryProvider).getMe();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        errorMessage: null,
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.initial, errorMessage: null);
    try {
      final tokenSchema = await ref
          .read(authRepositoryProvider)
          .login(email, password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: tokenSchema.user,
        errorMessage: null,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      log('LOGIN ERROR: $statusCode ${e.message}');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage:
            statusCode == 401
                ? 'Credenciales incorrectas. Verifica tu correo y contrasena.'
                : 'No se pudo conectar con el servidor. Verifica la red y la URL de la API.',
      );
    } catch (e) {
      log('LOGIN ERROR: $e');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'No se pudo iniciar sesion. Intenta de nuevo.',
      );
    }
  }

  Future<void> register(UserCreate userCreate) async {
    state = state.copyWith(status: AuthStatus.initial, errorMessage: null);
    try {
      await ref.read(authRepositoryProvider).register(userCreate);
      await login(userCreate.correo, userCreate.contrasena);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Error en el registro. Revisa los datos e intenta de nuevo.',
      );
    }
  }

  Future<void> updateProfile(UserProfileUpdate update) async {
    try {
      final user = await ref.read(authRepositoryProvider).updateMe(update);
      state = state.copyWith(user: user, errorMessage: null);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Error al actualizar el perfil');
    }
  }

  Future<void> logout() async {
    log('AUTH: iniciando logout');
    try {
      await ref.read(authRepositoryProvider).logout();
      log('AUTH: logout remoto completado');
    } catch (e) {
      log('AUTH: logout remoto fallo pero se continua localmente: $e');
    }
    await _clearLocalData();
  }

  Future<void> forceLogout() async {
    log('AUTH: force logout local');
    await _clearLocalData();
  }

  Future<void> _clearLocalData() async {
    try {
      final storage = ref.read(secureStorageProvider);
      await storage.delete(key: 'jwt_token');
      log('AUTH: token eliminado de secure storage');
    } catch (e) {
      log('AUTH: error al borrar token: $e');
    }

    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      user: null,
      errorMessage: null,
    );
  }
}
