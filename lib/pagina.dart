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
import 'package:sensors_plus/sensors_plus.dart';
import 'login.dart';
import 'user.dart';
import 'tesoro.dart';

class WelcomeScreen extends StatefulWidget {
  final String username;
  const WelcomeScreen({super.key, required this.username});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _selectedIndex = 0;
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  static const Color primaryColor = Color(0xFF91B1A8);
  static const Color backgroundColor = Color(0xFF97AAA6);
  static const Color secondaryColor = Color(0xFF8992D7);

  void _onItemTapped(int index) {
    setState(() { _selectedIndex = index; });
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
            title: const Text('GeoHunt Explorador', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: primaryColor,
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const Login()), (route) => false);
                },
              )
            ],
          ),
          body: _widgetOptions.elementAt(_selectedIndex),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Cazar'),
              BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Top 10'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: secondaryColor,
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            backgroundColor: Colors.white,
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

  bool _showRoute = false;
  LatLng? _currentPosition;

  StreamSubscription<Position>? _positionStream;
  StreamSubscription? _accelerometerSubscription;

  TreasureModel? _treasureInRange;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermissions();
    _initSensor();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  void _initSensor() {
    _accelerometerSubscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (acceleration > 15) {
        _onShakeDetected();
      }
    });
  }

  void _onShakeDetected() {
    if (_treasureInRange != null && !_isClaiming) {
      _claimTreasure(_treasureInRange!);
    }
  }

  Future<void> _claimTreasure(TreasureModel treasure) async {
    setState(() { _isClaiming = true; });

    int pointsToAdd = 0;
    switch (treasure.difficulty) {
      case 'Fácil': pointsToAdd = 100; break;
      case 'Medio': pointsToAdd = 300; break;
      case 'Difícil': pointsToAdd = 500; break;
      default: pointsToAdd = 100;
    }
    if (treasure.isLimitedTime) pointsToAdd += 200;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(widget.user.uid);

      batch.update(userRef, {
        'score': FieldValue.increment(pointsToAdd),
        'foundTreasures': FieldValue.arrayUnion([treasure.id])
      });

      await batch.commit();

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
                Text('Has ganado $pointsToAdd puntos.'),
                Text('Tesoro: ${treasure.title}'),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('¡Genial!'))],
          ),
        );
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isClaiming = false;
          _treasureInRange = null;
        });
      }
    }
  }

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
    const LocationSettings locationSettings = LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 2);
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
      if (mounted) {
        setState(() { _currentPosition = LatLng(pos.latitude, pos.longitude); });
      }
    });
  }

  void _centerOnUser() {
    if (_currentPosition != null) _mapController.move(_currentPosition!, 18);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(heroTag: "routeBtn", backgroundColor: _showRoute ? Colors.deepPurple : Colors.white, onPressed: () => setState(() => _showRoute = !_showRoute), child: Icon(Icons.alt_route, color: _showRoute ? Colors.white : Colors.deepPurple)),
        const SizedBox(height: 10),
        FloatingActionButton(heroTag: "gpsBtn", onPressed: _centerOnUser, child: const Icon(Icons.my_location)),
      ]),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('treasures').snapshots(),
            builder: (context, snapshot) {
              List<Marker> markers = [];
              List<LatLng> routePoints = [];
              TreasureModel? closestTreasure;

              if (snapshot.hasData) {
                final allDocs = snapshot.data!.docs;
                final allTreasures = allDocs.map((d) => TreasureModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();

                final uncollectedTreasures = allTreasures.where((t) => !(widget.user.foundTreasures?.contains(t.id) ?? false)).toList();

                if (_currentPosition != null) {
                  for (var t in uncollectedTreasures) {
                    final double dist = _distanceCalculator.as(LengthUnit.Meter, _currentPosition!, LatLng(t.location.latitude, t.location.longitude));
                    if (dist <= 5) {
                      closestTreasure = t;
                      if (_treasureInRange != t) {
                        WidgetsBinding.instance.addPostFrameCallback((_) { setState(() { _treasureInRange = t; }); });
                      }
                    }
                  }
                  if (closestTreasure == null && _treasureInRange != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) { setState(() { _treasureInRange = null; }); });
                  }
                }

                markers = allTreasures.map((t) {
                  bool isFound = widget.user.foundTreasures?.contains(t.id) ?? false;
                  Color markerColor;
                  IconData markerIcon;

                  if (isFound) {
                    markerColor = Colors.grey;
                    markerIcon = Icons.check_circle;
                  } else if (t == _treasureInRange) {
                    markerColor = Colors.green;
                    markerIcon = Icons.location_on;
                  } else {
                    markerColor = Colors.red;
                    markerIcon = Icons.location_on;
                  }

                  return Marker(
                    point: LatLng(t.location.latitude, t.location.longitude),
                    width: 60, height: 60,
                    child: GestureDetector(
                      onTap: () => _showTreasureDetails(t, isFound),
                      child: Icon(markerIcon, color: markerColor, size: 50),
                    ),
                  );
                }).toList();

                if (_showRoute && _currentPosition != null) {
                  routePoints = _calculateOptimizedRoute(uncollectedTreasures);
                }
              }

              if (_currentPosition != null) {
                markers.add(Marker(point: _currentPosition!, width: 50, height: 50, child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40)));
              }

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: _tepicCenter, initialZoom: 14),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.geohunt.app'),
                  if (_showRoute && routePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: routePoints, strokeWidth: 5, color: Colors.deepPurple)]),
                  if (_treasureInRange != null && _currentPosition != null)
                    CircleLayer(circles: [
                      CircleMarker(
                          point: LatLng(_treasureInRange!.location.latitude, _treasureInRange!.location.longitude),
                          radius: 15,
                          useRadiusInMeter: true,
                          color: Colors.green.withOpacity(0.3),
                          borderColor: Colors.green,
                          borderStrokeWidth: 2
                      )
                    ]),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),

          if (_treasureInRange != null)
            Positioned(
              top: 50, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
                child: Column(
                  children: [
                    const Text("¡LISTO PARA CAZAR!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 5),
                    Text("Agita tu teléfono para reclamar: ${_treasureInRange!.title}", style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
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
  const LeaderboardView({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(20), color: const Color(0xFF8CB9AC), width: double.infinity, child: const Text("🏆 Mejores Cazadores", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
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
                    return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: ListTile(
                      leading: CircleAvatar(backgroundImage: data['profileImageUrl'] != null ? NetworkImage(data['profileImageUrl']) : null, child: data['profileImageUrl'] == null ? Text(data['username']?[0] ?? '?') : null),
                      title: Text(data['username'] ?? 'Anónimo'),
                      trailing: Text("${data['score'] ?? 0} pts", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    ));
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
  bool _isLoading = false;
  String? _currentImageUrl;

  @override
  void initState() { super.initState(); _usernameController = TextEditingController(text: widget.user.username); _phoneController = TextEditingController(text: widget.user.phoneNumber ?? ''); _currentImageUrl = widget.user.profileImageUrl; }

  // OPTIMIZACIÓN DE IMAGEN DE PERFIL
  Future<void> _pickAndUploadImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 60, maxWidth: 512);
    if (image == null) return;
    setState(()=>_isLoading=true);
    final ref = FirebaseStorage.instance.ref().child('profile_images').child('${widget.user.uid}.jpg');
    await ref.putFile(File(image.path), SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({'profileImageUrl': url});
    setState(()=>_isLoading=false);
  }

  Future<void> _updateProfile() async {
    await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({'username': _usernameController.text, 'phoneNumber': _phoneController.text});
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      GestureDetector(onTap: () => showModalBottomSheet(context: context, builder: (ctx)=>Wrap(children: [ListTile(leading: const Icon(Icons.photo), title: const Text('Galería'), onTap: (){Navigator.pop(ctx); _pickAndUploadImage(ImageSource.gallery);}), ListTile(leading: const Icon(Icons.camera), title: const Text('Cámara'), onTap: (){Navigator.pop(ctx); _pickAndUploadImage(ImageSource.camera);})])), child: CircleAvatar(radius: 60, backgroundImage: _currentImageUrl!=null?NetworkImage(_currentImageUrl!):null, child: _currentImageUrl==null?const Icon(Icons.camera_alt):null)),
      const SizedBox(height: 20),
      Card(elevation: 4, child: Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Column(children: [const Text('Puntaje', style: TextStyle(color: Colors.grey)), Text('${widget.user.score}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF8992D7)))]), Container(height: 30, width: 1, color: Colors.grey), Column(children: [const Text('Tesoros', style: TextStyle(color: Colors.grey)), Text('${widget.user.foundTreasures?.length ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF8992D7)))])]))),
      const SizedBox(height: 20),
      TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Nombre')), const SizedBox(height: 10), TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Teléfono')), const SizedBox(height: 20), ElevatedButton(onPressed: _updateProfile, child: const Text('Guardar'))
    ]));
  }
}