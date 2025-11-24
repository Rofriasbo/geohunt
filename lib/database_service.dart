import 'package:cloud_firestore/cloud_firestore.dart';
import 'modelos/user.dart';
import 'modelos/admin_model.dart'; // Importamos el nuevo modelo
import 'modelos/tesoro.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final String _userCollection = 'users';
  final String _treasureCollection = 'treasures';

  // --- USUARIOS ---
  Future<void> createUser(UserModel user) async {
    await _db.collection(_userCollection).doc(user.uid).set(user.toJson());
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection(_userCollection).doc(uid).update(data);
    } catch (e) {
      print('Error al actualizar usuario $uid: $e');
    }
  }

  Future<void> saveFCMToken(String uid, String? token) async {
    if (token != null) {
      await _db.collection(_userCollection).doc(uid).set({
        'fcmToken': token, // Este es el campo que la Cloud Function utiliza
      }, SetOptions(merge: true));
      print("Token FCM guardado/actualizado en Firestore para UID: $uid");
    }
  }

  // Método específico para crear/actualizar Admins
  Future<void> createOrUpdateAdmin(AdminModel admin) async {
    await _db.collection(_userCollection).doc(admin.uid).set(admin.toJson(), SetOptions(merge: true));
  }

  // Método genérico para obtener datos crudos y decidir el modelo después
  Future<DocumentSnapshot?> getUserSnapshot(String uid) async {
    try {
      return await _db.collection(_userCollection).doc(uid).get();
    } catch (e) {
      print('Error al obtener snapshot: $e');
      return null;
    }
  }

  // --- TESOROS ---
  Future<String?> createTreasure(TreasureModel treasure) async {
    try {
      final docRef = _db.collection(_treasureCollection).doc();
      await docRef.set(treasure.toJson());
      return docRef.id;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Stream<List<TreasureModel>> getTreasures() {
    return _db.collection(_treasureCollection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return TreasureModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> updateTreasure(String treasureId, Map<String, dynamic> data) async {
    await _db.collection(_treasureCollection).doc(treasureId).update(data);
  }

  Future<void> deleteTreasure(String treasureId) async {
    await _db.collection(_treasureCollection).doc(treasureId).delete();
  }

  Future<void> markTreasureAsFound(String userUid, String treasureId) async {
    final userRef = _db.collection(_userCollection).doc(userUid);
    await userRef.update({
      'foundTreasures': FieldValue.arrayUnion([treasureId]),
    });
  }
}