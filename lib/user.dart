import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final int score;
  final List<String>? foundTreasures;
  final String role; // Nuevo campo para el rol

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.score = 0,
    this.foundTreasures,
    this.role = 'user', // Por defecto
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    final List<dynamic>? treasuresList = data['foundTreasures'];

    return UserModel(
      uid: documentId,
      email: data['email'] ?? '',
      username: data['username'] ?? 'Explorador',
      score: data['score'] ?? 0,
      foundTreasures: treasuresList != null
          ? List<String>.from(treasuresList)
          : null,
      role: data['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'username': username,
      'score': score,
      'foundTreasures': foundTreasures ?? [],
      'role': role,
    };
  }
}