import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:go_router/go_router.dart';
import '../../domain/user.dart';
import '../providers/auth_provider.dart';
import '../widgets/profile_screen/edit_profile_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'MI PERFIL',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildAvatar(context, user),
            const SizedBox(height: 24),
            _buildInfoCard(
              'NOMBRE COMPLETO',
              user?.nombre ?? 'No disponible',
              Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              'CORREO ELECTRÓNICO',
              user?.correo ?? 'No disponible',
              Icons.email_outlined,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              'TELÉFONO',
              user?.telefono ?? 'No disponible',
              Icons.phone_outlined,
            ),
            const SizedBox(height: 40),
            _buildLogoutButton(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, User? user) {
    final name = user?.nombre ?? 'U';
    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF1E293B),
              child: Text(
                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                if (user != null) {
                  showDialog(
                    context: context,
                    builder: (context) => EditProfileDialog(user: user),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent),
        ),
        onPressed: () async {
          log('🖱️ UI: Botón de logout presionado');

          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text(
                '¿Cerrar Sesión?',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                '¿Estás seguro de que deseas salir de tu cuenta?',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'CERRAR SESIÓN',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true && context.mounted) {
            // Mostrar SnackBar de despedida
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cerrando sesión...'),
                backgroundColor: Color(0xFF1E293B),
                duration: Duration(seconds: 1),
              ),
            );

            await ref.read(authProvider.notifier).logout();
          }
        },
        child: const Text('CERRAR SESIÓN'),
      ),
    );
  }
}
