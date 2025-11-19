import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'registro.dart';
import 'pagina.dart';
import 'user.dart'; // El modelo de usuario
import 'registro_google.dart'; // NUEVO: Importamos el botón de Google que creamos

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  // Colores de la paleta
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const Registro(),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _performLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Por favor, ingresa correo y contraseña.');
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid;

      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      String username = 'Explorador';

      if (docSnapshot.exists && docSnapshot.data() != null) {
        username = UserModel.fromMap(docSnapshot.data()!, docSnapshot.id).username;
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WelcomeScreen(username: username),
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage;

      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Correo o contraseña incorrectos.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo electrónico es inválido.';
      } else {
        errorMessage = 'Error de inicio de sesión: ${e.message}';
      }

      _showSnackBar(errorMessage);
    } catch (e) {
      _showSnackBar('Ocurrió un error inesperado: $e');
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
              // Título
              Text(
                'GeoHunt',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: primaryColor.withAlpha((255 * 0.9).round()),
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(3.0, 3.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

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

              // Botón de Iniciar Sesión (Correo y Contraseña)
              ElevatedButton(
                onPressed: _performLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                ),
                child: const Text(
                  'Iniciar Sesión',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- NUEVO: Botón de Google (Para Admins) ---
              // Asegúrate de tener el archivo google.dart creado
              const GoogleLoginButton(),
              // --------------------------------------------

              const SizedBox(height: 20),

              // Link a Registrarse
              TextButton(
                onPressed: _navigateToRegister,
                style: TextButton.styleFrom(
                  foregroundColor: secondaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '¿No tienes cuenta? Regístrate aquí',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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