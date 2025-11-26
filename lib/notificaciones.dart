import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

Future iniciarNotificaciones() async {
  const AndroidInitializationSettings AIS = AndroidInitializationSettings('@mipmap/ic_launcher'); // Usa @mipmap para asegurar que lo encuentre

  const InitializationSettings IS = InitializationSettings(
      android: AIS
  );

  await plugin.initialize(IS);

  final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
  plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  if (androidImplementation != null) {
    await androidImplementation.requestNotificationsPermission();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'treasure_alerts', // ID (Igual al Backend)
      'Alertas de Tesoros', // Nombre
      description: 'Notificaciones cuando aparece un tesoro cerca',
      importance: Importance.max,
      playSound: true,
    );

    await androidImplementation.createNotificationChannel(channel);
  }
}

    Future mostrarNotificacion(String titulo, String info, String icono, {DateTime? fechaLimite}) async {
    final bool usarCronometro = fechaLimite != null;
    final int? tiempoObjetivo = fechaLimite?.millisecondsSinceEpoch;

    int? tiempoRestante;
    if (fechaLimite != null) {
    tiempoRestante = fechaLimite.difference(DateTime.now()).inMilliseconds;
    if (tiempoRestante < 0) tiempoRestante = 0;
    }

    final AndroidNotificationDetails AND = AndroidNotificationDetails(
    'treasure_alerts', // <--- 1. ASEGURA QUE ESTO COINCIDA CON EL MANIFEST
    'Alertas de Tesoros',
    channelDescription: 'Notificaciones de tesoros cercanos',
    importance: Importance.max,
    priority: Priority.high,

    // Configuración visual
    icon: icono, // Asegúrate de pasar 'tesoro' (sin .png)

    // Configuración de Tiempo
    usesChronometer: usarCronometro,
    chronometerCountDown: true,
    when: tiempoObjetivo,
    timeoutAfter: tiempoRestante,

    // --- CORRECCIÓN DEL ERROR DE LED ---
    enableLights: true,
    color: const Color.fromARGB(255, 255, 0, 0),
    ledColor: const Color.fromARGB(255, 255, 0, 0),
    ledOnMs: 1000,
    ledOffMs: 500,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
    android: AND,
    );

    await plugin.show(1, titulo, info, notificationDetails);

    }