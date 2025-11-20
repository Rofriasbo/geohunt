import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart';
import 'tesoro.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final String _userCollection = 'users';
  final String _treasureCollection = 'treasures';

  // --- MÉTODOS DE USUARIO ---
  Future<void> createUser(UserModel user) async {
    try {
      await _db.collection(_userCollection).doc(user.uid).set(user.toJson());
    } catch (e) {
      print('Error al crear usuario: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _db.collection(_userCollection).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error al obtener datos: $e');
      return null;
    }
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _db.collection(_userCollection).doc(uid).update(data);
  }

  // --- MÉTODOS DE TESOROS (CRUD) ---

  // Create
  Future<String?> createTreasure(TreasureModel treasure) async {
    try {
      // Firestore genera el ID automáticamente al usar .doc() vacío,
      // pero aquí usamos el ID que ya trae el modelo o dejamos que set lo cree
      // Lo mejor es dejar que Firestore genere el ID:
      final docRef = _db.collection(_treasureCollection).doc();
      // Guardamos los datos usando el ID generado
      await docRef.set(treasure.toJson());
      return docRef.id;
    } catch (e) {
      print('Error al crear tesoro: $e');
      return null;
    }
  }

  // Helper para crear directamente desde Mapa y GeoPoint (usado en Admin)
  Future<void> addTreasureRaw(Map<String, dynamic> data) async {
    await _db.collection(_treasureCollection).add(data);
  }

  // Read (Stream)
  Stream<List<TreasureModel>> getTreasures() {
    return _db.collection(_treasureCollection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return TreasureModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Update
  Future<void> updateTreasure(String treasureId, Map<String, dynamic> data) async {
    try {
      await _db.collection(_treasureCollection).doc(treasureId).update(data);
    } catch (e) {
      print('Error al actualizar tesoro: $e');
      rethrow;
    }
  }

  // Delete
  Future<void> deleteTreasure(String treasureId) async {
    try {
      await _db.collection(_treasureCollection).doc(treasureId).delete();
    } catch (e) {
      print('Error al eliminar tesoro: $e');
      rethrow;
    }
  }

  Future<void> markTreasureAsFound(String userUid, String treasureId) async {
    final userRef = _db.collection(_userCollection).doc(userUid);
    // CORREGIDO: Quité el espacio en 'foundTreasures'
    await userRef.update({
      'foundTreasures': FieldValue.arrayUnion([treasureId]),
    });
  }
}