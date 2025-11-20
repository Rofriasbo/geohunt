import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart'; // IMPORTANTE: Librería de mapas
import 'package:latlong2/latlong.dart';      // IMPORTANTE: Coordenadas
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
      const TreasuresManagementView(), // Ahora contiene el mapa
      ProfileEditView(user: widget.user),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Mapa de Tesoros (Tepic)' : 'Mi Perfil'),
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
                child: Text(widget.user.username.isNotEmpty ? widget.user.username[0].toUpperCase() : 'A', style: const TextStyle(fontSize: 40.0, color: Color(0xFF91B1A8))),
              ),
            ),
            ListTile(leading: const Icon(Icons.map), title: const Text('Mapa de Tesoros'), selected: _selectedIndex == 0, onTap: () => _onItemTapped(0)),
            ListTile(leading: const Icon(Icons.person), title: const Text('Modificar Perfil'), selected: _selectedIndex == 1, onTap: () => _onItemTapped(1)),
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
// VISTA DEL MAPA DE TESOROS
// ---------------------------------------------------------------------------
class TreasuresManagementView extends StatelessWidget {
  const TreasuresManagementView({super.key});

  // Coordenadas de Tepic, Nayarit
  final LatLng _tepicCenter = const LatLng(21.5114, -104.8947);

  Future<void> _deleteTreasure(String id, BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('treasures').doc(id).delete();
      if(context.mounted) {
        Navigator.pop(context); // Cerrar el diálogo
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tesoro eliminado')));
      }
    } catch (e) {
      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Función para mostrar detalles al tocar un marcador
  void _showTreasureDetails(BuildContext context, TreasureModel treasure) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(treasure.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Descripción: ${treasure.description}'),
            const SizedBox(height: 8),
            Text('Dificultad: ${treasure.difficulty}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Coordenadas: ${treasure.location.latitude.toStringAsFixed(4)}, ${treasure.location.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _deleteTreasure(treasure.id, context),
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text('Eliminar Tesoro', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('treasures').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Error al cargar mapa'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        // Lista de marcadores
        List<Marker> markers = [];

        if (snapshot.hasData) {
          markers = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Usamos tu modelo TreasureModel
            final treasure = TreasureModel.fromMap(data, doc.id);

            return Marker(
              point: LatLng(treasure.location.latitude, treasure.location.longitude),
              width: 60,
              height: 60,
              child: GestureDetector(
                onTap: () => _showTreasureDetails(context, treasure),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 45,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                ),
              ),
            );
          }).toList();
        }

        return FlutterMap(
          options: MapOptions(
            initialCenter: _tepicCenter, // Centrado en Tepic
            initialZoom: 13.5,           // Zoom adecuado para la ciudad
            minZoom: 5,
            maxZoom: 18,
          ),
          children: [
            // Capa del mapa base (OpenStreetMap)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.geohunt', // Buena práctica
            ),
            // Capa de marcadores (Tesoros)
            MarkerLayer(
              markers: markers,
            ),
            // Créditos de OSM (Requerido por licencia)
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// VISTA DE EDICIÓN DE PERFIL (Sin cambios)
// ---------------------------------------------------------------------------
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
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({'username': _usernameController.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actualizado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Icon(Icons.admin_panel_settings, size: 80, color: Color(0xFF91B1A8)),
          const SizedBox(height: 20),
          TextField(enabled: false, controller: TextEditingController(text: widget.user.email), decoration: const InputDecoration(labelText: 'Correo')),
          const SizedBox(height: 20),
          TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Nombre de Usuario')),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: _isLoading ? null : _updateProfile, child: const Text('Guardar Cambios')),
        ],
      ),
    );
  }
}