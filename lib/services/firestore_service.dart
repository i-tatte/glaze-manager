import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/models/clay.dart';
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

  // 特定の原料を取得 (リアルタイム)
  Stream<Material> getMaterialStream(String id) {
    if (_userId == null) return Stream.error("User not logged in");
    return _db
        .collection('users')
        .doc(_userId)
        .collection('materials')
        .doc(id)
        .snapshots()
        .map((snapshot) => Material.fromFirestore(snapshot));
  }

  // 原料名からIDを取得
  Future<String?> getMaterialIdByName(String name) async {
    if (_userId == null) throw Exception("User not logged in");
    final querySnapshot = await _db
        .collection('users')
        .doc(_userId)
        .collection('materials')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }
    return null;
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

  // 複数の釉薬を一括で追加 (バッチ処理)
  Future<void> addGlazesBatch(List<Glaze> glazes) async {
    if (_userId == null) throw Exception("User not logged in");

    final batch = _db.batch();
    final collectionRef = _db
        .collection('users')
        .doc(_userId)
        .collection('glazes');

    for (final glaze in glazes) {
      final docRef = collectionRef.doc(); // 新しいドキュメントIDを自動生成
      batch.set(docRef, glaze.toFirestore());
    }
    await batch.commit();
  }

  /// 複数の原料を名前で検索し、存在しない場合は新規作成する
  Future<List<String>> findOrCreateMaterials(List<String> materialNames) async {
    if (_userId == null) throw Exception("User not logged in");
    if (materialNames.isEmpty) return [];

    final newMaterialNames = <String>[];
    final existingMaterials = await getMaterials().first;
    final existingMaterialNames = existingMaterials.map((m) => m.name).toSet();

    for (final name in materialNames) {
      if (!existingMaterialNames.contains(name)) {
        newMaterialNames.add(name);
      }
    }

    if (newMaterialNames.isNotEmpty) {
      final batch = _db.batch();
      final collectionRef = _db
          .collection('users')
          .doc(_userId)
          .collection('materials');

      for (final name in newMaterialNames) {
        final newMaterial = Material(
          name: name,
          components: {},
          order: DateTime.now().millisecondsSinceEpoch,
          category: MaterialCategory.base,
        );
        batch.set(collectionRef.doc(), newMaterial.toFirestore());
      }
      await batch.commit();
    }
    return newMaterialNames;
  }

  /// 名前で顔料を検索し、存在しない場合はカテゴリ「顔料」で新規作成する。
  /// IDを返す
  Future<String> findOrCreatePigmentID(String pigmentName) async {
    if (_userId == null) throw Exception("User not logged in");
    if (pigmentName.isEmpty) return '';

    final existingMaterials = await getMaterials().first;
    final existingMaterialNames = existingMaterials.map((m) => m.name).toSet();

    if (!existingMaterialNames.contains(pigmentName)) {
      final newMaterial = Material(
        name: pigmentName,
        components: {},
        order: DateTime.now().millisecondsSinceEpoch,
        category: MaterialCategory.pigment, // カテゴリを顔料に設定
      );
      await addMaterial(newMaterial);
    }
    return await getMaterialIdByName(pigmentName) ?? '';
  }

  /// 複数の顔料を名前で検索し、存在しない場合はカテゴリ「顔料」で新規作成する
  Future<List<String>> findOrCreatePigments(List<String> pigmentNames) async {
    if (_userId == null) throw Exception("User not logged in");
    if (pigmentNames.isEmpty) return [];

    final uniquePigmentNames = pigmentNames.toSet().toList();
    final newPigmentNames = <String>[];
    final existingMaterials = await getMaterials().first;
    final existingMaterialNames = existingMaterials.map((m) => m.name).toSet();

    for (final name in uniquePigmentNames) {
      if (!existingMaterialNames.contains(name)) {
        newPigmentNames.add(name);
      }
    }

    if (newPigmentNames.isNotEmpty) {
      final batch = _db.batch();
      final collectionRef = _db
          .collection('users')
          .doc(_userId)
          .collection('materials');

      for (final name in newPigmentNames) {
        final newMaterial = Material(
          name: name,
          components: {},
          order:
              DateTime.now().millisecondsSinceEpoch +
              newPigmentNames.indexOf(name),
          category: MaterialCategory.pigment, // カテゴリを顔料に設定
        );
        batch.set(collectionRef.doc(), newMaterial.toFirestore());
      }
      await batch.commit();
    }
    return newPigmentNames;
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

  Stream<Glaze> getGlazeStream(String id) {
    if (_userId == null) return Stream.error("User not logged in");
    return _db
        .collection('users')
        .doc(_userId)
        .collection('glazes')
        .doc(id)
        .snapshots()
        .map((snapshot) => Glaze.fromFirestore(snapshot));
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

  // 特定の釉薬に関連するテストピース一覧を取得 (リアルタイム)
  Stream<List<TestPiece>> getTestPiecesForGlaze(String glazeId) {
    if (_userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_userId)
        .collection('test_pieces')
        .where('glazeId', isEqualTo: glazeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => TestPiece.fromFirestore(doc)).toList(),
        );
  }

  // 特定のテストピースを取得 (リアルタイム)
  Stream<TestPiece> getTestPieceStream(String id) {
    if (_userId == null) return Stream.error("User not logged in");
    return _db
        .collection('users')
        .doc(_userId)
        .collection('test_pieces')
        .doc(id)
        .snapshots()
        .map((snapshot) => TestPiece.fromFirestore(snapshot));
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

  // --- Clay Methods ---

  /// 素地土名を追加
  Future<void> addClay(Clay clay) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('clays')
        .add(clay.toFirestore());
  }

  /// 素地土名一覧を取得 (リアルタイム)
  Stream<List<Clay>> getClays() {
    if (_userId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_userId)
        .collection('clays')
        .orderBy('order') // orderフィールドで並び替え
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Clay.fromFirestore(doc)).toList(),
        );
  }

  /// 素地土名を更新
  Future<void> updateClay(Clay clay) async {
    if (_userId == null) throw Exception("User not logged in");
    if (clay.id == null) {
      throw Exception("Clay ID is required for update");
    }
    await _db
        .collection('users')
        .doc(_userId)
        .collection('clays')
        .doc(clay.id)
        .update(clay.toFirestore());
  }

  /// 素地土名を削除
  Future<void> deleteClay(String clayId) async {
    if (_userId == null) throw Exception("User not logged in");
    await _db
        .collection('users')
        .doc(_userId)
        .collection('clays')
        .doc(clayId)
        .delete();
  }

  /// 複数の素地土名の並び順を更新
  Future<void> updateClayOrder(List<Clay> clays) async {
    if (_userId == null) throw Exception("User not logged in");

    final batch = _db.batch();
    for (int i = 0; i < clays.length; i++) {
      final clay = clays[i];
      final docRef = _db
          .collection('users')
          .doc(_userId)
          .collection('clays')
          .doc(clay.id);
      batch.update(docRef, {'order': i});
    }
    await batch.commit();
  }
}
