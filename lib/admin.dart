import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'tesoro.dart';
import 'admin_model.dart';
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
          const TreasuresListView(),
          ProfileEditView(adminUser: currentAdmin),
        ];

        final List<String> _titles = [
          'GEO HUNT',
          'Inventario',
          'Perfil Admin'
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
                // --- CORRECCIÓN AQUÍ: Usamos DrawerHeader en lugar de UserAccountsDrawerHeader ---
                DrawerHeader(
                  decoration: const BoxDecoration(color: Color(0xFF91B1A8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 1. IMAGEN DE PERFIL
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        backgroundImage: (currentAdmin.profileImageUrl != null && currentAdmin.profileImageUrl!.isNotEmpty)
                            ? NetworkImage(currentAdmin.profileImageUrl!)
                            : null,
                        child: (currentAdmin.profileImageUrl == null || currentAdmin.profileImageUrl!.isEmpty)
                            ? Text(
                          currentAdmin.username.isNotEmpty ? currentAdmin.username[0].toUpperCase() : 'A',
                          style: const TextStyle(fontSize: 30.0, color: Color(0xFF91B1A8)),
                        )
                            : null,
                      ),
                      const SizedBox(height: 15),
                      // 2. SOLO EL NOMBRE (Sin email, sin overflow)
                      Text(
                        currentAdmin.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // --------------------------------------------------------------------------------

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
      },
    );
  }
}

// --- RESTO DEL CÓDIGO IGUAL ---

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
      _currentImageUrl = widget.adminUser.profileImageUrl; // Actualizar imagen localmente si cambia
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
      if (Platform.isAndroid) {
        status = await Permission.photos.request();
        if (status.isPermanentlyDenied || status.isDenied) status = await Permission.storage.request();
      } else {
        status = await Permission.photos.request();
      }
    }

    if (status.isGranted || status.isLimited) {
      _pickAndUploadImage(source);
    } else if (status.isPermanentlyDenied) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Habilita permisos en ajustes'), action: SnackBarAction(label: 'Ir', onPressed: openAppSettings)));
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Necesitamos permisos')));
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source, imageQuality: 25, maxWidth: 300, maxHeight: 300);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFF91B1A8),
              backgroundImage: (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                  ? NetworkImage(_currentImageUrl!)
                  : null,
              child: (_currentImageUrl == null || _currentImageUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 70, color: Colors.white)
                  : null,
            ),
            Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: _isLoading ? null : _showSelectionDialog, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFF8992D7), shape: BoxShape.circle), child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.camera_alt, color: Colors.white, size: 20))))
          ]),
          const SizedBox(height: 30),
          TextField(enabled: false, controller: TextEditingController(text: widget.adminUser.email), decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.email))),
          const SizedBox(height: 20),
          TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person))),
          const SizedBox(height: 20),
          TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone))),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: _isLoading ? null : _updateProfile, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)), child: const Text('Guardar Cambios Texto'))
        ],
      ),
    );
  }
}

class TreasuresMapView extends StatefulWidget {
  final String adminUid;
  const TreasuresMapView({super.key, required this.adminUid});
  @override
  State<TreasuresMapView> createState() => _TreasuresMapViewState();
}

class _TreasuresMapViewState extends State<TreasuresMapView> {
  final LatLng _tepicCenter = const LatLng(21.5114, -104.8947);
  final MapController _mapController = MapController();
  bool _showRoutes = false;
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  final Distance _distanceCalculator = const Distance();

  @override
  void initState() { super.initState(); _checkLocationPermissions(); }
  @override
  void dispose() { _positionStream?.cancel(); super.dispose(); }

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
      if(mounted) setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
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

  void _showTreasureForm(BuildContext context, {LatLng? location, TreasureModel? treasureToEdit}) {
    final isEditing = treasureToEdit != null;
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: isEditing ? treasureToEdit.title : '');
    final descController = TextEditingController(text: isEditing ? treasureToEdit.description : '');
    String difficulty = isEditing ? treasureToEdit.difficulty : 'Medio';
    bool isLimited = isEditing ? treasureToEdit.isLimitedTime : false;
    final LatLng finalLocation = isEditing ? LatLng(treasureToEdit.location.latitude, treasureToEdit.location.longitude) : (location ?? _tepicCenter);

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(isEditing ? 'Editar' : 'Nuevo'),
      content: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Título'), validator: (v)=>v!.isEmpty?'X':null),
        TextFormField(controller: descController, decoration: const InputDecoration(labelText: 'Descripción')),
        DropdownButtonFormField(value: difficulty, items: ['Fácil','Medio','Difícil'].map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>setDialogState(()=>difficulty=v!)),
        SwitchListTile(title: const Text('Limitado'), value: isLimited, onChanged: (v)=>setDialogState(()=>isLimited=v)),
      ]))),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () async {
          if(formKey.currentState!.validate()){
            final data = {
              'title': titleController.text, 'description': descController.text, 'difficulty': difficulty, 'isLimitedTime': isLimited,
              'location': GeoPoint(finalLocation.latitude, finalLocation.longitude),
              'creatorUid': widget.adminUid,
              if(!isEditing) 'creationDate': Timestamp.now()
            };
            if(isEditing) await FirebaseFirestore.instance.collection('treasures').doc(treasureToEdit.id).update(data);
            else await FirebaseFirestore.instance.collection('treasures').add(data);
            if(mounted) Navigator.pop(ctx);
          }
        }, child: Text(isEditing?'Guardar':'Crear'))
      ],
    )));
  }

  void _showTreasureDetails(TreasureModel t) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text(t.title), content: Text(t.description), actions: [
      TextButton(onPressed: (){Navigator.pop(ctx); _showTreasureForm(context, treasureToEdit: t);}, child: const Text('Editar')),
      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await FirebaseFirestore.instance.collection('treasures').doc(t.id).delete(); if(mounted)Navigator.pop(ctx); }, child: const Text('Eliminar'))
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        bottomNavigationBar: BottomNavigationBar(currentIndex: _showRoutes?1:0, onTap: (i)=>setState(()=>_showRoutes=(i==1)), items: const [BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'), BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Ruta')]),
        floatingActionButton: FloatingActionButton(onPressed: _centerOnUser, child: const Icon(Icons.my_location)),
        body: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('treasures').snapshots(), builder: (context, snapshot) {
          List<Marker> markers = []; List<LatLng> path = [];
          if(snapshot.hasData) {
            final all = snapshot.data!.docs.map((d)=>TreasureModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
            markers = all.map((t)=>Marker(point: LatLng(t.location.latitude, t.location.longitude), width: 60, height: 60, child: GestureDetector(onTap: ()=>_showTreasureDetails(t), child: const Icon(Icons.location_on, color: Colors.red, size: 50)))).toList();
            if(_showRoutes && _currentPosition != null) path = _calculateOptimizedRoute(all);
          }
          if(_currentPosition != null) markers.add(Marker(point: _currentPosition!, width: 50, height: 50, child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40)));
          return FlutterMap(mapController: _mapController, options: MapOptions(initialCenter: _tepicCenter, initialZoom: 14, onTap: (_, p)=>_showTreasureForm(context, location: p)), children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.geohunt.app'),
            if(_showRoutes && _currentPosition != null) CircleLayer(circles: [CircleMarker(point: _currentPosition!, radius: 200, useRadiusInMeter: true, color: Colors.blue.withOpacity(0.1), borderColor: Colors.blue)]),
            if(path.isNotEmpty) PolylineLayer(polylines: [Polyline(points: path, strokeWidth: 4, color: Colors.purple)]),
            MarkerLayer(markers: markers)
          ]);
        })
    );
  }
}

class TreasuresListView extends StatelessWidget {
  const TreasuresListView({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('treasures').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(itemCount: snapshot.data!.docs.length, itemBuilder: (context, index) {
          final t = TreasureModel.fromMap(snapshot.data!.docs[index].data() as Map<String, dynamic>, snapshot.data!.docs[index].id);
          return Card(child: ListTile(title: Text(t.title), subtitle: Text(t.difficulty), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseFirestore.instance.collection('treasures').doc(t.id).delete())));
        });
      },
    );
  }
}