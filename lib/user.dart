import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final int score;
  final List<String>? foundTreasures;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.score = 0,
    this.foundTreasures,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    final List<dynamic>? treasuresList = data['foundTreasures'];

    return UserModel(
      // CORRECCIÓN: Usamos documentId (doc.id) como el UID del usuario
      uid: documentId,
      email: data['email'] ?? '',
      username: data['username'] ?? 'Explorador',
      score: data['score'] ?? 0,
      foundTreasures: treasuresList != null
          ? List<String>.from(treasuresList)
          : null,
    );
  }

  // Método para convertir el objeto UserModel a un mapa para Firestore
  Map<String, dynamic> toJson() {
    return {
      // El UID no se incluye aquí porque se usa como ID del documento
      'email': email,
      'username': username,
      'score': score,
      'foundTreasures': foundTreasures ?? [],
    };
  }
}