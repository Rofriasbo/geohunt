import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart';
import 'tesoro.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final String _userCollection = 'users';
  final String _treasureCollection = 'treasures';

  Future<void> createUser(UserModel user) async {
    try {
      await _db.collection(_userCollection).doc(user.uid).set(user.toJson());
    } catch (e) {
      print('Error al crear usuario en Firestore: $e');
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
      print('Error al obtener datos del usuario: $e');
      return null;
    }
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection(_userCollection).doc(uid).update(data);
    } catch (e) {
      print('Error al actualizar datos del usuario $uid: $e');
      rethrow;
    }
  }

  Future<void> updateScore(String uid, int scoreToAdd) async {
    await _db.collection(_userCollection).doc(uid).update({
      'score': FieldValue.increment(scoreToAdd),
    });
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _db.collection(_userCollection).doc(uid).delete();
    } catch (e) {
      print('Error al eliminar usuario $uid: $e');
      rethrow;
    }
  }

  Stream<List<UserModel>> getScoreboard() {
    return _db
        .collection(_userCollection)
        .orderBy('score', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<String?> createTreasure(TreasureModel treasure) async {
    try {
      final docRef = _db.collection(_treasureCollection).doc();
      final data = treasure.toJson();
      await docRef.set(data);
      return docRef.id;
    } catch (e) {
      print('Error al crear tesoro: $e');
      return null;
    }
  }

  Future<TreasureModel?> getTreasureById(String treasureId) async {
    try {
      final doc = await _db.collection(_treasureCollection).doc(treasureId).get();
      if (doc.exists && doc.data() != null) {
        return TreasureModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error al obtener tesoro $treasureId: $e');
      return null;
    }
  }

  Stream<List<TreasureModel>> getTreasures() {
    return _db
        .collection(_treasureCollection)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TreasureModel.fromMap(doc.data()!, doc.id);
      }).toList();
    });
  }

  Stream<List<TreasureModel>> getActiveLimitedTimeTreasures() {
    final now = Timestamp.now();
    return _db
        .collection(_treasureCollection)
        .where('isLimitedTime', isEqualTo: true)
        .where('expiryDate', isGreaterThan: now)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TreasureModel.fromMap(doc.data()!, doc.id)).toList();
    });
  }

  Future<void> updateTreasure(String treasureId, Map<String, dynamic> data) async {
    try {
      await _db.collection(_treasureCollection).doc(treasureId).update(data);
    } catch (e) {
      print('Error al actualizar tesoro $treasureId: $e');
      rethrow;
    }
  }

  Future<void> deleteTreasure(String treasureId) async {
    try {
      await _db.collection(_treasureCollection).doc(treasureId).delete();
    } catch (e) {
      print('Error al eliminar tesoro $treasureId: $e');
      rethrow;
    }
  }

  Future<void> markTreasureAsFound(String userUid, String treasureId) async {
    final userRef = _db.collection(_userCollection).doc(userUid);

    await userRef.update({
      'foundTr easures': FieldValue.arrayUnion([treasureId]),
    });
  }

  Future<bool> hasUserFoundTreasure(String userUid, String treasureId) async {
    final userDoc = await _db.collection(_userCollection).doc(userUid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      final List<dynamic> foundTreasures = data?['foundTreasures'] ?? [];
      return foundTreasures.contains(treasureId);
    }
    return false;
  }
}