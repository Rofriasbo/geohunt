
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geohunt/notificaciones.dart';
import 'database_service.dart';

class FCMService {
  // Instancia de Firebase Messaging y DatabaseService
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final DatabaseService _dbService = DatabaseService();

  /**
   * Configura los permisos, obtiene el token FCM del dispositivo
   * y lo guarda en el documento del usuario en Firestore.
   */
  Future<void> setupFCMToken(String uid) async {
    // 1. Solicitar Permisos
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false, // Pedir permisos completos
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Permiso de notificaciones concedido. Iniciando FCM...');

      // 2. Obtener el Token
      String? token = await _fcm.getToken();

      if (token != null) {
        print("FCM Token Obtenido: $token");

        // 3. Guardar el token en Firestore
        await _dbService.saveFCMToken(uid, token);

        // 4. Escuchar si el token se actualiza
        _fcm.onTokenRefresh.listen((newToken) {
          _dbService.saveFCMToken(uid, newToken);
        });
      }
    } else {
      print('Permiso de notificaciones denegado. Las notificaciones Push no funcionarán.');
    }
  }
  void initForegroundNotifications() {
   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
     mostrarNotificacion(
       message.notification!.title ?? 'Notificación',
       message.notification!.body ?? 'Hay un tesoro cerca de tu zona.',
       'tesoro',
     );   });
 }
}