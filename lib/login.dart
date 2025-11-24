import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'registro.dart';
import 'pagina.dart';
import 'admin.dart';
import 'modelos/user.dart';
import 'modelos/admin_model.dart'; // IMPORTANTE
import 'registro_google.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  static const Color primaryColor = Color(0xFF91B1A8);
  static const Color backgroundColor = Color(0xFF97AAA6);
  static const Color inputBgColor = Color(0xFFE9F3F0);
  static const Color accentColor = Color(0xFF8CB9AC);
  static const Color secondaryColor = Color(0xFF8992D7);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _navigateToRegister() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const Registro()));
  }

  Future<void> _performLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa correo y contraseña')));
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid;
      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final String role = data['role'] ?? 'user';

        if (mounted) {
          // --- LÓGICA CORREGIDA ---
          if (role == 'admin') {
            // Convertimos a AdminModel
            AdminModel admin = AdminModel.fromMap(data, docSnapshot.id);

            // Navegamos usando el parámetro correcto 'adminUser'
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => AdminScreen(adminUser: admin)),
            );
          } else {
            // Convertimos a UserModel
            UserModel user = UserModel.fromMap(data, docSnapshot.id);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => WelcomeScreen(username: user.username)),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('GeoHunt', textAlign: TextAlign.center, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: primaryColor, shadows: [Shadow(blurRadius: 10.0, color: Colors.black.withOpacity(0.2), offset: const Offset(3.0, 3.0))])),
              const SizedBox(height: 40),
              TextField(controller: _emailController, decoration: InputDecoration(labelText: 'Correo', filled: true, fillColor: inputBgColor, prefixIcon: const Icon(Icons.email, color: accentColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 20),
              TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: 'Contraseña', filled: true, fillColor: inputBgColor, prefixIcon: const Icon(Icons.lock, color: accentColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _performLogin,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 20),
              const GoogleLoginButton(),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _navigateToRegister,
                child: const Text('¿No tienes cuenta? Regístrate aquí', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: secondaryColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}