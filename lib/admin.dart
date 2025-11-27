import 'dart:async';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'tesoro.dart';
import 'admin_model.dart';
import 'user.dart';
import 'login.dart';

class AdminScreen extends StatefulWidget {
  final AdminModel adminUser;

  const AdminScreen({super.key, required this.adminUser});

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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.adminUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final currentAdmin = AdminModel.fromMap(data, widget.adminUser.uid);

        final List<Widget> _widgetOptions = <Widget>[
          TreasuresMapView(adminUid: currentAdmin.uid),
          // Índice 1: Lista de Tesoros
          const TreasuresListView(),
          // Índice 2: Exploradores
          const UsersListView(), // <-- AÑADIDO
          // Índice 3: Modificar Perfil
          ProfileEditView(adminUser: currentAdmin),
          // Índice 4: Manual de Usuario
          const AdminManualView(),
        ];

        final List<String> _titles = [
          'GEO HUNT - Mapa Admin',
          'Inventario de Tesoros',
          'Gestión de Exploradores',
          'Perfil Admin',
          'Manual de Usuario'
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _titles[_selectedIndex],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white,
                letterSpacing: 1.5,
                shadows: [Shadow(blurRadius: 16, color: Colors.black54, offset: Offset(0, 4))],
              ),
            ),
            backgroundColor: const Color(0xFF91B1A8),
            elevation: 6,
            centerTitle: true,
          ),
          drawer: Drawer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF91B1A8), Color(0xFF8992D7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.white,
                          backgroundImage: (currentAdmin.profileImageUrl != null && currentAdmin.profileImageUrl!.isNotEmpty)
                              ? NetworkImage(currentAdmin.profileImageUrl!)
                              : null,
                          child: (currentAdmin.profileImageUrl == null || currentAdmin.profileImageUrl!.isEmpty)
                              ? Text(
                            currentAdmin.username.isNotEmpty ? currentAdmin.username[0].toUpperCase() : 'A',
                            style: const TextStyle(fontSize: 32.0, color: Color(0xFF91B1A8)),
                          )
                              : null,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          currentAdmin.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ListTile(leading: const Icon(Icons.map, color: Colors.white), title: const Text('Mapa y Rutas', style: TextStyle(color: Colors.white)), selected: _selectedIndex == 0, onTap: () => _onItemTapped(0)),
                  ListTile(leading: const Icon(Icons.diamond, color: Colors.white), title: const Text('Lista de Tesoros', style: TextStyle(color: Colors.white)), selected: _selectedIndex == 1, onTap: () => _onItemTapped(1)),
                  ListTile(leading: const Icon(Icons.people, color: Colors.white), title: const Text('Exploradores', style: TextStyle(color: Colors.white)), selected: _selectedIndex == 2, onTap: () => _onItemTapped(2)),
                  ListTile(leading: const Icon(Icons.person, color: Colors.white), title: const Text('Modificar Perfil', style: TextStyle(color: Colors.white)), selected: _selectedIndex == 3, onTap: () => _onItemTapped(3)),
                  const Divider(color: Colors.white70),
                  ListTile(
                      leading: const Icon(Icons.menu_book, color: Color(0xFF8992D7)),
                      title: const Text('Manual de Usuario', style: TextStyle(color: Colors.white)),
                      selected: _selectedIndex == 4,
                      onTap: () => _onItemTapped(4)
                  ),
                  ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)), onTap: _signOut),
                ],
              ),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE6F2EF), Color(0xFF97AAA6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _widgetOptions.elementAt(_selectedIndex),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// VISTA 1: MAPA DE TESOROS (CRUD + FOTO OPTIMIZADA)
// ---------------------------------------------------------------------------
class TreasuresMapView extends StatefulWidget {
  final String adminUid;
  const TreasuresMapView({super.key, required this.adminUid});

  @override
  State<TreasuresMapView> createState() => _TreasuresMapViewState();
}

class _TreasuresMapViewState extends State<TreasuresMapView> {
  final LatLng _tepicCenter = const LatLng(21.5114, -104.8947);
  final MapController _mapController = MapController();
  final Distance _distanceCalculator = const Distance();

  bool _showRoutes = false;
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStream;

  File? _selectedTreasureImage;
  bool _isUploadingImage = false;

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
    const LocationSettings locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
      if (mounted) setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
    });
  }

  void _centerOnUser() {
    if (_currentPosition != null) _mapController.move(_currentPosition!, 16);
    else _checkLocationPermissions();
  }

  List<LatLng> _calculateOptimizedRoute(List<TreasureModel> allTreasures) {
    if (_currentPosition == null) return [];
    List<TreasureModel> nearby = allTreasures.where((t) => _distanceCalculator.as(LengthUnit.Meter, _currentPosition!, LatLng(t.location.latitude, t.location.longitude)) <= 200).toList();
    if (nearby.isEmpty) return [];
    List<LatLng> path = [_currentPosition!];
    LatLng current = _currentPosition!;
    List<TreasureModel> pending = List.from(nearby);
    while (pending.isNotEmpty) {
      TreasureModel? nearest;
      double minD = double.infinity;
      for (var t in pending) {
        double d = _distanceCalculator.as(LengthUnit.Meter, current, LatLng(t.location.latitude, t.location.longitude));
        if (d < minD) {
          minD = d;
          nearest = t;
        }
      }
      if (nearest != null) {
        LatLng p = LatLng(nearest.location.latitude, nearest.location.longitude);
        path.add(p);
        current = p;
        pending.remove(nearest);
      }
    }
    return path;
  }

  // --- LÓGICA DE IMAGEN DEL TESORO (OPTIMIZADA) ---
  Future<void> _pickTreasureImage(StateSetter setDialogState) async {
    final ImagePicker picker = ImagePicker();
    // OPTIMIZACIÓN: Max 1024px y Calidad 70% (Balance detalle/peso)
    final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024
    );

    if (image != null) {
      setDialogState(() {
        _selectedTreasureImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadTreasureImage(File imageFile) async {
    try {
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final storageRef = FirebaseStorage.instance.ref().child('treasure_images').child(fileName);
      // Metadatos para caché y tipo
      await storageRef.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint("Error subiendo imagen: $e");
      return null;
    }
  }

  void _showTreasureForm(BuildContext context, {LatLng? location, TreasureModel? treasureToEdit}) {
    final isEditing = treasureToEdit != null;
    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController(text: isEditing ? treasureToEdit.title : '');
    final descController = TextEditingController(text: isEditing ? treasureToEdit.description : '');
    String difficulty = isEditing ? treasureToEdit.difficulty : 'Medio';
    bool isLimited = isEditing ? treasureToEdit.isLimitedTime : false;

    _selectedTreasureImage = null;
    String? existingImageUrl = isEditing ? treasureToEdit.imageUrl : null;

    final LatLng finalLocation = isEditing
        ? LatLng(treasureToEdit.location.latitude, treasureToEdit.location.longitude)
        : (location ?? _tepicCenter);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool canAddPhoto = (difficulty == 'Fácil' || difficulty == 'Medio');

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
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Título'),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Descripción'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: difficulty,
                      decoration: const InputDecoration(labelText: 'Dificultad'),
                      items: ['Fácil', 'Medio', 'Difícil'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setDialogState(() {
                        difficulty = v!;
                        if (difficulty == 'Difícil') _selectedTreasureImage = null;
                      }),
                    ),
                    SwitchListTile(
                      title: const Text('Tiempo Limitado'),
                      value: isLimited,
                      onChanged: (v) => setDialogState(() => isLimited = v),
                    ),
                    const SizedBox(height: 15),

                    if (canAddPhoto) ...[
                      const Divider(),
                      const Text("Pista Visual (Opcional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 10),

                      if (_selectedTreasureImage != null)
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Image.file(_selectedTreasureImage!, height: 120, width: double.infinity, fit: BoxFit.cover),
                            IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setDialogState(() => _selectedTreasureImage = null)),
                          ],
                        )
                      else if (existingImageUrl != null)
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Image.network(existingImageUrl!, height: 120, width: double.infinity, fit: BoxFit.cover),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setDialogState(() => existingImageUrl = null)),
                          ],
                        )
                      else
                        Container(
                          height: 80,
                          width: double.infinity,
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                          child: Center(child: TextButton.icon(icon: const Icon(Icons.add_photo_alternate), label: const Text("Agregar Foto"), onPressed: () => _pickTreasureImage(setDialogState))),
                        ),
                      const Text("* Solo disponible en Fácil/Medio", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ] else
                      const Text("🚫 Sin fotos en nivel Difícil", style: TextStyle(color: Colors.redAccent, fontSize: 12)),

                    if (_isUploadingImage) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: _isUploadingImage ? null : () async {
                  if (formKey.currentState!.validate()) {
                    setDialogState(() => _isUploadingImage = true);

                    String? finalImageUrl = existingImageUrl;
                    if (_selectedTreasureImage != null && canAddPhoto) {
                      finalImageUrl = await _uploadTreasureImage(_selectedTreasureImage!);
                    }
                    if (!canAddPhoto) finalImageUrl = null;

                    try {
                      final now = DateTime.now();
                      DateTime? limitedUntil;

                      if (isLimited) {
                        // Duración según dificultad
                        int minutes = 0;
                        switch (difficulty) {
                          case 'Fácil':
                            minutes = 4;
                            break;
                          case 'Medio':
                            minutes = 3;
                            break;
                          case 'Difícil':
                            minutes = 2;
                            break;
                        }
                        limitedUntil = now.add(Duration(minutes: minutes));
                      }

                      final data = {
                        'title': titleController.text.trim(),
                        'description': descController.text.trim(),
                        'difficulty': difficulty,
                        'isLimitedTime': isLimited,
                        'location': GeoPoint(finalLocation.latitude, finalLocation.longitude),
                        'creatorUid': widget.adminUid,
                        'imageUrl': finalImageUrl,
                        "notificationSent": false,
                        if (!isEditing) 'creationDate': Timestamp.now(),
                        // Solo incluye el campo si está activo el tiempo limitado
                        if (isLimited && limitedUntil != null)
                          'limitedUntil': Timestamp.fromDate(limitedUntil),
                      };


                      if (isEditing) {
                        await FirebaseFirestore.instance.collection('treasures').doc(treasureToEdit.id).update(data);
                      } else {
                        await FirebaseFirestore.instance.collection('treasures').add(data);
                      }

                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'Actualizado' : 'Creado')));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    } finally {
                      setDialogState(() => _isUploadingImage = false);
                    }
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

  void _showTreasureDetails(TreasureModel t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              children: [
                Chip(label: Text('Dificultad: ${t.difficulty}')),
                const SizedBox(width: 5),
                if (t.isLimitedTime) const Chip(label: Text('Limitado'), backgroundColor: Colors.orangeAccent),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showTreasureForm(context, treasureToEdit: t);
              },
              child: const Text('Editar')
          ),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('treasures').doc(t.id).delete();
                if(mounted) Navigator.pop(ctx);
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _showRoutes ? 1 : 0,
        onTap: (index) {
          if (index == 1 && _currentPosition == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activa el GPS')));
          }
          setState(() => _showRoutes = (index == 1));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Explorar'),
          BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Ruta (200m)'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnUser,
        child: const Icon(Icons.my_location, color: Colors.blueAccent),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('treasures').snapshots(),
            builder: (context, snapshot) {
              List<Marker> markers = [];
              List<LatLng> routePoints = [];

              if (snapshot.hasData) {
                final allTreasures = snapshot.data!.docs.map((d) => TreasureModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();

                markers = allTreasures.map((t) => Marker(
                  point: LatLng(t.location.latitude, t.location.longitude),
                  width: 60,
                  height: 60,
                  child: GestureDetector(
                    onTap: () => _showTreasureDetails(t),
                    child: const Icon(Icons.location_on, color: Colors.red, size: 50),
                  ),
                )).toList();

                if (_showRoutes && _currentPosition != null) {
                  routePoints = _calculateOptimizedRoute(allTreasures);
                }
              }

              if (_currentPosition != null) {
                markers.add(Marker(point: _currentPosition!, width: 50, height: 50, child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40)));
              }

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: _tepicCenter, initialZoom: 14, onTap: (_, p) => _showTreasureForm(context, location: p)),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.geohunt.app'),
                  if (_showRoutes && _currentPosition != null)
                    CircleLayer(circles: [CircleMarker(point: _currentPosition!, radius: 200, useRadiusInMeter: true, color: Colors.blue.withOpacity(0.1), borderColor: Colors.blue, borderStrokeWidth: 1)]),
                  if (routePoints.isNotEmpty)
                    PolylineLayer(polylines: [Polyline(points: routePoints, strokeWidth: 5, color: Colors.deepPurpleAccent, isDotted: true)]),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),
          if (_showRoutes)
            Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.all(8), color: Colors.white70, child: const Text("Modo Ruta Activo", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. VISTA DE LISTA DE TESOROS (CON FOTO)
// =============================================================================
class TreasuresListView extends StatelessWidget {
  const TreasuresListView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('treasures').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay tesoros'));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final t = TreasureModel.fromMap(snapshot.data!.docs[index].data() as Map<String, dynamic>, snapshot.data!.docs[index].id);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFE6F2EF),
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: t.imageUrl != null
                    ? CircleAvatar(backgroundImage: NetworkImage(t.imageUrl!), radius: 28)
                    : const CircleAvatar(child: Icon(Icons.diamond), radius: 28),
                title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text(t.difficulty, style: const TextStyle(color: Color(0xFF8992D7), fontWeight: FontWeight.w500)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => FirebaseFirestore.instance.collection('treasures').doc(t.id).delete(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// 3. VISTA DE GESTIÓN DE USUARIOS
// =============================================================================
class UsersListView extends StatelessWidget {
  const UsersListView({super.key});

  void _showUserDetails(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          CircleAvatar(backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null, child: user.profileImageUrl == null ? const Icon(Icons.person) : null),
          const SizedBox(width: 10), Expanded(child: Text(user.username))
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Email: ${user.email}'),
          Text('Tel: ${user.phoneNumber ?? "N/A"}'),
          Text('Puntaje: ${user.score}'),
          Text('Tesoros Hallados: ${user.foundTreasures?.length ?? 0}'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'user').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay exploradores registrados.'));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final user = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFE6F2EF),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF91B1A8),
                  backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null,
                  child: user.profileImageUrl == null ? Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                  radius: 28,
                ),
                title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text(user.email ?? 'Sin correo', style: const TextStyle(color: Color(0xFF8992D7))),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF8992D7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${user.score} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                onTap: () => _showUserDetails(context, user),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// 4. VISTA DE PERFIL ADMIN (OPTIMIZADA)
// =============================================================================
class ProfileEditView extends StatefulWidget {
  final AdminModel adminUser;
  const ProfileEditView({super.key, required this.adminUser});
  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  bool _isLoading = false;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.adminUser.username);
    _phoneController = TextEditingController(text: widget.adminUser.phoneNumber ?? '');
    _currentImageUrl = widget.adminUser.profileImageUrl;
  }

  @override
  void didUpdateWidget(covariant ProfileEditView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adminUser != widget.adminUser) {
      _usernameController.text = widget.adminUser.username;
      _phoneController.text = widget.adminUser.phoneNumber ?? '';
      _currentImageUrl = widget.adminUser.profileImageUrl;
    }
  }

  void _showSelectionDialog() {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galería'), onTap: () { Navigator.pop(ctx); _checkPermissionAndPick(ImageSource.gallery); }),
      ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Cámara'), onTap: () { Navigator.pop(ctx); _checkPermissionAndPick(ImageSource.camera); }),
    ])));
  }

  Future<void> _checkPermissionAndPick(ImageSource source) async {
    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      status = Platform.isAndroid ? await Permission.photos.request() : await Permission.photos.request();
      if (Platform.isAndroid && (status.isPermanentlyDenied || status.isDenied)) status = await Permission.storage.request();
    }

    if (status.isGranted || status.isLimited) {
      _pickAndUploadImage(source);
    } else if (status.isPermanentlyDenied) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Habilita permisos en ajustes'), action: SnackBarAction(label: 'Ir', onPressed: openAppSettings)));
    }
  }

  // OPTIMIZACIÓN: Perfil ligero (512px, 60%)
  Future<void> _pickAndUploadImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source, imageQuality: 60, maxWidth: 512);
      if (image == null) return;

      setState(() => _isLoading = true);

      final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('${widget.adminUser.uid}.jpg');
      await storageRef.putFile(File(image.path), SettableMetadata(contentType: 'image/jpeg'));
      final String downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(widget.adminUser.uid).update({'profileImageUrl': downloadUrl});

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen actualizada')));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.adminUser.uid).update({
        'username': _usernameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actualizado')));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE6F2EF), Color(0xFF97AAA6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              GestureDetector(
                onTap: _isLoading ? null : _showSelectionDialog,
                child: CircleAvatar(
                  radius: 62,
                  backgroundColor: const Color(0xFF91B1A8),
                  backgroundImage: (_currentImageUrl != null) ? NetworkImage(_currentImageUrl!) : null,
                  child: _currentImageUrl == null ? const Icon(Icons.person, size: 70, color: Colors.white) : null,
                ),
              ),
              const SizedBox(height: 22),
              Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        enabled: false,
                        controller: TextEditingController(text: widget.adminUser.email),
                        decoration: InputDecoration(
                          labelText: 'Correo',
                          prefixIcon: const Icon(Icons.email, color: Color(0xFF8992D7)),
                          filled: true,
                          fillColor: Color(0xFFE6F2EF),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: const Icon(Icons.person, color: Color(0xFF91B1A8)),
                          filled: true,
                          fillColor: Color(0xFFE6F2EF),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF8992D7)), borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFF91B1A8)),
                          filled: true,
                          fillColor: Color(0xFFE6F2EF),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF8992D7)), borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF8992D7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          onPressed: _isLoading ? null : _updateProfile,
                          child: const Text('Guardar Cambios'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 5. MANUAL DE USUARIO
// =============================================================================
class AdminManualView extends StatelessWidget {
  const AdminManualView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(leading: Icon(Icons.map), title: Text("1. Mapa"), subtitle: Text("Toca para crear. Si es Fácil/Medio, añade foto.")),
        ListTile(leading: Icon(Icons.alt_route), title: Text("2. Rutas"), subtitle: Text("Activa 'Ruta' para ver el camino óptimo.")),
        ListTile(leading: Icon(Icons.people), title: Text("3. Usuarios"), subtitle: Text("Gestiona exploradores.")),
        ListTile(leading: Icon(Icons.person), title: Text("4. Perfil"), subtitle: Text("Actualiza tu foto.")),
      ],
    );
  }
}