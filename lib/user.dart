import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String username;
  final int score; // Solo para usuarios
  final List<String>? foundTreasures; // Solo para usuarios
  final String? phoneNumber;
  final String role;

  UserModel({
    required this.uid,
    this.email,
    required this.username,
    this.score = 0,
    this.foundTreasures,
    this.phoneNumber,
    this.role = 'user',
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    final List<dynamic>? treasuresList = data['foundTreasures'];

    return UserModel(
      uid: documentId,
      email: data['email'] as String?,
      username: data['username'] ?? 'Explorador',
      score: data['score'] ?? 0,
      foundTreasures: treasuresList != null
          ? List<String>.from(treasuresList)
          : null,
      phoneNumber: data['phoneNumber'] as String?,
      role: data['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'username': username,
      'score': score,
      'foundTreasures': foundTreasures ?? [],
      'phoneNumber': phoneNumber,
      'role': role,
    };
  }
}