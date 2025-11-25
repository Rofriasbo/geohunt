import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart'; // CORREGIDO: Importa el archivo correcto (plural)

class Registro extends StatefulWidget {
  const Registro({super.key});

  @override
  State<Registro> createState() => _RegistroState();
}

class _RegistroState extends State<Registro> {
  static const Color primaryColor = Color(0xFF91B1A8);
  static const Color backgroundColor = Color(0xFF97AAA6);
  static const Color inputBgColor = Color(0xFFE9F3F0);
  static const Color accentColor = Color(0xFF8CB9AC);
  static const Color secondaryColor = Color(0xFF8992D7);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _performRegistration() async {
    final String username = _usernameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Por favor, completa todos los campos.');
      return;
    }

    try {
      // 1. Crear usuario en Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Crear objeto UserModel
      UserModel newUser = UserModel(
        uid: userCredential.user!.uid,
        email: email,
        username: username,
        role: 'user', // Por defecto se registra como 'user'
      );

      // 3. Guardar en Firestore
      await _firestore
          .collection('users')
          .doc(newUser.uid)
          .set(newUser.toJson());

      _showSnackBar('Registro exitoso. Bienvenido!');

      if (mounted) {
        Navigator.of(context).pop();
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'weak-password') {
        errorMessage = 'La contraseña es demasiado débil.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Ya existe una cuenta con este correo.';
      } else {
        errorMessage = 'Error de registro: ${e.message}';
      }
      _showSnackBar(errorMessage);
    } catch (e) {
      _showSnackBar('Ocurrió un error inesperado: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Crear Cuenta', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                '¡Únete a la Aventura!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 30),

              // Campo de Nombre de Usuario
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de Usuario',
                  labelStyle: const TextStyle(color: primaryColor),
                  filled: true,
                  fillColor: inputBgColor,
                  prefixIcon: const Icon(Icons.person, color: accentColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Campo de Correo Electrónico
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  labelStyle: const TextStyle(color: primaryColor),
                  filled: true,
                  fillColor: inputBgColor,
                  prefixIcon: const Icon(Icons.email, color: accentColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Campo de Contraseña
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: const TextStyle(color: primaryColor),
                  filled: true,
                  fillColor: inputBgColor,
                  prefixIcon: const Icon(Icons.lock, color: accentColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Botón de Registrarse
              ElevatedButton(
                onPressed: _performRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                ),
                child: const Text(
                  'Registrarse',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}