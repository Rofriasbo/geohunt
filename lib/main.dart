import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Asegúrate de que este archivo exista (generado por FlutterFire)
import 'login.dart';

// 1. Convertimos el main en asíncrono para esperar a Firebase
void main() async {
  // 2. Aseguramos que los widgets estén listos antes de iniciar Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Inicializamos Firebase usando las opciones de tu plataforma
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