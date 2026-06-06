import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_screen/login_background.dart';
import '../widgets/login_screen/login_header.dart';
import '../widgets/login_screen/login_form.dart';
import '../widgets/login_screen/login_footer.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    await ref.read(authProvider.notifier).login(
      _emailController.text,
      _passwordController.text,
    );
    
    if (mounted) {
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.authenticated) {
        _showSnackBar('Sesión iniciada correctamente.', Colors.blueAccent);
      } else {
        _showSnackBar(
          authState.errorMessage ??
              'No se pudo iniciar sesión. Verifica tus credenciales e intenta de nuevo.',
          Colors.redAccent,
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const LoginBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  const LoginHeader(),
                  LoginForm(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    isLoading: _isLoading,
                    onLogin: _handleLogin,
                  ),
                  const LoginFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
