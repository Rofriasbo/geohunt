import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart'; // Tu modelo de usuario
import 'pagina.dart'; // Tu pantalla de bienvenida

class GoogleLoginButton extends StatefulWidget {
  const GoogleLoginButton({super.key});

  @override
  State<GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<GoogleLoginButton> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isSigningIn = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      // 1. Iniciar el flujo de autenticación de Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Si el usuario cancela el login
      if (googleUser == null) {
        setState(() {
          _isSigningIn = false;
        });
        return;
      }

      // 2. Obtener los detalles de autenticación de la solicitud
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Crear una nueva credencial para Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Iniciar sesión en Firebase con la credencial
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // 5. Verificar si el usuario ya existe en Firestore
        final DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

        String username = user.displayName ?? 'Admin Google';

        if (!userDoc.exists) {
          // --- LÓGICA DE REGISTRO DE ADMIN ---
          // Si es la primera vez que entra con Google, lo creamos como ADMIN

          UserModel newAdmin = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            username: username,
            role: 'admin', // <--- AQUÍ SE ASIGNA EL ROL DE ADMIN
            score: 0,
            foundTreasures: [],
          );

          await _firestore.collection('users').doc(user.uid).set(newAdmin.toJson());
        } else {
          // Si ya existe, recuperamos su nombre actual
          username = UserModel.fromMap(userDoc.data() as Map<String, dynamic>, user.uid).username;
        }

        // 6. Navegar a la pantalla principal
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => WelcomeScreen(username: username),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Error de Firebase: ${e.message}');
    } catch (e) {
      _showSnackBar('Error al iniciar sesión con Google: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // Ocupar todo el ancho disponible
      child: ElevatedButton.icon(
        onPressed: _isSigningIn ? null : _signInWithGoogle,
        icon: _isSigningIn
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
            : const Icon(Icons.g_mobiledata, color: Colors.black87, size: 30), // Icono simple o usa una imagen de Google
        label: Text(
          _isSigningIn ? 'Cargando...' : 'Continuar con Google (Admin)',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}