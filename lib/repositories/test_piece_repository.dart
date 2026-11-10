import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/repositories/user_scoped_repository.dart';

class TestPieceRepository extends UserScopedRepository<TestPiece> {
  TestPieceRepository({super.db, super.auth});

  @override
  String get collectionName => 'test_pieces';

  @override
  TestPiece fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      TestPiece.fromFirestore(snapshot);

  @override
  Map<String, dynamic> toFirestore(TestPiece item) => item.toFirestore();

  @override
  Query<Map<String, dynamic>> orderQuery(
    CollectionReference<Map<String, dynamic>> ref,
  ) => ref.orderBy('createdAt', descending: true);

  /// 新規ドキュメントIDを発行する (書き込みはまだ行わない)。
  /// 画像アップロードパスにIDを含めるため、保存前にIDを確定させる用途。
  String newDocumentId() => collection.doc().id;

  /// 指定IDでドキュメントを作成する (newDocumentIdとセットで使用)
  Future<void> setById(String id, TestPiece piece) async {
    await collection.doc(id).set(toFirestore(piece));
  }

  /// 指定したフィールドだけを更新する (他のフィールドは触らない)
  Future<void> updateFields(String id, Map<String, dynamic> fields) async {
    await collection.doc(id).update(fields);
  }

  /// 複数のドキュメントの指定フィールドをまとめて更新する。
  /// WriteBatch の上限に収まるよう、[chunkSize] 件ごとに区切って commit する。
  Future<void> updateFieldsBatch(
    Map<String, Map<String, dynamic>> fieldsById, {
    int chunkSize = 400,
  }) async {
    final entries = fieldsById.entries.toList();
    for (var start = 0; start < entries.length; start += chunkSize) {
      final batch = db.batch();
      for (final entry in entries.skip(start).take(chunkSize)) {
        batch.update(collection.doc(entry.key), entry.value);
      }
      await batch.commit();
    }
  }

  /// 特定の釉薬を使用するテストピース一覧を監視する (メイン・追加釉薬の両方を含む)
  ///
  /// firestore.indexes.json の複合インデックス
  /// (relatedGlazeIds CONTAINS + createdAt DESC) が必要。
  Stream<List<TestPiece>> watchForGlaze(String glazeId) {
    if (userId == null) return Stream.value([]);
    return collection
        .where('relatedGlazeIds', arrayContains: glazeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
  }
}
