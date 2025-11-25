import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModel {
  final String uid;
  final String email;
  final String username;
  final String? phoneNumber;
  final String? profileImageUrl; // NUEVO CAMPO
  final String role;
  final List<String> permissions;
  final Timestamp? lastLogin;

  AdminModel({
    required this.uid,
    required this.email,
    required this.username,
    this.phoneNumber,
    this.profileImageUrl, // NUEVO
    this.role = 'admin',
    this.permissions = const ['manage_treasures', 'manage_users'],
    this.lastLogin,
  });

  factory AdminModel.fromMap(Map<String, dynamic> data, String documentId) {
    return AdminModel(
      uid: documentId,
      email: data['email'] ?? '',
      username: data['username'] ?? 'Administrador',
      phoneNumber: data['phoneNumber'],
      profileImageUrl: data['profileImageUrl'], // Leemos la imagen
      role: data['role'] ?? 'admin',
      permissions: data['permissions'] != null
          ? List<String>.from(data['permissions'])
          : ['manage_treasures'],
      lastLogin: data['lastLogin'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'username': username,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl, // Guardamos la imagen
      'role': role,
      'permissions': permissions,
      'lastLogin': lastLogin ?? Timestamp.now(),
    };
  }
}