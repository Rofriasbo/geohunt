import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

Future iniciarNotificaciones() async{
  const AndroidInitializationSettings AIS = AndroidInitializationSettings('ic_launcher');

  const InitializationSettings IS = InitializationSettings(
    android: AIS
  );

await plugin.initialize(IS);
  final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
  plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  final bool? aceptado = await androidImplementation?.requestNotificationsPermission();

  if (aceptado != null) {
    if (aceptado) {
      print("Permiso de notificaciones concedido.");
    } else {
      print("Permiso de notificaciones denegado.");
    }
  }
}


Future mostrarNotificacion(String titulo, String info, String icono) async{
  final AndroidNotificationDetails AND = AndroidNotificationDetails(
      'DAM2025',
      'Multiplataforma',
       importance: Importance.max,
       priority: Priority.high,
       icon: icono
  );

  final NotificationDetails notificationDetails = NotificationDetails(
    android: AND
  );
await plugin.show(1, titulo, info, notificationDetails);
}