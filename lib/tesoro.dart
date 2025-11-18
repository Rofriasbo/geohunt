import 'package:cloud_firestore/cloud_firestore.dart';

class TreasureModel {
  final String id;
  final String title;
  final String description;
  final GeoPoint location; // Tipo de dato especial de Firestore para coordenadas
  final String difficulty; // Ej. 'Fácil', 'Medio', 'Difícil'
  final String creatorUid;
  final bool isLimitedTime; // Para los tesoros con tiempo limitado
  final Timestamp? creationDate; // Fecha de creación
  final Timestamp? expiryDate; // Para tesoros de tiempo limitado

  TreasureModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.difficulty,
    required this.creatorUid,
    this.isLimitedTime = false,
    this.creationDate,
    this.expiryDate,
  });

  // Constructor correcto para aceptar dos argumentos (data y documentId)
  factory TreasureModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TreasureModel(
      id: documentId,
      title: data['title'] ?? 'Tesoro sin título',
      description: data['description'] ?? 'Sin descripción',
      location: data['location'] as GeoPoint,
      difficulty: data['difficulty'] ?? 'Medio',
      creatorUid: data['creatorUid'] ?? '',
      isLimitedTime: data['isLimitedTime'] ?? false,
      creationDate: data['creationDate'] as Timestamp?,
      expiryDate: data['expiryDate'] as Timestamp?,
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
      'creationDate': creationDate ?? Timestamp.now(),
      'expiryDate': expiryDate,
    };
  }
}