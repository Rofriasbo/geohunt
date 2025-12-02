import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String username;
  final int score;
  final List<String>? foundTreasures;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String role;
  final String? fcmToken;
  final GeoPoint? lastKnownLocation;

  UserModel({
    required this.uid,
    this.email,
    required this.username,
    this.score = 0,
    this.foundTreasures,
    this.phoneNumber,
    this.profileImageUrl,
    this.role = 'user',
    this.fcmToken,
    this.lastKnownLocation
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
      profileImageUrl: data['profileImageUrl'] as String?,
      role: data['role'] ?? 'user',
      fcmToken: data['fcmToken'] as String?,
      lastKnownLocation: data['lastKnownLocation'] as GeoPoint?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'username': username,
      'score': score,
      'foundTreasures': foundTreasures ?? [],
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'role': role,
      'fcmToken': fcmToken,
      'lastKnownLocation': lastKnownLocation
    };
  }
}