import 'dart:async';
import 'dart:io';
import 'dart:math'; // Para Shake
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart'; // IMPORTANTE: Sensores
import 'package:vibration/vibration.dart';
import 'database_service.dart';
import 'fcm_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'login.dart';
import 'notificaciones.dart';
import 'user.dart';
import 'tesoro.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Paleta de colores global
const Color primaryColor = Color(0xFF91B1A8);
const Color backgroundColor = Color(0xFF97AAA6);
const Color secondaryColor = Color(0xFF8992D7);
const Color accentColor = Color(0xFF8CB9AC);
const Color cardColor = Color(0xFFE6F2EF);

class WelcomeScreen extends StatefulWidget {
  final String username;
  const WelcomeScreen({super.key, required this.username});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();


  int _selectedIndex = 0;
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  // ...colores globales...

  Future<void> saveFCMTokenAndLocation(String uid) async {
    final DatabaseService dbService = DatabaseService();

    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await dbService.updateUser(uid, {
        'fcmToken': token,
      });
    }
     Position position = await Geolocator.getCurrentPosition();
  GeoPoint location = GeoPoint(position.latitude, position.longitude);
  await dbService.updateUser(uid, {
    'lastKnownLocation': location,
  });

  }

  void _initFCMListeners() {

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 Notificación recibida en Primer Plano: ${message.data}");

      String titulo = message.notification?.title ?? 'Alerta GeoHunt';
      String cuerpo = message.notification?.body ?? '¡Hay un tesoro cerca!';


      bool isLimited = message.data['isLimitedTime'] == 'true';


      DateTime? fechaLimite;

      if (message.data.containsKey('limitedUntil')) {
        try {
          int millis = int.parse(message.data['limitedUntil']);
          fechaLimite = DateTime.fromMillisecondsSinceEpoch(millis);
          print("⏳ Fecha límite detectada: $fechaLimite");
        } catch (e) {
          print("⚠️ Error parseando fecha limite: $e");
        }
      }
      mostrarNotificacion(
          titulo,
          cuerpo,
          'tesoro',
          fechaLimite: fechaLimite
      );
    });


    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('👆 Usuario tocó la notificación (Background)');
      // Aquí puedes agregar lógica para navegar al mapa y centrar el tesoro
    });


    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App iniciada desde notificación (Terminated): ${message.data}');
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() { _selectedIndex = index; });
  }
  final FCMService _fcmService = FCMService();

  @override
  void initState() {
    super.initState();
    _fcmService.setupFCMToken(_currentUid);
    _fcmService.initForegroundNotifications();
    _initFCMListeners();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_currentUid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final data = snapshot.data!.data() as Map<String, dynamic>;
        UserModel currentUser = UserModel.fromMap(data, _currentUid);

        final List<Widget> _widgetOptions = <Widget>[
          UserMapView(user: currentUser),
          const LeaderboardView(),
          UserProfileView(user: currentUser),
        ];

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text('GeoHunt Explorador', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22)),
            backgroundColor: primaryColor,
            elevation: 4,
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const Login()), (route) => false);
                },
              )
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [backgroundColor, accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _widgetOptions.elementAt(_selectedIndex),
          ),
          bottomNavigationBar: CurvedNavigationBar(
            key: _bottomNavigationKey,
            index: _selectedIndex,
            backgroundColor: Colors.transparent, //COLOR DE FONDO
            buttonBackgroundColor: Colors.white, //COLOR CIRCULAR DEL ICONO
            color: Colors.deepPurple, //COLOR DE LA BARRA
            animationCurve: Curves.linear,
            animationDuration: Duration(milliseconds: 300),
            height: 50,
            items: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, color: Colors.white70),
                  Text('Cazar', style: TextStyle(color: Colors.white70, fontSize: 9)),
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, color: Colors.white70),
                  Text('Top 10', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, color: Colors.white70),
                  Text('Perfil', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ],
            onTap: _onItemTapped,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// VISTA 1: MAPA DEL USUARIO (Visualización de Tesoros + Fotos)
// ---------------------------------------------------------------------------
class UserMapView extends StatefulWidget {
  final UserModel user;
  const UserMapView({super.key, required this.user});

  @override
  State<UserMapView> createState() => _UserMapViewState();
}

class _UserMapViewState extends State<UserMapView> {
  final LatLng _tepicCenter = const LatLng(21.5114, -104.8947);
  final MapController _mapController = MapController();
  final Distance _distanceCalculator = const Distance();
  final DatabaseService _dbService = DatabaseService();

  bool _showRoute = false;
  LatLng? _currentPosition;

  StreamSubscription<Position>? _positionStream;
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription<QuerySnapshot>? _treasuresSubscription; // Para escuchar los tesoros
  List<TreasureModel> _allTreasures = []; // Guardamos los tesoros aquí
  TreasureModel? _treasureInRange;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermissions();
    _initSensor();
    _listenToTreasures();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  void _listenToTreasures() {
    _treasuresSubscription = FirebaseFirestore.instance.collection('treasures').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _allTreasures = snapshot.docs.map((d) => TreasureModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
        });
      }
    });
  }

  // --- 1. SENSOR SHAKE ---
  void _initSensor() {
    _accelerometerSubscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (acceleration > 15) {
        _onShakeDetected();
      }
    });
  }

  void _onShakeDetected() {
    // Solo reclamar si hay uno en rango y no se está procesando ya
    if (_treasureInRange != null && !_isClaiming) {
      _claimTreasure(_treasureInRange!);
    }
  }

  // --- 2. RECLAMAR TESORO ---
  Future<void> _claimTreasure(TreasureModel treasure) async {
    setState(() {
      _isClaiming = true;
    });
    try {
      // Referencias
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
      final treasureRef = FirebaseFirestore.instance.collection('treasures').doc(treasure.id);

      // Esto asegura que la operación sea atómica y verifique el estado real del servidor
      int pointsAwarded = await FirebaseFirestore.instance.runTransaction((transaction) async {

        DocumentSnapshot snapshot = await transaction.get(treasureRef);

        if (!snapshot.exists) {
          throw Exception("Este tesoro ya no existe (fue eliminado o expiró).");
        }

        // En lugar de leer campo por campo manualmente, usamos tu factory 'fromMap'.
        // Esto convierte automáticamente los Timestamps a DateTime gracias a tu modelo.
        final freshTreasure = TreasureModel.fromMap(
            snapshot.data() as Map<String, dynamic>,
            snapshot.id
        );

        int pointsToAdd = 0;
    switch (freshTreasure.difficulty) {
      case 'Fácil':
        pointsToAdd = 100;
        break;
      case 'Medio':
        pointsToAdd = 300;
        break;
      case 'Difícil':
        pointsToAdd = 500;
        break;
      default:
        pointsToAdd = 100;
    }

        // Lógica de Tiempo Límite (Usando el DateTime ya convertido del modelo)
        if (freshTreasure.isLimitedTime && freshTreasure.limitedUntil != null) {
          // Comparamos DateTime con DateTime (fácil y limpio)
          if (DateTime.now().isBefore(freshTreasure.limitedUntil!)) {
            pointsToAdd += 200;
          }
        }

        // Actualizamos Usuario
        transaction.update(userRef, {
          'score': FieldValue.increment(pointsToAdd),
          'foundTreasures': FieldValue.arrayUnion([freshTreasure.id]),
        });

        return pointsToAdd;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('¡TESORO ENCONTRADO! 🎉'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 60),
                const SizedBox(height: 10),
                Text('Has ganado $pointsAwarded puntos.'), // Usamos la variable retornada
                Text('Tesoro: ${treasure.title}'),
                // Nota: Aquí podrías simplificar el mensaje ya que la lógica fue interna
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Opcional: Refrescar el mapa aquí
                },
                child: const Text('¡Genial!'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      // --- ERROR (Tesoro borrado o error de red) ---
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Se te acabó el tiempo. Suerte para la próxima'),
            content: Text(e.toString().replaceAll("Exception: ", "")), // Limpiar mensaje
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClaiming = false;
          _treasureInRange = null; // Ocultar botón
        });
      }
    }
  }

  // --- 3. GPS ---
  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    _startListeningLocation();
  }

  void _startListeningLocation() {
    const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2
    );

    _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings
    ).listen((pos) { // Se ejecuta CADA VEZ que el GPS reporta una nueva posición
      if (mounted) {
        final newPosition = LatLng(pos.latitude, pos.longitude);

        final uncollected = _allTreasures.where((t) => !(widget.user.foundTreasures?.contains(t.id) ?? false)).toList();
        TreasureModel? foundInRange;

        for (var t in uncollected) {
          final double dist = _distanceCalculator.as(LengthUnit.Meter, newPosition, LatLng(t.location.latitude, t.location.longitude));
          if (dist <= 5) { // Si un tesoro está en el rango de 5 metros
            foundInRange = t;
            break;
          }
        }

        // Comprobamos si el tesoro en rango ha cambiado
        if (foundInRange?.id != _treasureInRange?.id) {

          if (foundInRange != null) {
            _vibratePhone();

            // 1. Verificamos si es temporal Y si la fecha es válida
            if (foundInRange!.isLimitedTime && foundInRange!.limitedUntil != null) {

              // CASO A: Tesoro con Tiempo Límite ⏳
              // Le pasamos la fecha para que Android muestre el cronómetro
              mostrarNotificacion(
                  '¡CORRE! Tesoro Temporal ⏳',
                  'Se acaba el tiempo. ¡Agita rápido para reclamar!',
                  'tesoro',
                  fechaLimite: foundInRange!.limitedUntil // <--- Pasamos la fecha aquí
              );

            } else {

              // CASO B: Tesoro Normal 🟢
              // No pasamos fecha, así que no mostrará cronómetro
              mostrarNotificacion(
                '¡Tesoro cerca! 🟢',
                'Agita tu teléfono para reclamar el tesoro',
                'tesoro',
              );

            }
          }
          setState(() {
            _treasureInRange = foundInRange;
          });
        }

        // Actualizamos la posición del usuario en el mapa y en la BD
        setState(() {
          _currentPosition = newPosition;
        });
        _saveLastKnownLocation(pos);
      }
    });
  }

  void _saveLastKnownLocation(Position position) {
    // 1. Convertir la posición de Geolocator a un GeoPoint de Firestore
    final GeoPoint geoPoint = GeoPoint(position.latitude, position.longitude);
    // 2. Usar el nuevo método updateUser para actualizar SOLO este campo
    _dbService.updateUser(
      widget.user.uid,
      // Solo actualiza 'lastKnownLocation'
      {'lastKnownLocation': geoPoint},
    );
  }

  void _centerOnUser() {
    if (_currentPosition != null) _mapController.move(_currentPosition!, 18);
  }

  // Ruta optimizada: Solo considera los NO encontrados para guiarte
  List<LatLng> _calculateOptimizedRoute(List<TreasureModel> uncollectedTreasures) {
    if (_currentPosition == null) return [];
    List<TreasureModel> nearby = uncollectedTreasures.where((t) => _distanceCalculator.as(LengthUnit.Meter, _currentPosition!, LatLng(t.location.latitude, t.location.longitude)) <= 200).toList();
    if (nearby.isEmpty) return [];
    List<LatLng> path = [_currentPosition!];
    LatLng current = _currentPosition!;
    List<TreasureModel> pending = List.from(nearby);
    while (pending.isNotEmpty) {
      TreasureModel? nearest; double minD = double.infinity;
      for (var t in pending) {
        double d = _distanceCalculator.as(LengthUnit.Meter, current, LatLng(t.location.latitude, t.location.longitude));
        if (d < minD) { minD = d; nearest = t; }
      }
      if (nearest != null) {
        LatLng p = LatLng(nearest.location.latitude, nearest.location.longitude);
        path.add(p); current = p; pending.remove(nearest);
      }
    }
    return path;
  }

  // DETALLES CON IMAGEN DE PISTA
  void _showTreasureDetails(TreasureModel t, bool isFound) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGEN SI EXISTE
            if (t.imageUrl != null && t.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(t.imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover),
                ),
              ),

            Text(t.description),
            const SizedBox(height: 10),

            if (isFound)
              const Chip(label: Text("YA ENCONTRADO"), backgroundColor: Colors.grey, labelStyle: TextStyle(color: Colors.white))
            else
              Chip(label: Text(t.difficulty), backgroundColor: t.difficulty == 'Difícil' ? Colors.red[100] : Colors.green[100]),

            if (t.isLimitedTime) const Chip(label: Text('¡Tiempo Limitado!'), backgroundColor: Colors.orangeAccent),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  Future<void> _vibratePhone() async {
    try {
      // 1. Verificar si el dispositivo puede vibrar
      bool canVibrate = await Vibration.hasVibrator() ?? false;

      if (canVibrate) {
        // 2. Patrón de vibración: Vibra por 500ms y luego pausa 200ms (un pulso rápido)
        Vibration.vibrate(duration: 500);
        // Si quieres un patrón de pulsos:
        // Vibration.vibrate(pattern: [0, 500, 200, 500]); // Pausa, Vibra, Pausa, Vibra
      }
    } catch (e) {
      print('Error al intentar vibrar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {

    List<Marker> markers = [];
    List<LatLng> routePoints = [];

    // Lógica que estaba en el builder, ahora usa el estado local
    final uncollectedTreasures = _allTreasures.where((t) => !(widget.user.foundTreasures?.contains(t.id) ?? false)).toList();

    markers = _allTreasures.map((t) {
      bool isFound = widget.user.foundTreasures?.contains(t.id) ?? false;
      Color markerColor;
      if (isFound) markerColor = Colors.grey;
      else if (t.id == _treasureInRange?.id) markerColor = Colors.green;
      else markerColor = Colors.red;

      return Marker(
        point: LatLng(t.location.latitude, t.location.longitude),
        width: 60, height: 60,
        child: GestureDetector(
          onTap: () => _showTreasureDetails(t, isFound),
          child: Icon(Icons.location_on, color: markerColor, size: 50),
        ),
      );
    }).toList();

    if (_showRoute && _currentPosition != null) {
      routePoints = _calculateOptimizedRoute(uncollectedTreasures);
    }

    if (_currentPosition != null) {
      markers.add(Marker(
          point: _currentPosition!,
          width: 50, height: 50,
          child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40)
      ));
    }

    return Scaffold(
      floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(heroTag: "routeBtn",
            backgroundColor: _showRoute ? Colors.deepPurple : Colors.white,
            onPressed: () => setState(() => _showRoute = !_showRoute),
            child: Icon(Icons.alt_route,
                color: _showRoute ? Colors.white : Colors.deepPurple)),
        const SizedBox(height: 10),
        FloatingActionButton(heroTag: "gpsBtn",
            onPressed: _centerOnUser,
            child: const Icon(Icons.my_location)),
      ]),


      body: Stack(
        children: [
          FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: _tepicCenter, initialZoom: 14),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.geohunt.app'),
            if (_showRoute && routePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: routePoints, strokeWidth: 5, color: Colors.deepPurple)]),
            if (_treasureInRange != null) CircleLayer(circles: [
              CircleMarker(
                  point: LatLng(_treasureInRange!.location.latitude, _treasureInRange!.location.longitude),
                  radius: 15, useRadiusInMeter: true, color: Colors.green.withOpacity(0.3),
                  borderColor: Colors.green, borderStrokeWidth: 2
              )
            ]),
            MarkerLayer(markers: markers),
          ],
    ),
          if (_treasureInRange != null)
            Positioned(
              top: 50, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.green,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 10)
                    ]),
                child: Column(
                  children: [
                    const Text("¡LISTO PARA CAZAR!", style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                    const SizedBox(height: 5),
                    Text("Agita tu teléfono para reclamar: ${_treasureInRange!
                        .title}", style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center),
                    const Icon(Icons.vibration, color: Colors.white, size: 40)
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VISTA 2: TOP 10 LEADERBOARD
// ---------------------------------------------------------------------------
class LeaderboardView extends StatelessWidget {
  Color getRankColor(int index, bool me) {
    if (me) return Colors.blue.shade300;
    if (index == 0) return Color(0xFFFFF3C4); // Oro suave
    if (index == 1) return Color(0xFFF0F0F0); // Plata suave
    if (index == 2) return Color(0xFFCE8C4E);       // Bronce
    return Colors.white;                            // Resto
  }

  // Widget para mostrar el número o la medalla
  Widget getRankWidget(int index) {
    if (index == 0) return Text("🥇", style: TextStyle(fontSize: 24));
    if (index == 1) return Text("🥈", style: TextStyle(fontSize: 24));
    if (index == 2) return Text("🥉", style: TextStyle(fontSize: 24));

    // Para el puesto 4 en adelante, un círculo gris con el número
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        "${index + 1}",
        style: TextStyle(fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            fontSize: 12),
      ),
    );
  }
  const LeaderboardView({super.key});
  @override
  Widget build(BuildContext context) {

    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            width: double.infinity,
            child: const Text("🏆 Mejores Cazadores", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'user').orderBy('score', descending: true).limit(10).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Aún no hay jugadores."));
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final bool userLogged = (snapshot.data!.docs[index].id == currentUid);
                    return Card(
                      color: getRankColor(index, userLogged),
                      elevation: index<3 ? 4 : 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: userLogged
                            ? const BorderSide(color: Colors.purple, width: 3) // Borde más grueso si es el usuario logueado
                            : BorderSide.none, // Sin borde para los demás
                      ),
                        child: ListTile(
                          // SECCIÓN IZQUIERDA: PUESTO + AVATAR
                          leading: SizedBox(
                            width: 80,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 1. El Widget del Puesto (Medalla o Número)
                                getRankWidget(index),

                                // 2. El Avatar con Borde de Color
                                Container(
                                  padding: const EdgeInsets.all(2), // Grosor del borde
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: index<3 ? getRankColor(index, userLogged) : Colors.transparent, // Color del borde
                                  ),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: data['profileImageUrl'] != null
                                        ? NetworkImage(data['profileImageUrl'])
                                        : null,
                                    child: data['profileImageUrl'] == null
                                        ? Text(data['username']?[0] ?? '?',
                                        style: TextStyle(
                                            color: Colors.grey.shade700, fontWeight: FontWeight.bold))
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // SECCIÓN CENTRAL: NOMBRE
                          title: Text(
                            data['username'] ?? 'Anónimo',
                            style: TextStyle(
                              fontWeight: index<3 ? FontWeight.bold : FontWeight.w600,
                              fontSize: index<3 ? 18 : 16, // Más grande para top 3
                              color: const Color(0xFF333333),
                            ),
                          ),

                          // SECCIÓN DERECHA: PUNTOS
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              // Si es Top 3, usa el color de su medalla, si no, el color secundario por defecto
                              color: index<3 ? getRankColor(index, userLogged) : Color(0xFF8992D7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${data['score'] ?? 0}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: index<3 ? Colors.black87 : Colors.white,
                              ),
                            ),
                          ),
                        ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VISTA 3: PERFIL DE USUARIO (OPTIMIZADO)
// ---------------------------------------------------------------------------
class UserProfileView extends StatefulWidget {
  final UserModel user;
  const UserProfileView({super.key, required this.user});
  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}
class _UserProfileViewState extends State<UserProfileView> {
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  // bool _isLoading = false; // No se usa
  String? _currentImageUrl;

  @override
  void initState() { super.initState(); _usernameController = TextEditingController(text: widget.user.username); _phoneController = TextEditingController(text: widget.user.phoneNumber ?? ''); _currentImageUrl = widget.user.profileImageUrl; }

  // OPTIMIZACIÓN DE IMAGEN DE PERFIL
  Future<void> _pickAndUploadImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 60, maxWidth: 512);
    if (image == null) return;
    // ...eliminado _isLoading...
    final ref = FirebaseStorage.instance.ref().child('profile_images').child('${widget.user.uid}.jpg');
    await ref.putFile(File(image.path), SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({'profileImageUrl': url});
    // ...eliminado _isLoading...
  }

  Future<void> _updateProfile() async {
    await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({'username': _usernameController.text, 'phoneNumber': _phoneController.text});
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundColor, accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Cabecera visual con avatar y nombre
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [secondaryColor.withOpacity(0.18), accentColor.withOpacity(0.18)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        builder: (ctx) => Wrap(
                          children: [
                            ListTile(
                              leading: Icon(Icons.photo, color: secondaryColor),
                              title: const Text('Galería'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickAndUploadImage(ImageSource.gallery);
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.camera, color: secondaryColor),
                              title: const Text('Cámara'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickAndUploadImage(ImageSource.camera);
                              },
                            ),
                          ],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: accentColor,
                        backgroundImage: _currentImageUrl != null ? NetworkImage(_currentImageUrl!) : null,
                        child: _currentImageUrl == null ? const Icon(Icons.camera_alt, color: Colors.white, size: 38) : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          colors: [secondaryColor, primaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: Text(
                        widget.user.username,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black26, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Card de estadísticas con iconos
            Card(
              color: cardColor,
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              margin: const EdgeInsets.only(bottom: 18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Icon(Icons.star, color: secondaryColor, size: 28),
                        const SizedBox(height: 4),
                        const Text('Puntaje', style: TextStyle(color: Colors.grey)),
                        Text('${widget.user.score}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: secondaryColor)),
                      ],
                    ),
                    Container(height: 40, width: 1, color: Colors.grey[300]),
                    Column(
                      children: [
                        Icon(Icons.emoji_events, color: secondaryColor, size: 28),
                        const SizedBox(height: 4),
                        const Text('Tesoros', style: TextStyle(color: Colors.grey)),
                        Text('${widget.user.foundTreasures?.length ?? 0}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: secondaryColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Inputs modernos
            const SizedBox(height: 10),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Nombre',
                labelStyle: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: secondaryColor), borderRadius: BorderRadius.circular(14)),
                prefixIcon: Icon(Icons.person, color: accentColor),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Teléfono',
                labelStyle: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: secondaryColor), borderRadius: BorderRadius.circular(14)),
                prefixIcon: Icon(Icons.phone, color: accentColor),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    elevation: 3,
                  ),
                  onPressed: _updateProfile,
                  child: const Text('Guardar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}