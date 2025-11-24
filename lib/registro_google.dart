import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'modelos/user.dart';
import 'modelos/admin_model.dart'; // IMPORTANTE: Importar AdminModel
import 'pagina.dart';
import 'admin.dart';

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
    setState(() { _isSigningIn = true; });

    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() { _isSigningIn = false; });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

        String role = 'user';

        // 1. Determinar o Crear Rol
        if (!userDoc.exists) {
          // Nuevo Admin por defecto (según tu lógica)
          AdminModel newAdmin = AdminModel(
            uid: user.uid,
            email: user.email ?? '',
            username: user.displayName ?? 'Admin Google',
            role: 'admin',
            permissions: ['manage_treasures'],
            lastLogin: Timestamp.now(),
          );
          await _firestore.collection('users').doc(user.uid).set(newAdmin.toJson());
          role = 'admin';
        } else {
          final data = userDoc.data() as Map<String, dynamic>;
          role = data['role'] ?? 'user';
        }

        if (mounted) {
          // 2. Navegación según Rol
          if (role == 'admin') {
            // CORRECCIÓN AQUÍ:
            // Recuperamos los datos y creamos un AdminModel
            final adminData = (userDoc.exists) ? userDoc.data() as Map<String, dynamic> : {
              'email': user.email,
              'username': user.displayName,
              'role': 'admin'
            };

            AdminModel adminModel = AdminModel.fromMap(adminData, user.uid);

            Navigator.of(context).pushReplacement(
              // Usamos el parámetro correcto 'adminUser'
              MaterialPageRoute(builder: (context) => AdminScreen(adminUser: adminModel)),
            );
          } else {
            final data = userDoc.data() as Map<String, dynamic>;
            UserModel regularUser = UserModel.fromMap(data, user.uid);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => WelcomeScreen(username: regularUser.username)),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) { setState(() { _isSigningIn = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSigningIn ? null : _signInWithGoogle,
        icon: _isSigningIn
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.g_mobiledata, color: Colors.black87, size: 30),
        label: Text(_isSigningIn ? 'Cargando...' : 'Continuar con Google (Admin)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}