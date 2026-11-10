import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/repositories/clay_repository.dart';
import 'package:glaze_manager/repositories/firing_atmosphere_repository.dart';
import 'package:glaze_manager/repositories/firing_profile_repository.dart';
import 'package:glaze_manager/repositories/firing_repository.dart';
import 'package:glaze_manager/repositories/glaze_repository.dart';
import 'package:glaze_manager/repositories/material_repository.dart';
import 'package:glaze_manager/repositories/tag_repository.dart';
import 'package:glaze_manager/repositories/test_piece_repository.dart';
import 'package:glaze_manager/repositories/view_history_repository.dart';
import 'package:glaze_manager/services/snapshot_backfill.dart';

/// Firestoreアクセスのファサード。
///
/// 実体はエンティティごとのリポジトリ (`lib/repositories/`) に分割されており、
/// 本クラスは既存の呼び出し側 (画面・テスト) との互換のために
/// 従来のメソッド名で各リポジトリへ委譲する。
/// 新規コードは個別リポジトリを直接使用してよい。
class FirestoreService {
  final MaterialRepository materials;
  final GlazeRepository glazes;
  final TestPieceRepository testPieces;
  final ClayRepository clays;
  final FiringProfileRepository firingProfiles;
  final FiringAtmosphereRepository firingAtmospheres;
  final FiringRepository firings;
  final TagRepository tags;
  final ViewHistoryRepository viewHistory;

  FirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
    : materials = MaterialRepository(db: db, auth: auth),
      glazes = GlazeRepository(db: db, auth: auth),
      testPieces = TestPieceRepository(db: db, auth: auth),
      clays = ClayRepository(db: db, auth: auth),
      firingProfiles = FiringProfileRepository(db: db, auth: auth),
      firingAtmospheres = FiringAtmosphereRepository(db: db, auth: auth),
      firings = FiringRepository(db: db, auth: auth),
      tags = TagRepository(db: db, auth: auth),
      viewHistory = ViewHistoryRepository(db: db, auth: auth);

  // --- Material Methods ---

  /// 原料を追加
  Future<void> addMaterial(Material material) => materials.add(material);

  /// 原料一覧を取得 (リアルタイム)
  Stream<List<Material>> getMaterials() => materials.watchAll();

  /// 原料一覧を1回だけ取得
  Future<List<Material>> getMaterialsOnce() => materials.getAll();

  /// 特定の原料を取得 (リアルタイム)
  Stream<Material> getMaterialStream(String id) => materials.watchById(id);

  /// 原料名からIDを取得
  Future<String?> getMaterialIdByName(String name) =>
      materials.getIdByName(name);

  /// 原料を更新
  Future<void> updateMaterial(Material material) =>
      materials.updateById(material.id, material);

  /// 原料を削除
  Future<void> deleteMaterial(String materialId) =>
      materials.deleteById(materialId);

  /// 複数の原料の並び順を更新
  Future<void> updateMaterialOrder(List<Material> list) =>
      materials.updateOrder(list);

  /// 複数の原料を名前で検索し、存在しない場合は新規作成する
  Future<List<String>> findOrCreateMaterials(List<String> materialNames) =>
      materials.findOrCreate(materialNames, category: MaterialCategory.base);

  /// 名前で顔料を検索し、存在しない場合はカテゴリ「顔料」で新規作成する。IDを返す
  Future<String> findOrCreatePigmentID(String pigmentName) async {
    if (pigmentName.isEmpty) return '';
    await materials.findOrCreate([
      pigmentName,
    ], category: MaterialCategory.pigment);
    return await materials.getIdByName(pigmentName) ?? '';
  }

  /// 複数の顔料を名前で検索し、存在しない場合はカテゴリ「顔料」で新規作成する
  Future<List<String>> findOrCreatePigments(List<String> pigmentNames) =>
      materials.findOrCreate(pigmentNames, category: MaterialCategory.pigment);

  // --- Glaze Methods ---

  /// 釉薬を追加
  Future<void> addGlaze(Glaze glaze) => glazes.add(glaze);

  /// 複数の釉薬を一括で追加 (バッチ処理)
  Future<void> addGlazesBatch(List<Glaze> list) => glazes.addBatch(list);

  /// 釉薬一覧を取得 (リアルタイム)
  Stream<List<Glaze>> getGlazes() => glazes.watchAll();

  /// 釉薬一覧を1回だけ取得
  Future<List<Glaze>> getGlazesOnce() => glazes.getAll();

  /// 特定の釉薬を取得 (リアルタイム)
  Stream<Glaze> getGlazeStream(String id) => glazes.watchById(id);

  /// 釉薬を更新
  Future<void> updateGlaze(Glaze glaze) => glazes.updateById(glaze.id, glaze);

  /// 釉薬を削除
  Future<void> deleteGlaze(String glazeId) => glazes.deleteById(glazeId);

  // --- TestPiece Methods ---

  /// テストピースを追加
  Future<void> addTestPiece(TestPiece testPiece) => testPieces.add(testPiece);

  /// テストピースの新規ドキュメントIDを発行する (書き込みはまだ行わない)
  String createTestPieceId() => testPieces.newDocumentId();

  /// 指定IDでテストピースを作成する (createTestPieceIdとセットで使用)
  Future<void> setTestPiece(String id, TestPiece testPiece) =>
      testPieces.setById(id, testPiece);

  /// テストピース一覧を取得 (リアルタイム)
  Stream<List<TestPiece>> getTestPieces() => testPieces.watchAll();

  /// テストピース一覧を1回だけ取得
  Future<List<TestPiece>> getTestPiecesOnce() => testPieces.getAll();

  /// 特定の釉薬に関連するテストピース一覧を取得 (リアルタイム)
  Stream<List<TestPiece>> getTestPiecesForGlaze(String glazeId) =>
      testPieces.watchForGlaze(glazeId);

  /// 特定のテストピースを取得 (リアルタイム)
  Stream<TestPiece> getTestPieceStream(String id) => testPieces.watchById(id);

  /// テストピースの指定フィールドだけを更新する。
  /// imageUrl / thumbnailUrl は Cloud Functions が書くので送らないこと
  /// (TestPiece.toUpdateFields を使う)
  Future<void> updateTestPieceFields(String id, Map<String, dynamic> fields) =>
      testPieces.updateFields(id, fields);

  /// 複数のテストピースの指定フィールドをまとめて更新する (400 件ごとに commit)
  Future<void> updateTestPieceFieldsBatch(
    Map<String, Map<String, dynamic>> fieldsById,
  ) => testPieces.updateFieldsBatch(fieldsById);

  /// 写しを持たない既存のテストピースに、現在の調合から写しを埋める。
  /// 書き込んだ件数を返す。通信できなければ例外になる。
  ///
  /// どのテストピースに写しが無いかは、サーバーから読んだ内容で判断する。
  /// 端末のキャッシュで判断すると、長く使っていなかった端末が、別の端末で
  /// すでに保存された写しを、古い調合から作った写しで上書きしてしまう。
  Future<int> backfillTestPieceSnapshots() async {
    final (pieces, glazeList, materialList, clayList) = await (
      testPieces.getAllFromServer(),
      glazes.getAllFromServer(),
      materials.getAllFromServer(),
      clays.getAllFromServer(),
    ).wait;
    final plan = planSnapshotBackfill(
      pieces: pieces,
      glazeMap: {for (final g in glazeList) g.id!: g},
      materialMap: {for (final m in materialList) m.id!: m},
      clayMap: {for (final c in clayList) c.id!: c},
    );
    if (plan.isEmpty) return 0;
    await testPieces.updateFieldsBatch({
      for (final entry in plan.entries)
        entry.key: {'snapshot': entry.value.toMap()},
    });
    return plan.length;
  }

  /// テストピースを削除
  Future<void> deleteTestPiece(String testPieceId) =>
      testPieces.deleteById(testPieceId);

  // --- ViewHistory Methods ---

  /// テストピースの閲覧履歴を更新または作成する
  Future<void> updateViewHistory(String testPieceId) =>
      viewHistory.record(testPieceId);

  /// 最近見たテストピースのIDリストを取得する
  Stream<List<String>> getRecentTestPieceIds({int limit = 20}) =>
      viewHistory.watchRecentIds(limit: limit);

  // --- FiringProfile Methods ---

  /// 焼成プロファイルを追加
  Future<void> addFiringProfile(FiringProfile profile) =>
      firingProfiles.add(profile);

  /// 焼成プロファイル一覧を取得 (リアルタイム)
  Stream<List<FiringProfile>> getFiringProfiles() => firingProfiles.watchAll();

  /// 焼成プロファイル一覧を1回だけ取得
  Future<List<FiringProfile>> getFiringProfilesOnce() =>
      firingProfiles.getAll();

  /// 特定の焼成プロファイルを取得 (リアルタイム)
  Stream<FiringProfile> getFiringProfileStream(String id) =>
      firingProfiles.watchById(id);

  /// 焼成プロファイルを更新
  Future<void> updateFiringProfile(FiringProfile profile) =>
      firingProfiles.updateById(profile.id, profile);

  /// 焼成プロファイルを削除
  Future<void> deleteFiringProfile(String profileId) =>
      firingProfiles.deleteById(profileId);

  // --- FiringAtmosphere Methods ---

  /// 焼成雰囲気を追加
  Future<void> addFiringAtmosphere(FiringAtmosphere atmosphere) =>
      firingAtmospheres.add(atmosphere);

  /// 焼成雰囲気一覧を取得 (リアルタイム)
  Stream<List<FiringAtmosphere>> getFiringAtmospheres() =>
      firingAtmospheres.watchAll();

  /// 焼成雰囲気一覧を1回だけ取得
  Future<List<FiringAtmosphere>> getFiringAtmospheresOnce() =>
      firingAtmospheres.getAll();

  /// 特定の焼成雰囲気を取得 (リアルタイム)
  Stream<FiringAtmosphere> getFiringAtmosphereStream(String id) =>
      firingAtmospheres.watchById(id);

  /// 焼成雰囲気を更新
  Future<void> updateFiringAtmosphere(FiringAtmosphere atmosphere) =>
      firingAtmospheres.updateById(atmosphere.id, atmosphere);

  /// 焼成雰囲気を削除
  Future<void> deleteFiringAtmosphere(String atmosphereId) =>
      firingAtmospheres.deleteById(atmosphereId);

  // --- Firing Methods ---

  /// 焼成回の新規ドキュメントIDを発行する (書き込みはまだ行わない)
  String createFiringId() => firings.newDocumentId();

  /// 指定IDで焼成回を作成する (createFiringIdとセットで使用)
  Future<void> setFiring(String id, Firing firing) =>
      firings.setById(id, firing);

  /// 焼成回一覧を取得 (リアルタイム。焼成日の新しい順)
  Stream<List<Firing>> getFirings() => firings.watchAll();

  /// 焼成回一覧を1回だけ取得
  Future<List<Firing>> getFiringsOnce() => firings.getAll();

  /// 焼成回を更新
  Future<void> updateFiring(Firing firing) =>
      firings.updateById(firing.id, firing);

  /// 焼成回を削除
  Future<void> deleteFiring(String firingId) => firings.deleteById(firingId);

  // --- Clay Methods ---

  /// 素地土名を追加
  Future<void> addClay(Clay clay) => clays.add(clay);

  /// 素地土名一覧を取得 (リアルタイム)
  Stream<List<Clay>> getClays() => clays.watchAll();

  /// 素地土名一覧を1回だけ取得
  Future<List<Clay>> getClaysOnce() => clays.getAll();

  /// 特定の素地土名を取得 (リアルタイム)
  Stream<Clay> getClayStream(String id) => clays.watchById(id);

  /// 素地土名を更新
  Future<void> updateClay(Clay clay) => clays.updateById(clay.id, clay);

  /// 素地土名を削除
  Future<void> deleteClay(String clayId) => clays.deleteById(clayId);

  /// 複数の素地土名の並び順を更新
  Future<void> updateClayOrder(List<Clay> list) => clays.updateOrder(list);

  // --- Tag Methods ---

  /// タグ一覧を取得 (リアルタイム)
  Stream<List<String>> getTags() => tags.watchAll();

  /// タグ一覧を1回だけ取得
  Future<List<String>> getTagsOnce() => tags.getAll();

  /// タグを追加 (存在しない場合のみ)
  Future<void> addTag(String tagName) => tags.add(tagName);

  /// 複数のタグをまとめて追加 (存在しないものだけ作成)
  Future<void> addTags(List<String> tagNames) => tags.addAll(tagNames);

  /// タグを削除 (マスターリストからのみ削除)
  Future<void> deleteTag(String tagName) => tags.delete(tagName);
}
