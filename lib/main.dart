import 'dart:developer';
import 'dart:io' as dart_io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'core/router/app_router.dart';

import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyHttpOverrides extends dart_io.HttpOverrides {
  @override
  dart_io.HttpClient createHttpClient(dart_io.SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (dart_io.X509Certificate cert, String host, int port) => true;
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capturar errores de Flutter
  FlutterError.onError = (details) {
    log('❌ FLUTTER ERROR: ${details.exception}');
    log('📜 STACK: ${details.stack}');
    FlutterError.presentError(details);
  };

  // Ignorar errores de certificado SSL por el guion bajo en el dominio (solo móvil)
  if (!kIsWeb) {
    dart_io.HttpOverrides.global = MyHttpOverrides();
  }

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      log('❌ Firebase initialize error: $e');
    }
  } else {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      log('⚠️ Firebase not initialized on Web: $e');
    }
  }

  await dotenv.load(fileName: ".env");

  // Stripe Initialization (solo móvil)
  if (!kIsWeb) {
    Stripe.publishableKey =
        dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? "pk_test_placeholder";
    try {
      await Stripe.instance.applySettings();
    } catch (e) {
      log('❌ Stripe initialize error: $e');
    }
  }

  final container = ProviderContainer();
  try {
    await container
        .read(notificationServiceProvider)
        .initialize(scaffoldMessengerKey);
  } catch (e) {
    log('⚠️ Notification service initialization skipped or failed: $e');
  }

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Smart Mechanic',
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
