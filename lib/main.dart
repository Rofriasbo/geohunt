import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geohunt/notificaciones.dart';
import 'firebase_options.dart'; // Asegúrate de que este archivo exista (generado por FlutterFire)
import 'login.dart';

// Handler para Segundo Plano (Fuera de cualquier clase)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Notificación en 2do plano recibida: ${message.messageId}");
}
// 1. Convertimos el main en asíncrono para esperar a Firebase
void main() async {
  // 2. Aseguramos que los widgets estén listos antes de iniciar Firebase
  WidgetsFlutterBinding.ensureInitialized();
await iniciarNotificaciones();
  // 3. Inicializamos Firebase usando las opciones de tu plataforma
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await iniciarNotificaciones();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 4. Una vez inicializado, arrancamos la app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoHunt',
      debugShowCheckedModeBanner: false, // Quita la etiqueta "DEBUG"
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF91B1A8)),
        useMaterial3: true,
      ),
      // 5. Aquí definimos que la pantalla de inicio es el Login
      home: const Login(),
    );
  }
}