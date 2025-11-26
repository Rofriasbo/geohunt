import 'package:cloud_firestore/cloud_firestore.dart';

class TreasureModel {
  final String id;
  final String title;
  final String description;
  final GeoPoint location;
  final String difficulty;
  final String creatorUid;
  final bool isLimitedTime;
  final DateTime? limitedUntil;
  final bool notificationSent; //Adición para manejar los puntos temporales
  final Timestamp? creationDate;
  final Timestamp? expiryDate;
  final String? imageUrl; // NUEVO: URL de la imagen del tesoro

  TreasureModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.difficulty,
    required this.creatorUid,
    this.isLimitedTime = false,
    this.limitedUntil,
    this.notificationSent = false,
    this.creationDate,
    this.expiryDate,
    this.imageUrl, // NUEVO
  });

  factory TreasureModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TreasureModel(
      id: documentId,
      title: data['title'] ?? 'Tesoro sin título',
      description: data['description'] ?? 'Sin descripción',
      location: data['location'] is GeoPoint
          ? data['location']
          : const GeoPoint(21.5114, -104.8947),
      difficulty: data['difficulty'] ?? 'Medio',
      creatorUid: data['creatorUid'] ?? '',
      isLimitedTime: data['isLimitedTime'] ?? false,
      limitedUntil: data['limitedUntil'] != null
          ? (data['limitedUntil'] as Timestamp).toDate()
          : null,
      notificationSent: data['notificationSent'] ?? false,
      creationDate: data['creationDate'] as Timestamp?,
      expiryDate: data['expiryDate'] as Timestamp?,
      imageUrl: data['imageUrl'] as String?, // NUEVO
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'difficulty': difficulty,
      'creatorUid': creatorUid,
      'isLimitedTime': isLimitedTime,
      'limitedUntil': limitedUntil,
      'notificationSent': notificationSent,
      'creationDate': creationDate ?? Timestamp.now(),
      'expiryDate': expiryDate,
      'imageUrl': imageUrl, // NUEVO
    };
  }
}