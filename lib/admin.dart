import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'tesoro.dart';
import 'user.dart';
import 'login.dart';

class AdminScreen extends StatefulWidget {
  final UserModel user;

  const AdminScreen({super.key, required this.user});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Login()),
            (Route<dynamic> route) => false,
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() { _selectedIndex = index; });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _widgetOptions = <Widget>[
      TreasuresMapView(adminUser: widget.user),
      const TreasuresListView(),
      ProfileEditView(user: widget.user),
    ];

    final List<String> _titles = [
      'Ruta Inteligente (200m)',
      'Inventario de Tesoros',
      'Mi Perfil'
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: const Color(0xFF91B1A8),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF91B1A8)),
              accountName: Text(widget.user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text(widget.user.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  widget.user.username.isNotEmpty ? widget.user.username[0].toUpperCase() : 'A',
                  style: const TextStyle(fontSize: 40.0, color: Color(0xFF91B1A8)),
                ),
              ),
            ),
            ListTile(leading: const Icon(Icons.map), title: const Text('Mapa y Rutas'), selected: _selectedIndex == 0, onTap: () => _onItemTapped(0)),
            ListTile(leading: const Icon(Icons.list_alt), title: const Text('Lista Detallada'), selected: _selectedIndex == 1, onTap: () => _onItemTapped(1)),
            ListTile(leading: const Icon(Icons.person), title: const Text('Modificar Perfil'), selected: _selectedIndex == 2, onTap: () => _onItemTapped(2)),
            const Divider(),
            ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Cerrar Sesión'), onTap: _signOut),
          ],
        ),
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
    );
  }
}

// ---------------------------------------------------------------------------
// VISTA 1: MAPA CON RUTA INTELIGENTE (VECINO MÁS CERCANO + RADIO 200M)
// ---------------------------------------------------------------------------
class TreasuresMapView extends StatefulWidget {
  final UserModel adminUser;
  const TreasuresMapView({super.key, required this.adminUser});

  @override
  State<TreasuresMapView> createState() => _TreasuresMapViewState();
}

class _TreasuresMapViewState extends State<TreasuresMapView> {
  final LatLng _tepicCenter = const LatLng(21.5114, -104.8947);
  final MapController _mapController = MapController();

  bool _showRoutes = false;
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStream;

  // Calculadora de distancias
  final Distance _distanceCalculator = const Distance();

  @override
  void initState() {
    super.initState();
    _checkLocationPermissions();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El GPS está desactivado')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _startListeningLocation();
  }

  void _startListeningLocation() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Actualizar cada 5 metros para mejor precisión de ruta
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position? position) {
        if (position != null) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
          });
        }
      },
    );
  }

  void _centerOnUser() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 16);
    } else {
      _checkLocationPermissions();
    }
  }

  // --- ALGORITMO DE RUTA (GREEDY / VECINO MÁS CERCANO) ---
  //
  List<LatLng> _calculateOptimizedRoute(List<TreasureModel> allTreasures) {
    if (_currentPosition == null) return [];

    // 1. Filtrar tesoros en radio de 200m
    List<TreasureModel> nearbyTreasures = allTreasures.where((t) {
      final pos = LatLng(t.location.latitude, t.location.longitude);
      // as(LengthUnit.Meter, p1, p2)
      final double meters = _distanceCalculator.as(LengthUnit.Meter, _currentPosition!, pos);
      return meters <= 200;
    }).toList();

    if (nearbyTreasures.isEmpty) return [];

    // 2. Ordenar ruta por distancia más corta entre puntos
    List<LatLng> optimizedPath = [];

    // Empezamos en la posición del usuario
    LatLng currentLocation = _currentPosition!;
    optimizedPath.add(currentLocation);

    // Copia mutable para ir eliminando los visitados
    List<TreasureModel> pending = List.from(nearbyTreasures);

    while (pending.isNotEmpty) {
      // Buscar el más cercano al punto actual
      TreasureModel? nearest;
      double minDistance = double.infinity;

      for (var t in pending) {
        final tPos = LatLng(t.location.latitude, t.location.longitude);
        final dist = _distanceCalculator.as(LengthUnit.Meter, currentLocation, tPos);

        if (dist < minDistance) {
          minDistance = dist;
          nearest = t;
        }
      }

      if (nearest != null) {
        final nearestPos = LatLng(nearest.location.latitude, nearest.location.longitude);
        optimizedPath.add(nearestPos); // Agregar al camino
        currentLocation = nearestPos;  // Movernos ahí mentalmente
        pending.remove(nearest);       // Quitar de pendientes
      }
    }

    return optimizedPath;
  }

  // --- UI CRUD (Sin cambios mayores) ---
  void _showTreasureForm(BuildContext context, {LatLng? location, TreasureModel? treasureToEdit}) {
    final isEditing = treasureToEdit != null;
    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController(text: isEditing ? treasureToEdit.title : '');
    final descController = TextEditingController(text: isEditing ? treasureToEdit.description : '');
    String difficulty = isEditing ? treasureToEdit.difficulty : 'Medio';
    bool isLimited = isEditing ? treasureToEdit.isLimitedTime : false;

    final LatLng finalLocation = isEditing
        ? LatLng(treasureToEdit.location.latitude, treasureToEdit.location.longitude)
        : (location ?? _tepicCenter);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Editar Tesoro' : 'Nuevo Tesoro'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ubicación: ${finalLocation.latitude.toStringAsFixed(5)}, ${finalLocation.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Título'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                    TextFormField(controller: descController, decoration: const InputDecoration(labelText: 'Descripción'), maxLines: 2),
                    DropdownButtonFormField<String>(value: difficulty, items: ['Fácil', 'Medio', 'Difícil'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setDialogState(() => difficulty = v!), decoration: const InputDecoration(labelText: 'Dificultad')),
                    SwitchListTile(title: const Text('Tiempo Limitado'), value: isLimited, onChanged: (v) => setDialogState(() => isLimited = v)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final data = {
                      'title': titleController.text.trim(),
                      'description': descController.text.trim(),
                      'difficulty': difficulty,
                      'isLimitedTime': isLimited,
                      'location': GeoPoint(finalLocation.latitude, finalLocation.longitude),
                      'creatorUid': widget.adminUser.uid,
                      if (!isEditing) 'creationDate': Timestamp.now(),
                    };
                    if (isEditing) {
                      await FirebaseFirestore.instance.collection('treasures').doc(treasureToEdit.id).update(data);
                    } else {
                      await FirebaseFirestore.instance.collection('treasures').add(data);
                    }
                    if (mounted) Navigator.pop(ctx);
                  }
                },
                child: Text(isEditing ? 'Guardar' : 'Crear'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTreasureDetails(TreasureModel treasure) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(treasure.title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(treasure.description), const SizedBox(height: 10), Chip(label: Text('Dificultad: ${treasure.difficulty}'))]),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); _showTreasureForm(context, treasureToEdit: treasure); }, child: const Text('Editar')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await FirebaseFirestore.instance.collection('treasures').doc(treasure.id).delete(); if(mounted) Navigator.pop(ctx); }, child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF8992D7),
        unselectedItemColor: Colors.grey,
        currentIndex: _showRoutes ? 1 : 0,
        onTap: (index) {
          if (index == 1 && _currentPosition == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Necesitas activar el GPS para trazar rutas')));
          }
          setState(() => _showRoutes = (index == 1));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Explorar Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Ruta Cercana (200m)'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: _centerOnUser,
        child: const Icon(Icons.my_location, color: Colors.blueAccent),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('treasures').snapshots(),
            builder: (context, snapshot) {
              List<Marker> markers = [];
              List<TreasureModel> allTreasures = [];
              List<LatLng> routePoints = [];

              if (snapshot.hasData) {
                // 1. Parsear todos los tesoros
                allTreasures = snapshot.data!.docs.map((doc) {
                  return TreasureModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                }).toList();

                // 2. Crear marcadores visuales
                markers = allTreasures.map((t) {
                  return Marker(
                    point: LatLng(t.location.latitude, t.location.longitude),
                    width: 60,
                    height: 60,
                    child: GestureDetector(onTap: () => _showTreasureDetails(t), child: const Icon(Icons.location_on, color: Colors.red, size: 50)),
                  );
                }).toList();

                // 3. CALCULAR RUTA (Si está activo el modo y hay GPS)
                if (_showRoutes && _currentPosition != null) {
                  routePoints = _calculateOptimizedRoute(allTreasures);
                }
              }

              // Marcador de usuario
              if (_currentPosition != null) {
                markers.add(Marker(point: _currentPosition!, width: 50, height: 50, child: Container(decoration: BoxDecoration(color: Colors.blue.withOpacity(0.3), shape: BoxShape.circle), child: const Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 40))));
              }

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _tepicCenter,
                  initialZoom: 14,
                  onTap: (tapPosition, point) => _showTreasureForm(context, location: point),
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.geohunt.app'),

                  // Capa visual del radio de 200m (Círculo)
                  if (_showRoutes && _currentPosition != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _currentPosition!,
                          radius: 200, // 200 metros de radio visual (Aprox, flutter_map usa pixeles o metros segun config, para precision real visual se necesita un plugin extra, pero esto es aproximado para UI)
                          useRadiusInMeter: true,
                          color: Colors.blueAccent.withOpacity(0.1),
                          borderColor: Colors.blueAccent,
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),

                  // La línea de la ruta
                  if (_showRoutes && routePoints.isNotEmpty)
                    PolylineLayer(polylines: [Polyline(points: routePoints, strokeWidth: 5.0, color: Colors.deepPurpleAccent, isDotted: true)]),

                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),
          if (_showRoutes)
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Ruta Inteligente (200m)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    if (_currentPosition == null)
                      const Text("Esperando GPS...", style: TextStyle(fontSize: 12, color: Colors.orange))
                    else
                      const Text("Buscando la ruta más corta...", style: TextStyle(fontSize: 10, color: Colors.grey)),
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
// RESTO DEL CÓDIGO IGUAL (Vistas 2 y 3)
// ---------------------------------------------------------------------------
class TreasuresListView extends StatelessWidget {
  const TreasuresListView({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('treasures').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay tesoros.'));
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final t = TreasureModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(title: Text(t.title), subtitle: Text(t.difficulty), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseFirestore.instance.collection('treasures').doc(t.id).delete())),
            );
          },
        );
      },
    );
  }
}

class ProfileEditView extends StatefulWidget {
  final UserModel user;
  const ProfileEditView({super.key, required this.user});
  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  late TextEditingController _usernameController;
  bool _isLoading = false;
  @override
  void initState() { super.initState(); _usernameController = TextEditingController(text: widget.user.username); }
  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try { await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({'username': _usernameController.text.trim()}); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [const Icon(Icons.admin_panel_settings, size: 80, color: Color(0xFF91B1A8)), const SizedBox(height: 20), TextField(enabled: false, controller: TextEditingController(text: widget.user.email), decoration: const InputDecoration(labelText: 'Correo')), const SizedBox(height: 20), TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Nombre')), const SizedBox(height: 30), ElevatedButton(onPressed: _isLoading ? null : _updateProfile, child: const Text('Guardar'))]));
  }
}