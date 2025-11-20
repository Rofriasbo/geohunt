import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart';
import 'pagina.dart';
import 'admin.dart'; // IMPORTANTE: Importamos la pantalla de Admin

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
      // 1. Forzar cierre de sesión previo para elegir cuenta
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

        UserModel userModel;

        if (!userDoc.exists) {
          // CASO: NUEVO USUARIO -> Se crea como ADMIN por defecto (según tu lógica)
          userModel = UserModel(
            uid: user.uid,
            email: user.email ?? '', // CORRECCIÓN: Manejo de nulos
            username: user.displayName ?? 'Admin Google',
            role: 'admin',
            score: 0,
            foundTreasures: [],
          );
          await _firestore.collection('users').doc(user.uid).set(userModel.toJson());
        } else {
          // CASO: YA EXISTE -> Cargamos sus datos
          userModel = UserModel.fromMap(userDoc.data() as Map<String, dynamic>, user.uid);
        }

        if (mounted) {
          // --- LÓGICA DE REDIRECCIÓN ---
          if (userModel.role == 'admin') {
            // SI ES ADMIN -> PANTALLA DE ADMIN
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => AdminScreen(user: userModel)),
            );
          } else {
            // SI ES USER NORMAL -> PANTALLA DE BIENVENIDA
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => WelcomeScreen(username: userModel.username)),
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