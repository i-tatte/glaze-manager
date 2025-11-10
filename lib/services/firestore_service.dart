import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 現在のユーザーIDを取得
  String? get _userId => _auth.currentUser?.uid;

  // 原料を追加
  Future<void> addMaterial(Material material) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('materials')
        .add(material.toFirestore());
  }

  // 原料一覧を取得 (リアルタイム)
  Stream<List<Material>> getMaterials() {
    if (_userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_userId)
        .collection('materials')
        .orderBy('order') // orderフィールドで並び替え
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Material.fromFirestore(doc)).toList(),
        );
  }

  // 原料を更新
  Future<void> updateMaterial(Material material) async {
    if (_userId == null) throw Exception("User not logged in");
    if (material.id == null) {
      throw Exception("Material ID is required for update");
    }
    await _db
        .collection('users')
        .doc(_userId)
        .collection('materials')
        .doc(material.id)
        .update(material.toFirestore());
  }

  // 原料を削除
  Future<void> deleteMaterial(String materialId) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('materials')
        .doc(materialId)
        .delete();
  }

  // 複数の原料の並び順を更新
  Future<void> updateMaterialOrder(List<Material> materials) async {
    if (_userId == null) throw Exception("User not logged in");

    final batch = _db.batch();
    for (int i = 0; i < materials.length; i++) {
      final material = materials[i];
      final docRef = _db
          .collection('users')
          .doc(_userId)
          .collection('materials')
          .doc(material.id);
      batch.update(docRef, {'order': i});
    }
    await batch.commit();
  }

  // --- Glaze Methods ---

  // 釉薬を追加
  Future<void> addGlaze(Glaze glaze) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('glazes')
        .add(glaze.toFirestore());
  }

  // 釉薬一覧を取得 (リアルタイム)
  Stream<List<Glaze>> getGlazes() {
    if (_userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_userId)
        .collection('glazes')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Glaze.fromFirestore(doc)).toList(),
        );
  }

  // 釉薬を更新
  Future<void> updateGlaze(Glaze glaze) async {
    if (_userId == null) throw Exception("User not logged in");
    if (glaze.id == null) throw Exception("Glaze ID is required for update");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('glazes')
        .doc(glaze.id)
        .update(glaze.toFirestore());
  }

  // 釉薬を削除
  Future<void> deleteGlaze(String glazeId) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('glazes')
        .doc(glazeId)
        .delete();
  }

  // --- TestPiece Methods ---

  // テストピースを追加
  Future<void> addTestPiece(TestPiece testPiece) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('test_pieces')
        .add(testPiece.toFirestore());
  }

  // テストピース一覧を取得 (リアルタイム)
  Stream<List<TestPiece>> getTestPieces() {
    if (_userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_userId)
        .collection('test_pieces')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => TestPiece.fromFirestore(doc)).toList(),
        );
  }

  // テストピースを更新
  Future<void> updateTestPiece(TestPiece testPiece) async {
    if (_userId == null) throw Exception("User not logged in");
    if (testPiece.id == null) {
      throw Exception("TestPiece ID is required for update");
    }
    await _db
        .collection('users')
        .doc(_userId)
        .collection('test_pieces')
        .doc(testPiece.id)
        .update(testPiece.toFirestore());
  }

  // テストピースを削除
  Future<void> deleteTestPiece(String testPieceId) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('test_pieces')
        .doc(testPieceId)
        .delete();
  }

  // --- FiringProfile Methods ---

  /// 焼成プロファイルを追加
  Future<void> addFiringProfile(FiringProfile profile) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('firing_profiles')
        .add(profile.toFirestore());
  }

  /// 焼成プロファイル一覧を取得 (リアルタイム)
  Stream<List<FiringProfile>> getFiringProfiles() {
    if (_userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_userId)
        .collection('firing_profiles')
        .orderBy('name') // 名前で並び替え
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FiringProfile.fromFirestore(doc))
              .toList(),
        );
  }

  /// 焼成プロファイルを更新
  Future<void> updateFiringProfile(FiringProfile profile) async {
    if (_userId == null) throw Exception("User not logged in");
    if (profile.id == null) {
      throw Exception("FiringProfile ID is required for update");
    }
    await _db
        .collection('users')
        .doc(_userId)
        .collection('firing_profiles')
        .doc(profile.id)
        .update(profile.toFirestore());
  }

  /// 焼成プロファイルを削除
  Future<void> deleteFiringProfile(String profileId) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('firing_profiles')
        .doc(profileId)
        .delete();
  }

  // --- FiringAtmosphere Methods ---

  /// 焼成雰囲気を追加
  Future<void> addFiringAtmosphere(FiringAtmosphere atmosphere) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('firing_atmospheres')
        .add(atmosphere.toFirestore());
  }

  /// 焼成雰囲気一覧を取得 (リアルタイム)
  Stream<List<FiringAtmosphere>> getFiringAtmospheres() {
    if (_userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_userId)
        .collection('firing_atmospheres')
        .orderBy('name') // 名前で並び替え
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FiringAtmosphere.fromFirestore(doc))
              .toList(),
        );
  }

  /// 焼成雰囲気を更新
  Future<void> updateFiringAtmosphere(FiringAtmosphere atmosphere) async {
    if (_userId == null) throw Exception("User not logged in");
    if (atmosphere.id == null) {
      throw Exception("FiringAtmosphere ID is required for update");
    }
    await _db
        .collection('users')
        .doc(_userId)
        .collection('firing_atmospheres')
        .doc(atmosphere.id)
        .update(atmosphere.toFirestore());
  }

  /// 焼成雰囲気を削除
  Future<void> deleteFiringAtmosphere(String atmosphereId) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('firing_atmospheres')
        .doc(atmosphereId)
        .delete();
  }
}
